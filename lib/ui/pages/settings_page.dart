import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../models/version_info.dart';
import '../../core/api/api_client.dart';
import 'category_manage_page.dart';
import 'budget_page.dart';
import 'fixed_expense_page.dart';
import 'user_profile_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  String? _username;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final response = await apiClient.get('/api/users/me');
      setState(() {
        _username = response.data['username'];
        _avatarUrl = response.data['avatar_url'];
      });
    } catch (e) {
      // 使用默认用户名
      setState(() {
        _username = 'user3';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 小红书风格配色
    const primaryColor = Color(0xFFFF6B6B);
    const backgroundColor = Color(0xFFFFF8F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 用户信息卡片
          _buildUserCard(context),
          
          const SizedBox(height: 16),
          
          // 设置列表
          _buildSection(
            '通用设置',
            [
              _buildSettingItem(
                context,
                icon: Icons.notifications_outlined,
                title: '消息通知',
                subtitle: '记账提醒、预算提醒',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.language,
                title: '语言',
                subtitle: '简体中文',
                onTap: () {},
              ),
              _buildSettingItem(
                context,
                icon: Icons.attach_money,
                title: '货币',
                subtitle: '人民币 (¥)',
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildSection(
            '数据管理',
            [
              _buildSettingItem(
                context,
                icon: Icons.savings_outlined,
                iconColor: const Color(0xFF4CAF50),
                title: '预算设置',
                subtitle: '设置月度预算，追踪支出',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetPage())),
              ),
              _buildSettingItem(
                context,
                icon: Icons.repeat_outlined,
                iconColor: const Color(0xFFFF9A3C),
                title: '月固定费用',
                subtitle: '房租、社保、医保等固定支出',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedExpensePage())),
              ),
              _buildSettingItem(
                context,
                icon: Icons.category_outlined,
                iconColor: const Color(0xFF9B6DFF),
                title: '分类管理',
                subtitle: '自定义支出/收入分类',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagePage())),
              ),
              _buildSettingItem(
                context,
                icon: Icons.backup_outlined,
                iconColor: const Color(0xFF2196F3),
                title: '数据备份',
                subtitle: '备份到云端',
                onTap: () => _showBackupDialog(context),
              ),
              _buildSettingItem(
                context,
                icon: Icons.restore,
                iconColor: const Color(0xFF00BCD4),
                title: '数据恢复',
                subtitle: '从云端恢复数据',
                onTap: () {},
              ),
              _buildSettingItem(
                context,
                icon: Icons.file_download_outlined,
                iconColor: const Color(0xFF607D8B),
                title: '导出数据',
                subtitle: '导出Excel/CSV',
                onTap: () => _showExportDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildSection(
            '其他',
            [
              _buildSettingItem(
                context,
                icon: Icons.system_update_alt,
                iconColor: const Color(0xFF2196F3),
                title: '软件更新',
                trailing: _isCheckingUpdate
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onTap: _checkForUpdate,
              ),
              _buildSettingItem(
                context,
                icon: Icons.logout,
                iconColor: Colors.red,
                title: '退出登录',
                titleColor: Colors.red,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSection(
            '关于',
            [
              _buildSettingItem(
                context,
                icon: Icons.info_outline,
                iconColor: const Color(0xFF607D8B),
                title: '关于我们',
                subtitle: '版本 1.0.0',
                onTap: () => _showAboutDialog(context),
              ),
              _buildSettingItem(
                context,
                icon: Icons.star_outline,
                iconColor: const Color(0xFFFFC107),
                title: '给我们评分',
                onTap: () {},
              ),
              _buildSettingItem(
                context,
                icon: Icons.feedback_outlined,
                iconColor: const Color(0xFF4CAF50),
                title: '意见反馈',
                onTap: () => _showFeedbackDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    
    setState(() => _isCheckingUpdate = true);
    
    try {
      final updateInfo = await _updateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUpdateDialog(updateInfo);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showUpdateDialog(VersionInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => _UpdateDialog(versionInfo: updateInfo, updateService: _updateService),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfilePage()),
        );
        // 返回后刷新用户信息
        _loadUserInfo();
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C8C), Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
                image: _avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage('http://114.132.171.188$_avatarUrl'),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _avatarUrl == null
                  ? const Icon(Icons.person, size: 40, color: Color(0xFFFF6B6B))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username ?? 'user3',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '个人版用户',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? const Color(0xFFFF6B6B)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? const Color(0xFFFF6B6B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? const Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing else if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据备份'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('数据已自动同步到云端'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('导出为 Excel'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在导出...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('导出为 CSV'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在导出...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '金算盘',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.calculate, size: 48, color: Color(0xFFFF6B6B)),
      children: const [
        Text('智能语音记账，轻松管理每一笔'),
        SizedBox(height: 16),
        Text('支持语音记账、拍照识别、AI智能分类'),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('意见反馈'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '请输入您的宝贵意见...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('感谢您的反馈!')));
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
  }
}

/// 更新对话框组件
class _UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;
  final UpdateService updateService;

  const _UpdateDialog({required this.versionInfo, required this.updateService});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _downloadProgress = 0;
  bool _isDownloading = false;
  String? _downloadMessage;

  Future<void> _startUpdate() async {
    setState(() { _isDownloading = true; _downloadProgress = 0; _downloadMessage = '正在下载...'; });

    final result = await widget.updateService.downloadAndInstall(
      widget.versionInfo,
      onProgress: (progress) {
        if (mounted) setState(() { _downloadProgress = progress; _downloadMessage = '下载中 ${(progress * 100).toStringAsFixed(0)}%'; });
      },
    );

    if (mounted) {
      if (result.success) {
        setState(() => _downloadMessage = '正在打开安装程序...');
        Future.delayed(const Duration(seconds: 1), () { if (mounted) Navigator.of(context).pop(); });
      } else {
        setState(() { _isDownloading = false; _downloadMessage = result.message; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt, color: Colors.blue),
          const SizedBox(width: 8),
          Text('发现新版本 v${widget.versionInfo.version}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.versionInfo.updateLog.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(child: Text(widget.versionInfo.updateLog, style: const TextStyle(fontSize: 13))),
            ),
            const SizedBox(height: 16),
          ],
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 8),
            Text(_downloadMessage ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (_downloadMessage != null && _downloadMessage!.contains('失败'))
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_downloadMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        if (widget.versionInfo.isForceUpdate && !_isDownloading) const SizedBox.shrink()
        else if (!_isDownloading) ...[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('稍后再说')),
          ElevatedButton(onPressed: _startUpdate, child: const Text('立即更新')),
        ]
        else ...[
          if (!_downloadMessage!.contains('正在打开')) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        ],
      ],
    );
  }
}