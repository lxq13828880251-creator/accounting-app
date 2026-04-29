/// 预算模型
class Budget {
  final int? id;
  final int userId;
  final int year;
  final int month;
  final double totalBudget;
  final double warningThreshold; // 预警阈值(默认0.8)
  final Map<String, double>? categoryBudgets;
  final bool enableReminder;
  final DateTime? createdAt;

  Budget({
    this.id,
    required this.userId,
    required this.year,
    required this.month,
    required this.totalBudget,
    this.warningThreshold = 0.8,
    this.categoryBudgets,
    this.enableReminder = true,
    this.createdAt,
  });

  /// 预警金额 = 总预算 × 预警阈值
  double get warningAmount => totalBudget * warningThreshold;

  /// 剩余预算
  double remainingBudget(double spent) => totalBudget - spent;

  /// 使用比例
  double usageRatio(double spent) => totalBudget > 0 ? spent / totalBudget : 0;

  /// 是否超支
  bool isOverBudget(double spent) => spent > totalBudget;

  /// 是否接近预警
  bool isNearWarning(double spent) => usageRatio(spent) >= warningThreshold;

  /// 获取预警级别
  WarningLevel getWarningLevel(double spent) {
    final ratio = usageRatio(spent);
    if (ratio >= 1.0) return WarningLevel.danger;
    if (ratio >= warningThreshold) return WarningLevel.warning;
    if (ratio >= 0.5) return WarningLevel.caution;
    return WarningLevel.normal;
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      userId: json['user_id'] ?? json['userId'],
      year: json['year'],
      month: json['month'],
      totalBudget: (json['total_budget'] ?? json['totalBudget'] ?? 0).toDouble(),
      warningThreshold: (json['warning_threshold'] ?? json['warningThreshold'] ?? 0.8).toDouble(),
      categoryBudgets: json['category_budgets'] != null
          ? Map<String, double>.from(json['category_budgets'].map(
              (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble())))
          : null,
      enableReminder: json['enable_reminder'] ?? json['enableReminder'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'year': year,
      'month': month,
      'total_budget': totalBudget,
      'warning_threshold': warningThreshold,
      if (categoryBudgets != null) 'category_budgets': categoryBudgets,
      'enable_reminder': enableReminder,
    };
  }

  Budget copyWith({
    int? id,
    int? userId,
    int? year,
    int? month,
    double? totalBudget,
    double? warningThreshold,
    Map<String, double>? categoryBudgets,
    bool? enableReminder,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      year: year ?? this.year,
      month: month ?? this.month,
      totalBudget: totalBudget ?? this.totalBudget,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      enableReminder: enableReminder ?? this.enableReminder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 预警级别
enum WarningLevel {
  normal,   // 正常 (<50%)
  caution,  // 提醒 (50-80%)
  warning,  // 警告 (80-100%)
  danger,   // 危险 (>100%)
}

extension WarningLevelExtension on WarningLevel {
  String get label {
    switch (this) {
      case WarningLevel.normal:
        return '正常';
      case WarningLevel.caution:
        return '注意';
      case WarningLevel.warning:
        return '预警';
      case WarningLevel.danger:
        return '超支';
    }
  }

  String get emoji {
    switch (this) {
      case WarningLevel.normal:
        return '✅';
      case WarningLevel.caution:
        return '💡';
      case WarningLevel.warning:
        return '⚠️';
      case WarningLevel.danger:
        return '🚨';
    }
  }
}
