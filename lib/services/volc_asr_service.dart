import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_config.dart';

/// 火山引擎语音识别服务
/// 使用语音服务专用 API Key 认证
///
/// 完整流程：麦克风录音 → 语音服务Key认证 → 火山ASR极速识别2.0 → 文字
class VolcAsrService {
  final Dio _dio = Dio();
  final AudioRecorder _recorder = AudioRecorder();
  String? _tempAudioPath;

  // ══════════════════════════════════════════════════════════════
  // ASR 识别（录音文件极速识别2.0）
  // 端点: POST /api/v3/auc/bigmodel/recognize/flash
  // 认证: X-Api-Key: { volcAsrApiKey }
  // 资源ID: volc.seedasr.auc (2.0版本)
  // ══════════════════════════════════════════════════════════════

  /// 语音识别（录音文件极速识别 - 一次请求直接返回）
  Future<String> recognizeFromBase64(String audioBase64, {String format = 'wav'}) async {
    try {
      final taskId = _generateUuid();

      debugPrint('ASR Request: taskId=$taskId, format=$format, dataLen=${audioBase64.length}');

      final response = await _dio.post(
        AppConfig.volcAsrFlashUrl,
        options: Options(
          headers: {
            'X-Api-Key': AppConfig.volcAsrApiKey,
            'X-Api-Resource-Id': AppConfig.volcAsrResourceId,
            'X-Api-Request-Id': taskId,
            'X-Api-Sequence': '-1',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'user': {
            'uid': AppConfig.volcAsrApiKey,
          },
          'audio': {
            'data': audioBase64,
          },
          'request': {
            'model_name': 'bigmodel',
            'enable_itn': true,
            'enable_punc': true,
            'enable_ddc': true,
          },
        },
      );

      debugPrint('ASR Response: status=${response.statusCode}');

      if (response.statusCode == 200) {
        final statusCode = response.headers.value('X-Api-Status-Code');
        final statusMessage = response.headers.value('X-Api-Message') ?? 'OK';
        debugPrint('ASR API Status: $statusCode - $statusMessage');

        // 成功状态码
        // 10000000 = 有识别结果
        // 20000000/20000001/20000002/20000003 = 成功(可能无语音)
        if (statusCode == '10000000' ||
            statusCode == '20000000' ||
            statusCode == '20000001' ||
            statusCode == '20000002' ||
            statusCode == '20000003') {
          final result = response.data['result'];
          if (result != null) {
            final text = result['text'] ?? '';
            debugPrint('ASR Text: "$text"');
            return text;
          }
          // 有结果但text为空
          debugPrint('ASR: No speech detected (empty text)');
          return '';
        }

        throw Exception('ASR识别失败: [$statusCode] $statusMessage');
      }

      throw Exception('请求失败: ${response.statusCode}');
    } catch (e) {
      debugPrint('ASR Error: $e');
      throw Exception('语音识别失败: $e');
    }
  }

  /// 从文件路径识别音频（支持WAV和AAC格式）
  Future<String> recognizeFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      debugPrint('File: $filePath, size: ${bytes.length} bytes');

      // 检测文件格式
      final ext = filePath.split('.').last.toLowerCase();
      String format = 'wav';

      if (ext == 'aac' || ext == 'm4a') {
        format = 'aac';
        // AAC格式直接使用
        final audioBase64 = base64Encode(bytes);
        return recognizeFromBase64(audioBase64, format: format);
      } else if (ext == 'wav') {
        // WAV格式需要检查文件头
        final audioBase64 = base64Encode(bytes);
        return recognizeFromBase64(audioBase64, format: 'wav');
      } else if (ext == 'mp3') {
        format = 'mp3';
        final audioBase64 = base64Encode(bytes);
        return recognizeFromBase64(audioBase64, format: format);
      }

      // 其他格式，统一尝试WAV
      final audioBase64 = base64Encode(bytes);
      return recognizeFromBase64(audioBase64);
    } catch (e) {
      throw Exception('文件识别失败: $e');
    }
  }

  /// 生成UUID
  String _generateUuid() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  String _randomHex(int length) {
    final random = DateTime.now().microsecondsSinceEpoch;
    return random.toRadixString(16).padLeft(length, '0').substring(0, length);
  }

  // ══════════════════════════════════════════════════════════════
  // 录音控制
  // ══════════════════════════════════════════════════════════════

  /// 开始录音（使用AAC编码，兼容性更好）
  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _tempAudioPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

        // 使用 AAC 编码，这是移动端最通用的格式
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,  // AAC-LC 编码
            sampleRate: 16000,
            bitRate: 64000,
            numChannels: 1,
          ),
          path: _tempAudioPath!,
        );

        debugPrint('Recording started: $_tempAudioPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('开始录音失败: $e');
      return false;
    }
  }

  /// 停止录音并识别
  Future<String> stopRecordingAndRecognize() async {
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        debugPrint('Recording stopped: $path');
        return recognizeFromFile(path);
      }
      throw Exception('录音文件无效');
    } catch (e) {
      throw Exception('停止录音识别失败: $e');
    }
  }

  /// 录音指定时长并识别
  Future<String> recordAndRecognize({Duration duration = const Duration(seconds: 5)}) async {
    try {
      if (!await startRecording()) {
        throw Exception('无法访问麦克风');
      }

      await Future.delayed(duration);
      return stopRecordingAndRecognize();
    } catch (e) {
      throw Exception('录音识别失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _recorder.dispose();
  }
}
