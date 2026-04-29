import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../models/version_info.dart';
import '../core/constants/app_config.dart';

/// 自动更新服务
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final Dio _dio = Dio();

  /// 后端API基础URL
  String get _baseUrl => AppConfig.apiBaseUrl;

  /// 获取当前版本信息
  Future<({String version, int versionCode})> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
    return (version: version, versionCode: buildNumber);
  }

  /// 检查更新
  Future<VersionInfo?> checkForUpdate() async {
    try {
      final current = await getCurrentVersion();

      final response = await _dio.get(
        '$_baseUrl/api/version/latest',
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final versionInfo = VersionInfo.fromJson(response.data);

        // 检查是否需要更新
        if (versionInfo.needsUpdate(current.version, current.versionCode)) {
          return versionInfo;
        }
      }
      return null;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      return null;
    }
  }

  /// 下载并安装APK
  Future<({bool success, String? message, double progress})> downloadAndInstall(
    VersionInfo versionInfo, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 请求存储权限（Android 13以下需要）
      if (Platform.isAndroid && await _needStoragePermission()) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          return (success: false, message: '需要存储权限才能下载更新', progress: 0.0);
        }
      }

      // 获取下载目录
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return (success: false, message: '无法访问存储目录', progress: 0.0);
      }

      final fileName = 'accounting_app_${versionInfo.version}.apk';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 如果已下载，跳过下载步骤
      if (await file.exists()) {
        await file.delete();
      }

      // 下载APK
      debugPrint('开始下载: ${versionInfo.downloadUrl}');

      await _dio.download(
        versionInfo.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
            debugPrint('下载进度: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      debugPrint('下载完成: $filePath');

      // 安装APK
      final installResult = await _installApk(filePath);
      return (success: installResult.success, message: installResult.message, progress: 1.0);
    } catch (e) {
      debugPrint('下载安装失败: $e');
      return (success: false, message: '下载失败: $e', progress: 0.0);
    }
  }

  /// 安装APK
  Future<({bool success, String? message})> _installApk(String filePath) async {
    try {
      // 使用open_filex打开APK，系统会自动弹出安装界面
      final result = await OpenFilex.open(filePath);

      if (result.type == ResultType.done) {
        return (success: true, message: '正在打开安装程序...');
      } else {
        return (success: false, message: '打开安装程序失败: ${result.message}');
      }
    } catch (e) {
      return (success: false, message: '安装失败: $e');
    }
  }

  /// 检查是否需要存储权限（Android 13以下）
  Future<bool> _needStoragePermission() async {
    if (!Platform.isAndroid) return false;

    // Android 13 (API 33) 以上不需要存储权限
    final sdkInt = await _getAndroidSdkInt();
    return sdkInt < 33;
  }

  Future<int> _getAndroidSdkInt() async {
    try {
      // 这里简化处理，假设是Android 10+
      return 30;
    } catch (_) {
      return 30;
    }
  }
}
