import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/models/fixed_expense.dart';
import '../core/constants/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 固定费用服务
class FixedExpenseService {
  late final Dio _dio;

  FixedExpenseService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl + '/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加Token拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConfig.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  /// 获取所有固定费用
  Future<List<FixedExpense>> getAllFixedExpenses() async {
    try {
      final response = await _dio.get('/fixed-expenses/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => FixedExpense.fromJson(e)).toList();
      }
    } catch (e) {
      // 返回空列表
    }
    return [];
  }

  /// 获取已启用的固定费用
  Future<List<FixedExpense>> getEnabledFixedExpenses() async {
    final all = await getAllFixedExpenses();
    return all.where((e) => e.isEnabled).toList();
  }

  /// 获取每月固定费用总额
  Future<double> getMonthlyTotal() async {
    final enabled = await getEnabledFixedExpenses();
    double total = 0.0;
    for (var e in enabled) {
      total += e.amount;
    }
    return total;
  }

  /// 添加固定费用
  Future<FixedExpense> addFixedExpense(FixedExpense expense) async {
    try {
      final response = await _dio.post(
        '/fixed-expenses/',
        data: expense.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return FixedExpense.fromJson(response.data);
      }
    } catch (e) {
      // 忽略错误
    }
    throw Exception('添加固定费用失败');
  }

  /// 更新固定费用
  Future<void> updateFixedExpense(FixedExpense expense) async {
    try {
      final response = await _dio.put(
        '/fixed-expenses/${expense.id}',
        data: expense.toJson(),
      );

      if (response.statusCode == 200) {
        return;
      }
    } catch (e) {
      // 忽略错误
    }
    throw Exception('更新固定费用失败');
  }

  /// 删除固定费用
  Future<void> deleteFixedExpense(int id) async {
    try {
      final response = await _dio.delete('/fixed-expenses/$id');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
    } catch (e) {
      // 忽略错误
    }
    throw Exception('删除固定费用失败');
  }

  /// 切换启用状态
  Future<void> toggleEnabled(FixedExpense expense) async {
    final updated = expense.copyWith(isEnabled: !expense.isEnabled);
    await updateFixedExpense(updated);
  }
}
