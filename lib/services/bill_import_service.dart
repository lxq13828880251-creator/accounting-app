import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_config.dart';

/// 账单记录项
class BillItem {
  final String source; // 'alipay' | 'wechat'
  final DateTime date;
  final String type; // 'expense' | 'income'
  final double amount;
  final String category;
  final String? counterparty;
  final String? description;
  final String? status;
  final String? orderNo;

  BillItem({
    required this.source,
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    this.counterparty,
    this.description,
    this.status,
    this.orderNo,
  });
}

/// 账单解析结果
class BillParseResult {
  final List<BillItem> items;
  final double totalExpense;
  final double totalIncome;
  final int expenseCount;
  final int incomeCount;
  final String source;

  BillParseResult({
    required this.items,
    required this.totalExpense,
    required this.totalIncome,
    required this.expenseCount,
    required this.incomeCount,
    required this.source,
  });
}

/// 账单导入服务
class BillImportService {
  final Dio _dio;

  BillImportService() : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  /// 从文件路径解析支付宝账单(CSV)
  Future<BillParseResult> parseAlipayFile(Uint8List bytes) async {
    try {
      // 将文件发送到后端解析
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'alipay_bill.csv'),
      });

      final response = await _dio.post('/api/bill/parse-alipay', data: formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['items'] ?? [];
        final items = data.map((item) => BillItem(
          source: 'alipay',
          date: DateTime.parse(item['date']),
          type: item['type'],
          amount: (item['amount'] as num).toDouble(),
          category: item['category'] ?? '其他',
          counterparty: item['counterparty'],
          description: item['description'],
          status: item['status'],
        )).toList();

        return _buildResult(items, '支付宝');
      } else {
        // 后端返回错误，尝试本地解析
        return _parseAlipayCsvLocal(bytes);
      }
    } catch (e) {
      // 如果后端API不可用，尝试本地解析
      try {
        return _parseAlipayCsvLocal(bytes);
      } catch (_) {
        rethrow;
      }
    }
  }

  /// 本地解析支付宝CSV
  Future<BillParseResult> _parseAlipayCsvLocal(Uint8List bytes) async {
    try {
      // 尝试不同编码
      String content = '';
      for (final encoding in ['utf-8', 'gbk', 'gb2312', 'gb18030']) {
        try {
          content = String.fromCharCodes(bytes);
          break;
        } catch (_) {
          continue;
        }
      }

      final lines = content.split('\n');
      final List<BillItem> items = [];

      // 找到表头行 - 更灵活的匹配
      int headerIndex = -1;
      for (int i = 0; i < lines.length && i < 10; i++) {
        if (lines[i].contains('交易时间')) {
          headerIndex = i;
          break;
        }
      }

      if (headerIndex == -1) {
        throw Exception('无法找到支付宝账单表头，请确保是支付宝标准格式CSV');
      }

      // 解析数据行
      for (int i = headerIndex + 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.startsWith('---') || line.startsWith('=')) continue;

        // 使用逗号分割，但允许引号包裹的内容
        final parts = _splitCsvLine(line);
        if (parts.length < 6) continue;

        try {
          final dateStr = parts[0].trim();
          final category = parts.length > 1 ? parts[1].trim() : '';
          final counterparty = parts.length > 2 ? parts[2].trim() : '';
          final description = parts.length > 4 ? parts[4].trim() : (parts.length > 3 ? parts[3].trim() : '');
          final typeStr = parts.length > 5 ? parts[5].trim() : '';
          final amountStr = parts.length > 6 ? parts[6].trim() : '0';
          final status = parts.length > 8 ? parts[8].trim() : '交易成功';

          // 跳过非收支记录
          if (!['支出', '收入'].contains(typeStr)) continue;
          // 只处理成功交易
          if (!status.contains('成功') && !status.contains('退款')) continue;

          final amount = double.tryParse(amountStr.replaceAll(',', '').replaceAll('¥', '')) ?? 0;
          if (amount == 0) continue;

          // 解析日期
          final dateParts = dateStr.split(' ');
          if (dateParts.length < 2) continue;
          final ymd = dateParts[0].split('-');
          final time = dateParts[1].split(':');
          final date = DateTime(
            int.parse(ymd[0]),
            int.parse(ymd[1]),
            int.parse(ymd[2]),
            int.parse(time[0]),
            int.parse(time[1]),
            int.parse(time[2]),
          );

          items.add(BillItem(
            source: 'alipay',
            date: date,
            type: typeStr == '支出' ? 'expense' : 'income',
            amount: amount.abs(),
            category: _mapAlipayCategory(category),
            counterparty: counterparty,
            description: description,
            status: status,
          ));
        } catch (e) {
          continue;
        }
      }

      return _buildResult(items, '支付宝');
    } catch (e) {
      throw Exception('解析支付宝账单失败: $e');
    }
  }

  /// CSV行分割（处理引号）
  List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  /// 从文件路径解析微信账单(Excel)
  Future<BillParseResult> parseWechatFile(Uint8List bytes) async {
    try {
      // 将字节发送到后端解析(后端有pandas)
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'wechat_bill.xlsx'),
      });

      final response = await _dio.post('/api/bill/parse-wechat', data: formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['items'] ?? [];
        final items = data.map((item) => BillItem(
          source: 'wechat',
          date: DateTime.parse(item['date']),
          type: item['type'],
          amount: (item['amount'] as num).toDouble(),
          category: item['category'] ?? '其他',
          counterparty: item['counterparty'],
          description: item['description'],
          status: item['status'],
        )).toList();

        return _buildResult(items, '微信支付');
      } else {
        // 后端解析失败
        throw Exception(response.data['detail'] ?? '服务器解析失败');
      }
    } catch (e) {
      // 如果后端API不可用，返回友好提示
      throw Exception('微信Excel需要后端解析，请确保网络连接正常。错误: $e');
    }
  }

  /// 本地解析微信Excel(简单解析)
  Future<BillParseResult> _parseWechatExcelLocal(Uint8List bytes) async {
    try {
      // 简单的CSV式解析 - 微信导出的Excel实际上可以用CSV方式解析
      // 这里我们直接返回错误，提示用户需要后端支持
      throw Exception('微信Excel需要后端解析，请确保后端已更新');
    } catch (e) {
      rethrow;
    }
  }

  /// 批量导入账单到服务器
  Future<Map<String, dynamic>> importBills(List<BillItem> items, String token) async {
    try {
      // 转换为后端需要的格式
      final itemsData = items.map((item) => {
        'amount': item.amount,
        'record_type': item.type,
        'category': item.category,
        'counterparty': item.counterparty,
        'description': item.description,
        'record_date': '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}',
        'source': item.source,
      }).toList();

      final response = await _dio.post(
        '/api/bill/import',
        data: itemsData,  // 直接发送数组，不包装
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'application/json',
        ),
      );

      return response.data;
    } catch (e) {
      throw Exception('导入账单失败: $e');
    }
  }

  DateTime _parseAlipayDate(String dateStr) {
    // 格式: 2026-04-26 12:36:20
    final parts = dateStr.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':');
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  double _parseAmount(String amountStr) {
    return double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
  }

  String _mapAlipayCategory(String category) {
    // 支付宝分类映射到应用分类
    final mapping = {
      '交通出行': '交通',
      '餐饮': '餐饮',
      '日用百货': '日用',
      '服饰装扮': '服饰',
      '娱乐': '娱乐',
      '医疗': '医疗',
      '教育': '教育',
      '居住': '居住',
      '通讯': '通讯',
      '快递': '日用',
      '电影': '娱乐',
      '旅游': '娱乐',
      '酒店': '居住',
    };
    return mapping[category] ?? category;
  }

  BillParseResult _buildResult(List<BillItem> items, String source) {
    double totalExpense = 0;
    double totalIncome = 0;
    int expenseCount = 0;
    int incomeCount = 0;

    for (final item in items) {
      if (item.type == 'expense') {
        totalExpense += item.amount;
        expenseCount++;
      } else {
        totalIncome += item.amount;
        incomeCount++;
      }
    }

    return BillParseResult(
      items: items,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      source: source,
    );
  }
}
