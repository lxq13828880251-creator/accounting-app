# 个人记账 APP - Flutter项目

## 项目概述

跨平台移动应用，支持语音记账、拍照识别、AI智能分类。

## 项目结构

```
accounting_app/
├── lib/
│   ├── main.dart                     # 应用入口
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart      # API客户端封装
│   │   ├── constants/
│   │   │   └── app_config.dart      # 应用配置（API地址、火山引擎凭证）
│   │   └── models/
│   │       ├── record.dart          # 记录模型
│   │       ├── category.dart        # 分类模型
│   │       └── user.dart            # 用户模型
│   ├── services/
│   │   ├── auth_service.dart        # 认证服务
│   │   ├── volc_asr_service.dart    # 火山引擎语音识别
│   │   ├── volc_ocr_service.dart    # 火山引擎图像识别
│   │   └── ai_parse_service.dart    # AI解析服务
│   ├── routes/
│   │   └── app_routes.dart          # 路由配置
│   └── ui/
│       └── pages/
│           ├── splash_page.dart      # 启动页
│           ├── login_page.dart       # 登录页
│           ├── home_page.dart        # 首页
│           ├── add_record_page.dart  # 添加记录页
│           ├── records_page.dart     # 记录列表页
│           └── stats_page.dart       # 统计页
├── pubspec.yaml                     # 依赖配置
└── README.md                        # 说明文档
```

## 环境要求

- Flutter SDK >= 3.0
- Dart SDK >= 3.0
- Android Studio / Xcode (iOS开发)

## 安装步骤

### 1. 安装Flutter SDK

**Windows:**
```bash
# 下载Flutter SDK
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.0-stable.zip

# 解压到任意目录 (例如 C:\flutter)
# 添加到系统PATH环境变量

# 验证安装
flutter doctor
```

**macOS:**
```bash
# 使用Homebrew安装
brew install flutter

# 或者下载安装包
https://docs.flutter.dev/get-started/install/macos
```

**Linux:**
```bash
# 下载Flutter SDK
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"
```

### 2. 配置Android SDK

```bash
flutter config --android-sdk /path/to/android/sdk
flutter doctor --android-licenses
```

### 3. 安装依赖

```bash
cd accounting_app
flutter pub get
```

### 4. 运行应用

**方式一：双击运行脚本**
```bash
# 双击运行这个脚本，会自动执行所有步骤
run_dev.bat
```

**方式二：手动命令**
```bash
# 获取依赖
flutter pub get

# 开发模式
flutter run

# 构建APK
flutter build apk --release

# 构建iOS
flutter build ios --release
```

## 配置说明

### 火山引擎凭证

在 `lib/core/constants/app_config.dart` 中配置：

```dart
class AppConfig {
  // 火山引擎语音识别
  static const String volcAccessKey = '你的AccessKeyID';
  static const String volcSecretKey = '你的SecretKey';  // 已解码
  
  // 后端API
  static const String apiBaseUrl = 'http://114.132.171.188:8000';
}
```

### 获取火山引擎凭证

1. 注册火山引擎账号: https://console.volcengine.com/
2. 创建应用获取 Access Key
3. 开通语音识别/OCR服务
4. 将凭证填入配置文件

## 功能特性

| 功能 | 说明 | 状态 |
|------|------|------|
| 用户登录 | JWT认证 | ✅ |
| 首页概览 | 月度收支统计 | ✅ |
| 语音记账 | 火山ASR识别 | ✅ |
| 拍照记账 | 火山OCR识别 | ✅ |
| 手动记账 | 分类+金额+日期 | ✅ |
| 记录列表 | 按日期分组 | ✅ |
| 统计图表 | 趋势+分类占比 | ✅ |
| AI解析 | 后端DeepSeek | ✅ |

## API对接

### 后端API

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/auth/token` | POST | 用户登录 |
| `/api/auth/me` | GET | 获取用户信息 |
| `/api/categories/` | GET | 获取分类列表 |
| `/api/records/` | GET/POST | 获取/创建记录 |
| `/api/stats/monthly` | GET | 月度统计 |
| `/api/ai/parse` | POST | AI文本解析 |

### 火山引擎API

| 服务 | API | 用途 |
|------|-----|------|
| 语音识别 | ASR | 语音转文字 |
| 图像识别 | OCR | 发票/小票识别 |

## 常见问题

### 1. 录音权限被拒绝
- iOS: 在 `ios/Runner/Info.plist` 添加 `NSMicrophoneUsageDescription`
- Android: 在 `android/app/src/main/AndroidManifest.xml` 添加 `RECORD_AUDIO` 权限

### 2. 相机权限被拒绝
- iOS: 在 `ios/Runner/Info.plist` 添加 `NSCameraUsageDescription`
- Android: 在 `android/app/src/main/AndroidManifest.xml` 添加 `CAMERA` 权限

### 3. 网络请求失败
- 检查 `lib/core/constants/app_config.dart` 中的API地址
- 确保后端服务正在运行

## 许可证

MIT License
