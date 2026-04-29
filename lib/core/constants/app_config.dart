class AppConfig {
  static const String appName = '金算盘';

  // 后端API
  static const String apiBaseUrl = 'http://114.132.171.188';
  static const String wsBaseUrl = 'ws://114.132.171.188';

  // ══════════════════════════════════════════════
  // 方舟控制台 - ARK API Key（豆包大模型统一凭证）
  // ══════════════════════════════════════════════
  static const String arkApiKey = 'fcf26a87-83ae-4afe-a8b6-18782e05aa75';

  // 豆包大模型 API Base（聊天/解析）
  static const String arkApiBaseUrl = 'https://ark.cn-beijing.volces.com/api/v3';

  // ══════════════════════════════════════════════
  // 火山引擎语音服务 - ASR 专用 API Key
  // ══════════════════════════════════════════════
  static const String volcAsrApiKey = '6e793ca0-a792-42f5-a96a-7a11d86ee282';
  static const String volcAsrResourceId = 'volc.seedasr.auc';

  // 火山ASR API（录音文件极速识别2.0）
  static const String volcApiBaseUrl = 'https://openspeech.bytedance.com/api/v3';
  static const String volcAsrFlashUrl = volcApiBaseUrl + '/auc/bigmodel/recognize/flash';

  // 本地存储Key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_info';

  // 录音配置
  static const int sampleRate = 16000;
  static const int maxDuration = 60; // 秒
}
