import 'package:hive_flutter/hive_flutter.dart';
import '../core/api/api_client.dart';
import '../core/models/budget.dart';

/// 预算服务
class BudgetService {
  static final BudgetService _instance = BudgetService._internal();
  factory BudgetService() => _instance;
  BudgetService._internal();

  final ApiClient _api = apiClient;
  static const String _boxName = 'budget_cache';
  late Box<Map> _cacheBox;

  Future<void> init() async {
    _cacheBox = await Hive.openBox<Map>(_boxName);
  }

  /// 获取当前月份预算
  Future<Budget?> getCurrentMonthBudget() async {
    final now = DateTime.now();
    return getBudget(now.year, now.month);
  }

  /// 获取指定月份预算
  Future<Budget?> getBudget(int year, int month) async {
    final cacheKey = '${year}_$month';
    
    try {
      final response = await _api.get('/api/budget', params: {
        'year': year,
        'month': month,
      });
      
      if (response.data != null) {
        final budget = Budget.fromJson(response.data);
        // 更新缓存
        await _cacheBox.put(cacheKey, budget.toJson());
        return budget;
      }
      // API返回null，清除缓存
      await _cacheBox.delete(cacheKey);
    } catch (e) {
      // API失败，从缓存读取
      final cached = _cacheBox.get(cacheKey);
      if (cached != null) {
        return Budget.fromJson(Map<String, dynamic>.from(cached));
      }
    }
    
    return null;
  }

  /// 保存预算
  Future<Budget> saveBudget(Budget budget) async {
    try {
      final response = await _api.post('/api/budget', data: budget.toJson());
      final savedBudget = Budget.fromJson(response.data);
      
      // 更新缓存
      final cacheKey = '${savedBudget.year}_${savedBudget.month}';
      await _cacheBox.put(cacheKey, savedBudget.toJson());
      
      return savedBudget;
    } catch (e) {
      // 如果API失败，保存到本地缓存
      final cacheKey = '${budget.year}_${budget.month}';
      await _cacheBox.put(cacheKey, budget.toJson());
      return budget;
    }
  }

  /// 获取预算使用情况
  Future<BudgetUsage> getBudgetUsage(int year, int month) async {
    try {
      final response = await _api.get('/api/budget/usage', params: {
        'year': year,
        'month': month,
      });
      
      return BudgetUsage.fromJson(response.data);
    } catch (e) {
      // 如果API失败，计算本地数据
      return _calculateLocalUsage(year, month);
    }
  }

  /// 计算本地使用情况
  Future<BudgetUsage> _calculateLocalUsage(int year, int month) async {
    final budget = await getBudget(year, month);
    double totalSpent = 0;
    Map<String, double> categorySpent = {};

    try {
      // 获取月度统计
      final response = await _api.get('/api/stats/monthly', params: {
        'year': year,
        'month': month,
      });
      
      totalSpent = (response.data['total_expense'] ?? 0).toDouble();
      
      // 解析分类支出
      final categoryStats = response.data['category_stats'] as List? ?? [];
      for (var stat in categoryStats) {
        if (stat['type'] == 'expense') {
          categorySpent[stat['category_name'] ?? '其他'] = (stat['total'] ?? 0).toDouble();
        }
      }
    } catch (e) {
      // 静默失败
    }

    return BudgetUsage(
      budget: budget,
      totalSpent: totalSpent,
      categorySpent: categorySpent,
      remaining: (budget?.totalBudget ?? 0) - totalSpent,
      usageRatio: budget != null && budget.totalBudget > 0 
          ? totalSpent / budget.totalBudget 
          : 0,
    );
  }

  /// 获取历史预算列表
  Future<List<Budget>> getBudgetHistory() async {
    try {
      final response = await _api.get('/api/budget/history');
      final List<dynamic> data = response.data ?? [];
      return data.map((e) => Budget.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 删除预算
  Future<void> deleteBudget(int id) async {
    try {
      await _api.delete('/api/budget/$id');
    } catch (e) {
      // 静默失败
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await _cacheBox.clear();
  }
}

/// 预算使用情况
class BudgetUsage {
  final Budget? budget;
  final double totalSpent;
  final Map<String, double> categorySpent;
  final double remaining;
  final double usageRatio;

  BudgetUsage({
    this.budget,
    required this.totalSpent,
    required this.categorySpent,
    required this.remaining,
    required this.usageRatio,
  });

  factory BudgetUsage.fromJson(Map<String, dynamic> json) {
    return BudgetUsage(
      budget: json['budget'] != null ? Budget.fromJson(json['budget']) : null,
      totalSpent: (json['total_spent'] ?? json['totalSpent'] ?? 0).toDouble(),
      categorySpent: json['category_spent'] != null
          ? Map<String, double>.from(json['category_spent'].map(
              (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble())))
          : {},
      remaining: (json['remaining'] ?? 0).toDouble(),
      usageRatio: (json['usage_ratio'] ?? json['usageRatio'] ?? 0).toDouble(),
    );
  }

  /// 是否超支
  bool get isOverBudget => budget != null && totalSpent > budget!.totalBudget;

  /// 是否接近预警
  bool get isNearWarning => budget != null && usageRatio >= budget!.warningThreshold;

  /// 获取预警级别
  WarningLevel get warningLevel {
    if (budget == null) return WarningLevel.normal;
    return budget!.getWarningLevel(totalSpent);
  }

  /// 获取每日平均支出
  double get dailyAverage {
    if (budget == null) return 0;
    final now = DateTime.now();
    final daysInMonth = DateTime(budget!.year, budget!.month + 1, 0).day;
    final currentDay = now.year == budget!.year && now.month == budget!.month 
        ? now.day 
        : daysInMonth;
    return currentDay > 0 ? totalSpent / currentDay : 0;
  }

  /// 预测月底支出
  double get predictedMonthEnd {
    if (budget == null || dailyAverage == 0) return totalSpent;
    final daysInMonth = DateTime(budget!.year, budget!.month + 1, 0).day;
    return dailyAverage * daysInMonth;
  }
}
