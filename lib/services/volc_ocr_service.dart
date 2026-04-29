import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_config.dart';

/// 火山引擎OCR识别服务
/// 统一使用 ARK API Key 认证
class VolcOcrService {
  final Dio _dio = Dio();

  // OCR API端点（使用通用OCR接口）
  static const String _ocrUrl = 'https://ark.cn-beijing.volces.com/api/v3/ocr/general';

  /// OCR识别（使用ARK Key）
  Future<OcrResult> recognizeFromBase64(String imageBase64) async {
    try {
      final response = await _dio.post(
        _ocrUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.arkApiKey}',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'image_base64': imageBase64,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final texts = <String>[];

        if (data['err_no'] == 0 || data['code'] == 1000) {
          if (data['data'] != null) {
            final items = data['data']['text_result'] ?? data['data']['TextDetections'] ?? [];
            for (var item in items) {
              texts.add(item['text'] ?? item['DetectedText'] ?? '');
            }
          }
        } else {
          throw Exception(data['err_msg'] ?? data['message'] ?? '识别失败');
        }

        return OcrResult(
          success: true,
          texts: texts,
          amounts: _extractAmounts(texts.join(' ')),
        );
      }

      throw Exception('请求失败: ${response.statusCode}');
    } catch (e) {
      return OcrResult(
        success: false,
        error: e.toString(),
        texts: [],
        amounts: [],
      );
    }
  }

  /// 发票OCR识别
  Future<OcrResult> recognizeInvoice(String imagePath) async {
    try {
      return recognizeFromBase64(imagePath);
    } catch (e) {
      return OcrResult(
        success: false,
        error: e.toString(),
        texts: [],
        amounts: [],
      );
    }
  }

  /// 从文本中提取金额
  List<double> _extractAmounts(String text) {
    final amounts = <double>[];
    final regex = RegExp(r'[¥￥$]?\s*(\d+\.?\d{0,2})');
    final matches = regex.allMatches(text);

    for (var match in matches) {
      final amount = double.tryParse(match.group(1) ?? '');
      if (amount != null && amount > 0 && amount < 1000000) {
        amounts.add(amount);
      }
    }

    return amounts;
  }
}

/// OCR识别结果
class OcrResult {
  final bool success;
  final String? error;
  final List<String> texts;
  final List<double> amounts;

  OcrResult({
    required this.success,
    this.error,
    required this.texts,
    required this.amounts,
  });

  String get combinedText => texts.join('\n');

  double? get maxAmount => amounts.isNotEmpty ? amounts.reduce((a, b) => a > b ? a : b) : null;
}
