/// 版本信息模型
class VersionInfo {
  final String version;       // 版本号 (如 "1.0.1")
  final int versionCode;      // 版本码 (如 2)
  final String downloadUrl;   // APK下载地址
  final String updateLog;     // 更新日志
  final int apkSize;          // APK大小(字节)
  final bool isForceUpdate;   // 是否强制更新

  VersionInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    this.updateLog = '',
    this.apkSize = 0,
    this.isForceUpdate = false,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] ?? '',
      versionCode: json['version_code'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      updateLog: json['update_log'] ?? '',
      apkSize: json['apk_size'] ?? 0,
      isForceUpdate: json['is_force_update'] ?? false,
    );
  }

  /// 格式化APK大小
  String get formattedSize {
    if (apkSize < 1024) return '$apkSize B';
    if (apkSize < 1024 * 1024) return '${(apkSize / 1024).toStringAsFixed(1)} KB';
    return '${(apkSize / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// 比较版本，返回true如果需要更新
  bool needsUpdate(String currentVersion, int currentVersionCode) {
    // 版本号比较 (如 "1.0.0" vs "1.0.1")
    List<int> currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> newParts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (currentParts.length < 3) currentParts.add(0);
    while (newParts.length < 3) newParts.add(0);

    for (int i = 0; i < 3; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    // 版本号比较
    return versionCode > currentVersionCode;
  }
}
