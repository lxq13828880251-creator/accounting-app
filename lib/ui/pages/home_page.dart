import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/record.dart';
import '../../core/models/category.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../services/budget_service.dart';
import '../../services/volc_asr_service.dart';
import '../../services/ai_parse_service.dart';
import '../../models/version_info.dart';
import 'add_record_page.dart';
import 'records_page.dart';
import 'stats_page.dart';
import 'settings_page.dart';
import 'budget_page.dart';
import 'bill_import_page.dart';

/// 月度统计Provider
final monthlyStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final response = await apiClient.get('/api/stats/monthly', params: {
    'year': now.year,
    'month': now.month,
  });
  return response.data;
});

/// 最近记录Provider
final recordsProvider = FutureProvider.autoDispose<List<Record>>((ref) async {
  try {
    final response = await apiClient.get('/api/records/', params: {'page_size': 100, 'limit': 100});
    List data = [];
    if (response.data is List) {
      data = response.data;
    } else if (response.data is Map) {
      final mapData = response.data as Map<String, dynamic>;
      if (mapData.containsKey('items') && mapData['items'] is List) {
        data = mapData['items'];
      } else if (mapData.containsKey('data') && mapData['data'] is List) {
        data = mapData['data'];
      } else if (mapData.containsKey('records') && mapData['records'] is List) {
        data = mapData['records'];
      }
    }
    return data.map((e) => Record.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    return [];
  }
});

/// 分类Provider
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final response = await apiClient.get('/api/categories/');
  final List data = response.data;
  return data.map((e) => Category.fromJson(e)).toList();
});

/// 预算使用情况Provider
final budgetUsageProvider = FutureProvider.autoDispose<BudgetUsage>((ref) async {
  final now = DateTime.now();
  final service = BudgetService();
  await service.init();
  return service.getBudgetUsage(now.year, now.month);
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkForUpdate(silent: true));
  }

  /// 刷新首页所有数据
  void _refreshHomeData() {
    ref.invalidate(monthlyStatsProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(budgetUsageProvider);
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    try {
      final updateInfo = await _updateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUpdateDialog(updateInfo);
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _showUpdateDialog(VersionInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => UpdateDialog(versionInfo: updateInfo, updateService: _updateService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [_DashboardTab(), RecordsPage(), StatsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            // 记账按钮直接跳转
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddRecordPage())).then((_) {
              // 记账完成后刷新首页数据
              _refreshHomeData();
            });
          } else {
            // 切换回首页时，强制刷新数据
            if (index == 0 && _currentIndex != 0) {
              _refreshHomeData();
            }
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined, color: Color(0xFF8E8E8E)), selectedIcon: Icon(Icons.home, color: Color(0xFFFF6B6B)), label: '首页'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF8E8E8E)), selectedIcon: Icon(Icons.receipt_long, color: Color(0xFFFF6B6B)), label: '记录'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline, color: Color(0xFF8E8E8E)), selectedIcon: Icon(Icons.add_circle, color: Color(0xFFFF6B6B)), label: '记账'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined, color: Color(0xFF8E8E8E)), selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFFF6B6B)), label: '统计'),
        ],
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;
  final UpdateService updateService;

  const UpdateDialog({super.key, required this.versionInfo, required this.updateService});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '更新失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [const Icon(Icons.system_update, color: Colors.blue), const SizedBox(width: 8), Text('发现新版本 v${widget.versionInfo.version}')]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Text('版本: ', style: TextStyle(color: Colors.grey)), Text(widget.versionInfo.version), const SizedBox(width: 16), const Text('大小: ', style: TextStyle(color: Colors.grey)), Text(widget.versionInfo.formattedSize)]),
          const SizedBox(height: 16),
          if (widget.versionInfo.updateLog.isNotEmpty) ...[
            const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(constraints: const BoxConstraints(maxHeight: 150), child: SingleChildScrollView(child: Text(widget.versionInfo.updateLog, style: const TextStyle(fontSize: 13)))),
            const SizedBox(height: 16),
          ],
          if (_isDownloading) ...[LinearProgressIndicator(value: _downloadProgress), const SizedBox(height: 8), Text(_downloadMessage ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))],
          if (_downloadMessage != null && _downloadMessage!.contains('失败')) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_downloadMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 12))),
        ],
      ),
      actions: [
        if (widget.versionInfo.isForceUpdate && !_isDownloading) const SizedBox.shrink()
        else if (!_isDownloading) ...[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('稍后再说')), ElevatedButton(onPressed: _startUpdate, child: const Text('立即更新'))]
        else ...[if (!_downloadMessage!.contains('正在打开')) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消'))],
      ],
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        title: const Text(
          '金算盘',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: '导入账单',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillImportPage())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(monthlyStatsProvider);
              ref.invalidate(recordsProvider);
              ref.invalidate(budgetUsageProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: _DashboardContent(),
    );
  }
}

/// 首页内容组件（独立出来以支持自动刷新）
class _DashboardContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> with WidgetsBindingObserver {
  // 定期自动刷新Timer（5分钟）
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 启动定期自动刷新：每5分钟刷新一次
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshAll() {
    if (mounted) {
      ref.invalidate(monthlyStatsProvider);
      ref.invalidate(recordsProvider);
      ref.invalidate(budgetUsageProvider);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当App从后台恢复到前台时，立即刷新数据
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(monthlyStatsProvider);
    ref.watch(recordsProvider); // 监听记录变更，触发重建
    final budgetUsageAsync = ref.watch(budgetUsageProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyStatsProvider);
        ref.invalidate(recordsProvider);
        ref.invalidate(budgetUsageProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本月综合卡片（概览 + 预算）
            budgetUsageAsync.when(
              data: (usage) => statsAsync.when(
                data: (stats) => _buildCombinedCard(context, stats, usage),
                loading: () => _buildBudgetCard(context, usage),
                error: (err, __) => _buildNetworkErrorCard(context, err),
              ),
              loading: () => statsAsync.when(
                data: (stats) => _buildOverviewCard(context, stats),
                loading: () => _buildLoadingCard(),
                error: (err, __) => _buildNetworkErrorCard(context, err),
              ),
              error: (err, __) => _buildNetworkErrorCard(context, err),
            ),
            const SizedBox(height: 20),

            // 快速记账入口
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Text('记账方式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                  const Spacer(),
                  Text('选择一种方式快速记', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            _buildQuickActions(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 综合卡片：小红书风格
  Widget _buildCombinedCard(BuildContext context, Map<String, dynamic> stats, BudgetUsage usage) {
    final income = ((stats['income'] ?? stats['total_income'] ?? 0) as num).toDouble();
    final expense = ((stats['expense'] ?? stats['total_expense'] ?? 0) as num).toDouble();
    final actualBalance = income - expense;
    final budgetRemaining = (usage.budget?.totalBudget ?? 0) - expense;
    final ratio = usage.budget != null ? usage.usageRatio.clamp(0.0, 1.0) : 0.0;
    final progressColor = _getProgressColor(ratio);
    final isOverBudget = usage.remaining < 0;
    // 超支显示红色渐变，未超支显示绿色渐变
    final gradientColors = isOverBudget
        ? [const Color(0xFFFF6B6B), const Color(0xFFFF4757)] // 红色渐变
        : [const Color(0xFF26DE81), const Color(0xFF20BF6A)]; // 绿色渐变

    return Column(
      children: [
        // 主卡片 - 渐变头部 + 白色身体
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // 渐变头部
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '本月预算结余',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${budgetRemaining < 0 ? "-" : ""}¥${budgetRemaining.abs().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            if (usage.budget == null)
                              const Text(
                                '（未设置预算）',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                          ],
                        ),
                        _buildMonthBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMiniStat('收入', income, Colors.white),
                        Container(width: 1, height: 32, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
                        _buildMiniStat('支出', expense, Colors.white),
                        Container(width: 1, height: 32, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
                        _buildMiniStat('结余', actualBalance, Colors.white),
                      ],
                    ),
                  ],
                ),
              ),

              // 预算进度条（如果有预算）
              if (usage.budget != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.savings, color: const Color(0xFFFF6B6B), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('预算', style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
                                  Text(
                                    '¥${usage.budget!.totalBudget.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D2D2D)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              usage.remaining >= 0
                                  ? Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F8F0),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '剩余 ¥${usage.remaining.toStringAsFixed(0)}',
                                          style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                  : Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE8E8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '超支 ¥${usage.remaining.abs().toStringAsFixed(0)}',
                                          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: progressColor == const Color(0xFFFF6B6B)
                                        ? const Color(0xFFFFE8E8)
                                        : const Color(0xFFFFF0F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(ratio * 100).toInt()}%',
                                    style: TextStyle(
                                      color: progressColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF5F0EB),
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const BudgetPage()),
                      );
                      if (result == true && mounted) {
                        ref.invalidate(monthlyStatsProvider);
                        ref.invalidate(recordsProvider);
                        ref.invalidate(budgetUsageProvider);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Color(0xFFFF6B6B), size: 18),
                          SizedBox(width: 6),
                          Text('设置本月预算', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 迷你统计列（用于渐变头部）
  Widget _buildMiniStat(String label, double value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '¥${value.abs().toStringAsFixed(0)}',
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 独立预算卡片（无统计时）
  Widget _buildBudgetCard(BuildContext context, BudgetUsage usage) {
    if (usage.budget != null) {
      return _buildBudgetProgressCard(context, usage);
    }
    return _buildBudgetSetupCard(context);
  }

  /// 获取情感化问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，早点休息哦~';
    if (hour < 9) return '早上好~今天也要元气满满';
    if (hour < 12) return '上午好~今天也要加油';
    if (hour < 14) return '中午好~记得吃午饭哦';
    if (hour < 18) return '下午好~今天辛苦了';
    if (hour < 21) return '晚上好~今天过得好吗';
    return '夜深了，早点休息哦~';
  }

  /// 获取结余提示文案
  String _getBalanceTip(double actualBalance, double income, double expense) {
    if (income == 0 && expense == 0) {
      return '今天还没有记账哦，快记一笔吧~';
    }
    if (actualBalance > 0) {
      final percent = (actualBalance / income * 100).toStringAsFixed(0);
      return '结余率 ${percent}%，继续保持~';
    } else if (actualBalance < 0) {
      return '稍微超支了，明天要控制一下哦';
    }
    return '收支平衡，继续努力~';
  }

  Widget _buildOverviewCard(BuildContext context, Map<String, dynamic> stats) {
    final income = ((stats['income'] ?? stats['total_income'] ?? 0) as num).toDouble();
    final expense = ((stats['expense'] ?? stats['total_expense'] ?? 0) as num).toDouble();
    final actualBalance = income - expense;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C8C), Color(0xFFFF6B6B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 情感化问候语
          Row(
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              if (income > 0 || expense > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getBalanceTip(actualBalance, income, expense),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本月实际结余', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '¥${actualBalance.abs().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ],
              ),
              _buildMonthBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('收入', income, Colors.white),
              Container(width: 1, height: 32, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _buildMiniStat('支出', expense, Colors.white),
              Container(width: 1, height: 32, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _buildMiniStat('结余', actualBalance, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBadge() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        '${now.month}月',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
  /// 预算进度卡片
  Widget _buildBudgetProgressCard(BuildContext context, BudgetUsage usage) {
    final ratio = usage.usageRatio.clamp(0.0, 1.0);
    final color = _getProgressColor(ratio);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const BudgetPage()),
          );
          if (result == true && mounted) {
            ref.invalidate(monthlyStatsProvider);
            ref.invalidate(recordsProvider);
            ref.invalidate(budgetUsageProvider);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.savings, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本月预算: ¥${usage.budget!.totalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio, minHeight: 6,
                        backgroundColor: const Color(0xFFF5F0EB),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(ratio * 100).toInt()}%',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    usage.remaining >= 0 ? '剩¥${usage.remaining.toStringAsFixed(0)}' : '超¥${usage.remaining.abs().toStringAsFixed(0)}',
                    style: TextStyle(color: usage.remaining >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  /// 预算设置引导卡片
  Widget _buildBudgetSetupCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const BudgetPage()),
          );
          if (result == true && mounted) {
            ref.invalidate(monthlyStatsProvider);
            ref.invalidate(recordsProvider);
            ref.invalidate(budgetUsageProvider);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.savings_outlined, color: Color(0xFFFF6B6B), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('设置月度预算', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D2D2D))),
                    const SizedBox(height: 4),
                    Text('智能管理支出，避免超支', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('去设置', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double ratio) {
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= 0.8) return Colors.orange;
    if (ratio >= 0.5) return Colors.amber;
    return Colors.green;
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VoiceRecordButton(onRecordComplete: (text) {
            if (text.isNotEmpty) {
              _navigateToRecordPage(context, text);
            }
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.camera_alt,
            label: '拍照记账',
            bgColor: const Color(0xFFFFF8E6),
            iconColor: const Color(0xFFFF9A3C),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddRecordPage(initialMode: 'camera'))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.edit_note,
            label: '手动记账',
            bgColor: const Color(0xFFF0E8FF),
            iconColor: const Color(0xFF9B6DFF),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddRecordPage())),
          ),
        ),
      ],
    );
  }

  /// 跳转到记账页并自动填充
  Future<void> _navigateToRecordPage(BuildContext context, String recognizedText) async {
    final aiService = AiParseService();
    
    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在识别...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // AI解析
      final parseResult = await aiService.parseText(recognizedText);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭加载框
        
        // 跳转到记账页
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddRecordPage(
              initialMode: 'voice',
              prefillData: AddRecordPrefill(
                recognizedText: recognizedText,
                amount: parseResult.amount,
                recordType: parseResult.recordType,
                categoryName: parseResult.categoryName,
                description: parseResult.description,
                recordDate: parseResult.recordDate.isEmpty ? DateTime.now() : DateTime.tryParse(parseResult.recordDate) ?? DateTime.now(),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭加载框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B6B)),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Color(0xFFFF6B6B)))),
    );
  }

  /// 网络错误卡片：显示重试和重新登录按钮
  Widget _buildNetworkErrorCard(BuildContext context, Object err) {
    final errMsg = err.toString();
    // 判断是否为401/认证错误
    final isAuthError = errMsg.contains('401') || errMsg.contains('Unauthorized') || errMsg.contains('token');
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isAuthError ? Icons.lock_outline : Icons.wifi_off,
              color: Colors.orange.shade700,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              isAuthError ? '登录已过期' : '网络连接失败',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAuthError ? '请重新登录后查看数据' : '请检查网络，下拉可刷新',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshAll,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试'),
                ),
                if (isAuthError) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final authService = AuthService();
                      await authService.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('重新登录'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2D2D2D))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 按住录音按钮组件
class _VoiceRecordButton extends StatefulWidget {
  final Function(String) onRecordComplete;

  const _VoiceRecordButton({required this.onRecordComplete});

  @override
  State<_VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<_VoiceRecordButton> with SingleTickerProviderStateMixin {
  final VolcAsrService _asrService = VolcAsrService();
  bool _isRecording = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed && _isRecording) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    
    final hasPermission = await _asrService.startRecording();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法访问麦克风'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() => _isRecording = true);
    _animationController.forward();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    setState(() => _isRecording = false);
    _animationController.stop();
    _animationController.reset();
    
    try {
      final text = await _asrService.stopRecordingAndRecognize();
      if (text.isNotEmpty) {
        widget.onRecordComplete(text);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未识别到语音内容'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: GestureDetector(
        onTapDown: (_) => _startRecording(),
        onTapUp: (_) => _stopRecording(),
        onTapCancel: _stopRecording,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: _isRecording
                            ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8C8C)])
                            : const LinearGradient(colors: [Color(0xFFFFB3B3), Color(0xFFFFD6D6)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.mic,
                        color: _isRecording ? Colors.white : const Color(0xFFFF6B6B),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                _isRecording ? '松开发送' : '按住说话',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _isRecording ? const Color(0xFFFF6B6B) : const Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

