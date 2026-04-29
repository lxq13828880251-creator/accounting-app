# 移动端 APP 设计方案

## 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| **框架** | Flutter 3.x | 跨平台(iOS/Android) |
| **状态管理** | Riverpod | Flutter官方推荐 |
| **网络** | Dio | 成熟稳定 |
| **本地存储** | Hive | 轻量级KV数据库 |
| **语音** | 火山引擎 ASR SDK | 语音转文字 |
| **图像** | 火山引擎 OCR SDK | 发票/小票识别 |

## 项目结构

```
accounting_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/              # API客户端
│   │   │   ├── api_client.dart
│   │   │   └── api_config.dart
│   │   ├── constants/        # 常量配置
│   │   │   └── app_config.dart
│   │   └── utils/           # 工具函数
│   │       └── format_utils.dart
│   ├── data/
│   │   ├── models/          # 数据模型
│   │   │   ├── record.dart
│   │   │   ├── category.dart
│   │   │   └── user.dart
│   │   ├── repositories/    # 数据仓库
│   │   │   └── record_repository.dart
│   │   └── providers/       # Riverpod providers
│   │       └── auth_provider.dart
│   ├── services/
│   │   ├── auth_service.dart      # 认证服务
│   │   ├── volc_asr_service.dart  # 火山语音识别
│   │   ├── volc_ocr_service.dart  # 火山图像识别
│   │   └── ai_parse_service.dart  # AI解析服务
│   ├── ui/
│   │   ├── pages/
│   │   │   ├── login_page.dart
│   │   │   ├── home_page.dart
│   │   │   ├── add_record_page.dart
│   │   │   ├── records_page.dart
│   │   │   └── stats_page.dart
│   │   └── widgets/
│   │       ├── record_card.dart
│   │       ├── category_selector.dart
│   │       └── voice_input_button.dart
│   └── routes/
│       └── app_routes.dart
├── pubspec.yaml
└── android/ios/
```

## 功能模块

### 1. 语音记账
```
用户按住说话 → 录音 → 火山ASR → 文字 → AI解析 → 生成记录
```

### 2. 拍照记账
```
拍照/选图 → 火山OCR → 识别文字 → AI解析 → 生成记录
```

### 3. 手动记账
```
选择分类 → 输入金额 → 确认 → 保存
```

## API对接

### 后端API (已部署)
```dart
// 登录
POST /api/auth/token
Body: { username, password }

// 创建记录
POST /api/records/
Body: { amount, category_id, record_type, record_date, description }

// AI解析
POST /api/ai/parse
Body: { text }
```

### 火山引擎API

```dart
// ASR语音识别
POST https://openspeech.bytedance.com/api/v3/asr
Headers: {
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: {
  "appid": "<app_id>",
  "audio_file": "<base64>",
  "format": "wav",
  "rate": 16000
}

// OCR通用识别
POST https://visual.volcengineapi.com/?Action=GeneralOcr
Headers: {
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: {
  "image_base64": "<image_data>"
}
```

## 凭证配置

```dart
// lib/core/constants/app_config.dart

class AppConfig {
  // 火山引擎 - 请替换为你的API Key
  static const String volcAccessKey = 'YOUR_ACCESS_KEY';
  static const String volcSecretKey = 'YOUR_SECRET_KEY';
  
  // 后端API
  static const String apiBaseUrl = 'http://YOUR_SERVER_IP:8000';
}
```

## 页面流程

```
启动 → 登录页 → 首页(仪表盘)
                  ↓
         ┌───────┼───────┐
         ↓       ↓       ↓
      语音记账  拍照记账  手动记账
         ↓       ↓       ↓
      AI解析 → 确认 → 保存
```

## 开发计划

| 阶段 | 内容 | 优先级 |
|------|------|--------|
| 1 | 项目初始化 + 登录 | P0 |
| 2 | 首页仪表盘 | P0 |
| 3 | 手动记账功能 | P0 |
| 4 | 语音记账(火山ASR) | P1 |
| 5 | 拍照记账(火山OCR) | P1 |
| 6 | 统计图表 | P2 |
