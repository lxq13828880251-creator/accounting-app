import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_config.dart';

/// 豆包大模型服务（方舟ARK API Key认证）
/// 完整流程：麦克风 → 火山ASR(语音服务Key) → 豆包API(ARK Key) → 结构化JSON
class DoubaoApiService {
  final Dio _dio = Dio();

  // ══════════════════════════════════════════════════════════════
  // 方舟ARK API 认证（豆包大模型使用）
  // ══════════════════════════════════════════════════════════════

  Map<String, String> get _arkHeaders => {
    'Authorization': 'Bearer ${AppConfig.arkApiKey}',
    'Content-Type': 'application/json',
  };

  // ══════════════════════════════════════════════════════════════
  // 智能记账解析（豆包API + ARK Key）
  // 输入: "买菜花了35块"
  // 输出: { amount: 35, record_type: "expense", category: "日用百货", description: "买菜" }
  // ══════════════════════════════════════════════════════════════

  /// 智能解析记账文本
  /// 使用豆包大模型自动识别金额、分类、收支类型
  Future<DoubaoParseResult> parseAccountingText(String text) async {
    try {
      final prompt = _buildAccountingPrompt(text);

      final response = await _dio.post(
        '${AppConfig.arkApiBaseUrl}/chat/completions',
        options: Options(
          headers: _arkHeaders,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': 'doubao-seed-1-6-flash-250828',  // 可用的豆包闪速模型
          'messages': [
            {
              'role': 'system',
              'content': '''你是一个专业的记账助手。请从用户的记账语音中提取信息，返回JSON格式。

规则：
- amount: 金额数字（只保留数字，如"35"），如果是收入返回正数，支出返回正数
- record_type: "expense"表示支出，"income"表示收入
- category: 根据语义匹配最合适的分类，可选值：餐饮、交通、购物、居住、通讯、医疗、教育、娱乐、工资、奖金、理财、其他
- description: 简短描述（5字以内）

只返回JSON，不要其他内容：
{"amount": 数字, "record_type": "expense|income", "category": "分类名", "description": "描述"}''',
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'temperature': 0.1,
          'max_tokens': 200,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final content = data['choices']?[0]?['message']?['content'] ?? '';

        return _parseJsonResponse(content);
      }

      throw Exception('豆包API请求失败: ${response.statusCode}');
    } catch (e) {
      // 如果豆包API失败，返回错误
      return DoubaoParseResult(
        success: false,
        error: '豆包API解析失败: $e',
      );
    }
  }

  /// 构建记账提示词
  String _buildAccountingPrompt(String text) {
    return '''
请从以下记账语音中提取信息，返回JSON格式：

语音内容：「$text」

要求：
- amount: 金额（数字）
- record_type: expense(支出) 或 income(收入)
- category: 分类（餐饮/交通/购物/居住/通讯/医疗/教育/娱乐/工资/奖金/理财/其他）
- description: 简短描述（5字以内）

只返回JSON：
''';
  }

  /// 解析JSON响应
  DoubaoParseResult _parseJsonResponse(String content) {
    try {
      // 提取JSON（可能在markdown代码块中）
      String jsonStr = content.trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final json = jsonDecode(jsonStr);

      return DoubaoParseResult(
        success: true,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        recordType: json['record_type'] ?? 'expense',
        category: json['category'] ?? '其他',
        description: json['description'] ?? '',
      );
    } catch (e) {
      return DoubaoParseResult(
        success: false,
        error: '解析响应失败: $e\n原始内容: $content',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 端到端一体化记账（ASR + 豆包API）
  // ══════════════════════════════════════════════════════════════

  /// 一体化语音记账
  /// 流程：录音 → ASR转文字 → 豆包API解析 → 返回结构化结果
  Future<DoubaoParseResult> voiceAccounting({
    required Future<String> Function() recordAndAsr, // 返回ASR转写的文字
  }) async {
    try {
      // 1. 录音 + ASR识别
      final recognizedText = await recordAndAsr();

      if (recognizedText.isEmpty) {
        return DoubaoParseResult(
          success: false,
          error: '未识别到语音内容',
        );
      }

      // 2. 豆包API智能解析
      final result = await parseAccountingText(recognizedText);

      // 3. 合并结果，保留原始识别文本
      return DoubaoParseResult(
        success: result.success,
        amount: result.amount,
        recordType: result.recordType,
        category: result.category,
        description: result.description,
        recognizedText: recognizedText,
        error: result.error,
      );
    } catch (e) {
      return DoubaoParseResult(
        success: false,
        error: '一体化记账失败: $e',
      );
    }
  }
}

/// 豆包API解析结果
class DoubaoParseResult {
  final bool success;
  final double amount;
  final String recordType;      // "expense" | "income"
  final String category;        // 分类名
  final String description;     // 描述
  final String? recognizedText;  // ASR原始识别文本
  final String? error;           // 错误信息

  DoubaoParseResult({
    required this.success,
    this.amount = 0,
    this.recordType = 'expense',
    this.category = '其他',
    this.description = '',
    this.recognizedText,
    this.error,
  });

  @override
  String toString() {
    return 'DoubaoParseResult: {amount: $amount, type: $recordType, category: $category, desc: $description}';
  }
}

// 全局单例
final doubaoApiService = DoubaoApiService();
