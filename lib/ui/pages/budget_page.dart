import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/budget.dart';
import '../../core/models/user.dart';
import '../../services/budget_service.dart';

/// 预算Provider
final budgetProvider = FutureProvider.autoDispose<Budget?>((ref) async {
  final service = BudgetService();
  await service.init();
  return service.getCurrentMonthBudget();
});

/// 预算使用情况Provider
final budgetUsageProvider = FutureProvider.autoDispose<BudgetUsage>((ref) async {
  final now = DateTime.now();
  final service = BudgetService();
  await service.init();
  return service.getBudgetUsage(now.year, now.month);
});

/// 预算设置页面
class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  double _warningThreshold = 0.8;
  bool _enableReminder = true;
  bool _isLoading = false;
  Budget? _currentBudget;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final now = DateTime.now();
    final service = BudgetService();
    await service.init();
    final budget = await service.getBudget(now.year, now.month);
    
    if (budget != null && mounted) {
      setState(() {
        _currentBudget = budget;
        _amountController.text = budget.totalBudget.toStringAsFixed(0);
        _warningThreshold = budget.warningThreshold;
        _enableReminder = budget.enableReminder;
      });
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final budget = Budget(
        id: _currentBudget?.id,
        userId: 1, // TODO: 从用户服务获取
        year: now.year,
        month: now.month,
        totalBudget: double.parse(_amountController.text),
        warningThreshold: _warningThreshold,
        enableReminder: _enableReminder,
      );

      final service = BudgetService();
      await service.init();
      await service.saveBudget(budget);
      // 清除缓存，确保下次获取到最新数据
      await service.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('预算设置成功'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算设置'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBudget,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 预算概览卡片
              _buildOverviewCard(),
              const SizedBox(height: 24),

              // 设置表单
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '月度预算',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 预算金额输入
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: '预算金额',
                          prefixText: '¥ ',
                          prefixStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          suffixText: '元',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入预算金额';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // 预警阈值
                      Text(
                        '预警阈值',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当消费达到此比例时发出预警',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _warningThreshold,
                              min: 0.5,
                              max: 1.0,
                              divisions: 10,
                              label: '${(_warningThreshold * 100).toInt()}%',
                              onChanged: (value) {
                                setState(() => _warningThreshold = value);
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getWarningColor(_warningThreshold).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(_warningThreshold * 100).toInt()}%',
                              style: TextStyle(
                                color: _getWarningColor(_warningThreshold),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildThresholdOption(0.5, '50%'),
                          _buildThresholdOption(0.7, '70%'),
                          _buildThresholdOption(0.8, '80%'),
                          _buildThresholdOption(0.9, '90%'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 提醒设置
                      SwitchListTile(
                        title: const Text('启用预算提醒'),
                        subtitle: const Text('消费接近预警时通知您'),
                        value: _enableReminder,
                        onChanged: (value) {
                          setState(() => _enableReminder = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 提示信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFFFF9A3C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '建议将月度预算设置为您平均月收入的50-70%，这样既能保证生活质量，又能有效控制支出。',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 历史记录入口
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('查看历史预算'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHistoryDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Consumer(
      builder: (context, ref, _) {
        final usageAsync = ref.watch(budgetUsageProvider);
        
        return usageAsync.when(
          data: (usage) => _buildUsageCard(usage),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox(),
        );
      },
    );
  }

  Widget _buildUsageCard(BudgetUsage usage) {
    final hasBudget = usage.budget != null && usage.budget!.totalBudget > 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateTime.now().month}月预算',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!hasBudget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '未设置',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (hasBudget) ...[
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usage.usageRatio.clamp(0, 1),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_getProgressColor(usage.usageRatio)),
                ),
              ),
              const SizedBox(height: 12),
              
              // 金额统计
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已花费',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        '¥${usage.totalSpent.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '预算',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        '¥${usage.budget!.totalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        usage.remaining >= 0 ? '剩余' : '超支',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        usage.remaining >= 0
                            ? '¥${usage.remaining.toStringAsFixed(0)}'
                            : '-¥${usage.remaining.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: usage.remaining >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 预警信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getWarningColor(usage.usageRatio).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getWarningIcon(usage.warningLevel),
                      color: _getWarningColor(usage.usageRatio),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getWarningMessage(usage),
                        style: TextStyle(
                          color: _getWarningColor(usage.usageRatio),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.savings_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      '设置月度预算，开始智能管理支出',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdOption(double value, String label) {
    final isSelected = (_warningThreshold - value).abs() < 0.01;
    return GestureDetector(
      onTap: () => setState(() => _warningThreshold = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog() async {
    final service = BudgetService();
    await service.init();
    final history = await service.getBudgetHistory();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('历史预算'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无历史记录'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final budget = history[index];
                    return ListTile(
                      title: Text('${budget.year}年${budget.month}月'),
                      trailing: Text(
                        '¥${budget.totalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Color _getWarningColor(double ratio) {
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= 0.8) return Colors.orange;
    if (ratio >= 0.5) return Colors.amber;
    return Colors.green;
  }

  IconData _getWarningIcon(WarningLevel level) {
    switch (level) {
      case WarningLevel.normal:
        return Icons.check_circle;
      case WarningLevel.caution:
        return Icons.info_outline;
      case WarningLevel.warning:
        return Icons.warning_amber;
      case WarningLevel.danger:
        return Icons.error_outline;
    }
  }

  Color _getProgressColor(double ratio) {
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= 0.8) return Colors.orange;
    if (ratio >= 0.5) return Colors.amber;
    return Colors.green;
  }

  String _getWarningMessage(BudgetUsage usage) {
    final level = usage.warningLevel;
    final ratio = (usage.usageRatio * 100).toInt();
    
    switch (level) {
      case WarningLevel.normal:
        return '支出正常，继续保持！';
      case WarningLevel.caution:
        return '注意：已使用$ratio%的预算';
      case WarningLevel.warning:
        return '⚠️ 预警：接近预算上限，请注意控制支出';
      case WarningLevel.danger:
        return '🚨 已超支！建议立即控制非必要消费';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
