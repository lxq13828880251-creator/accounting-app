import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api/api_client.dart';

/// 统计视图模式
enum StatsViewMode { year, month }

/// 日期选择状态
final statsViewModeProvider = StateProvider<StatsViewMode>((ref) => StatsViewMode.month);
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);
final selectedMonthProvider = StateProvider<int>((ref) => DateTime.now().month);

/// 年度统计Provider
final yearlyStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, year) async {
  final response = await apiClient.get('/api/stats/yearly', params: {'year': year});
  return response.data;
});

/// 月度统计Provider
final monthlyStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, params) async {
  final response = await apiClient.get('/api/stats/monthly', params: {
    'year': params.year,
    'month': params.month,
  });
  return response.data;
});

/// 当前视图统计Provider
final currentStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final viewMode = ref.watch(statsViewModeProvider);
  
  if (viewMode == StatsViewMode.year) {
    final year = ref.watch(selectedYearProvider);
    return ref.watch(yearlyStatsProvider(year).future);
  } else {
    final year = ref.watch(selectedYearProvider);
    final month = ref.watch(selectedMonthProvider);
    return ref.watch(monthlyStatsProvider((year: year, month: month)).future);
  }
});

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(statsViewModeProvider);
    final statsAsync = ref.watch(currentStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('统计', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black87),
            onPressed: () => _showDateSelector(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // 视图切换标签
          _buildViewModeTabs(context, ref, viewMode),
          // 统计内容
          Expanded(
            child: statsAsync.when(
              data: (stats) => _StatsContent(stats: stats, viewMode: viewMode),
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50))),
              error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(currentStatsProvider)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTabs(BuildContext context, WidgetRef ref, StatsViewMode viewMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _buildTab(context, ref, '年度', StatsViewMode.year, viewMode),
          _buildTab(context, ref, '月度', StatsViewMode.month, viewMode),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, WidgetRef ref, String label, StatsViewMode mode, StatsViewMode current) {
    final isSelected = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(statsViewModeProvider.notifier).state = mode,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF7F50) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDateSelector(BuildContext context, WidgetRef ref) async {
    final viewMode = ref.read(statsViewModeProvider);
    
    if (viewMode == StatsViewMode.year) {
      final year = ref.read(selectedYearProvider);
      final result = await showDialog<int>(
        context: context,
        builder: (context) => _YearPickerDialog(initialYear: year),
      );
      if (result != null) {
        ref.read(selectedYearProvider.notifier).state = result;
        ref.invalidate(currentStatsProvider);
      }
    } else {
      final year = ref.read(selectedYearProvider);
      final month = ref.read(selectedMonthProvider);
      final result = await showDatePicker(
        context: context,
        initialDate: DateTime(year, month),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
      );
      if (result != null) {
        ref.read(selectedYearProvider.notifier).state = result.year;
        ref.read(selectedMonthProvider.notifier).state = result.month;
        ref.invalidate(currentStatsProvider);
      }
    }
  }
}

class _YearPickerDialog extends StatefulWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择年份'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.2),
          itemCount: DateTime.now().year - 2019,
          itemBuilder: (context, index) {
            final year = 2020 + index;
            final isSelected = year == _selectedYear;
            return GestureDetector(
              onTap: () => setState(() => _selectedYear = year),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF7F50) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$year', style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedYear),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50)),
          child: const Text('确定', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50)),
            child: const Text('重试', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  final StatsViewMode viewMode;

  const _StatsContent({required this.stats, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    // 年度视图和月度视图数据结构不同
    if (viewMode == StatsViewMode.year) {
      return _buildYearlyView(context);
    } else {
      return _buildMonthlyView(context);
    }
  }

  Widget _buildYearlyView(BuildContext context) {
    final months = stats['months'] as List? ?? [];
    if (months.isEmpty) return _buildEmptyCard('暂无年度数据');

    final totalIncome = months.fold<double>(0, (sum, m) => sum + (m['income'] ?? 0).toDouble());
    final totalExpense = months.fold<double>(0, (sum, m) => sum + (m['expense'] ?? 0).toDouble());
    final balance = totalIncome - totalExpense;

    return RefreshIndicator(
      onRefresh: () async {},
      color: const Color(0xFFFF7F50),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年度概览卡片
            _buildYearOverviewCard(context, stats['year'] ?? DateTime.now().year, totalIncome, totalExpense, balance),
            const SizedBox(height: 20),
            
            // 月度柱状图
            _buildSectionTitle(context, '月度收支对比'),
            const SizedBox(height: 12),
            _buildMonthlyComparisonChart(context, months),
            const SizedBox(height: 20),
            
            // 每月明细
            _buildSectionTitle(context, '每月明细'),
            const SizedBox(height: 12),
            _buildMonthlyDetails(context, months),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyView(BuildContext context) {
    final income = (stats['total_income'] ?? 0).toDouble();
    final expense = (stats['total_expense'] ?? 0).toDouble();
    final balance = income - expense;
    final categoryStats = stats['category_stats'] as List? ?? [];
    
    final expenseCategories = categoryStats.where((s) => s['type'] == 'expense').toList()
      ..sort((a, b) => ((b['total'] ?? 0) as num).compareTo((a['total'] ?? 0) as num));
    final incomeCategories = categoryStats.where((s) => s['type'] == 'income').toList()
      ..sort((a, b) => ((b['total'] ?? 0) as num).compareTo((a['total'] ?? 0) as num));

    return RefreshIndicator(
      onRefresh: () async {},
      color: const Color(0xFFFF7F50),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 概览卡片
            _buildOverviewCard(context, income, expense, balance),
            const SizedBox(height: 20),
            
            // Tab切换：支出/收入占比
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const TabBar(
                      labelColor: Color(0xFFFF7F50),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFFFF7F50),
                      indicatorWeight: 3,
                      tabs: [Tab(text: '支出占比'), Tab(text: '收入占比')],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        expenseCategories.isNotEmpty
                            ? _buildCategoryPieChart(context, expenseCategories, Colors.red)
                            : _buildEmptyCard('暂无支出数据'),
                        incomeCategories.isNotEmpty
                            ? _buildCategoryPieChart(context, incomeCategories, Colors.green)
                            : _buildEmptyCard('暂无收入数据'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 分类明细列表
            if (expenseCategories.isNotEmpty) ...[
              _buildSectionTitle(context, '支出分类明细'),
              const SizedBox(height: 12),
              _buildCategoryList(context, expenseCategories, Colors.red),
              const SizedBox(height: 20),
            ],
            
            if (incomeCategories.isNotEmpty) ...[
              _buildSectionTitle(context, '收入分类明细'),
              const SizedBox(height: 12),
              _buildCategoryList(context, incomeCategories, Colors.green),
              const SizedBox(height: 20),
            ],
            
            // 趋势图
            if (stats['daily_stats'] != null) ...[
              _buildSectionTitle(context, '每日支出趋势'),
              const SizedBox(height: 12),
              _buildTrendChart(context, stats['daily_stats'] as List),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearOverviewCard(BuildContext context, int year, double income, double expense, double balance) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7F50), Color(0xFFFF6347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFFF7F50).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$year年', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(balance >= 0 ? '结余' : '超支', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${balance.abs().toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildOverviewItem('年收入', income, Icons.arrow_upward)),
              const SizedBox(width: 16),
              Expanded(child: _buildOverviewItem('年支出', expense, Icons.arrow_downward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, double income, double expense, double balance) {
    final total = income + expense;
    final year = stats['year'] ?? DateTime.now().year;
    final month = stats['month'] ?? DateTime.now().month;
    
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7F50), Color(0xFFFF6347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFFF7F50).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$year年$month月', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(balance >= 0 ? '结余' : '超支', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${balance.abs().toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildOverviewItem('收入', income, Icons.arrow_upward)),
              const SizedBox(width: 16),
              Expanded(child: _buildOverviewItem('支出', expense, Icons.arrow_downward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('¥${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFFF7F50), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildMonthlyComparisonChart(BuildContext context, List months) {
    if (months.isEmpty) return _buildEmptyCard('暂无数据');

    final maxValue = months.fold<double>(0, (max, m) {
      final income = (m['income'] ?? 0).toDouble();
      final expense = (m['expense'] ?? 0).toDouble();
      return [max, income, expense].reduce((a, b) => a > b ? a : b);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('收入', Colors.green),
              const SizedBox(width: 24),
              _buildLegend('支出', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = group.x + 1;
                      return BarTooltipItem(
                        '${month}月\n¥${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${(value.toInt() + 1)}月', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxValue > 0 ? maxValue / 4 : 100),
                barGroups: months.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(toY: (entry.value['income'] ?? 0).toDouble(), color: Colors.green.withOpacity(0.7), width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      BarChartRodData(toY: (entry.value['expense'] ?? 0).toDouble(), color: Colors.red.withOpacity(0.7), width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildMonthlyDetails(BuildContext context, List months) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: months.asMap().entries.map((entry) {
          final m = entry.value;
          final income = (m['income'] ?? 0).toDouble();
          final expense = (m['expense'] ?? 0).toDouble();
          final balance = income - expense;
          final isLast = entry.key == months.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFFF7F50).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${m['month']}', style: const TextStyle(color: Color(0xFFFF7F50), fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['month']}月', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('收 ¥${income.toStringAsFixed(0)}', style: TextStyle(color: Colors.green.shade600, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('支 ¥${expense.toStringAsFixed(0)}', style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${balance >= 0 ? '+' : ''}¥${balance.toStringAsFixed(0)}',
                  style: TextStyle(color: balance >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryPieChart(BuildContext context, List categories, Color baseColor) {
    final total = categories.fold<double>(0, (sum, s) => sum + (s['total'] ?? 0).toDouble());
    if (total == 0) return _buildEmptyCard('暂无数据');

    final colors = baseColor == Colors.red
        ? [Colors.red, Colors.orange, Colors.amber, Colors.pink, Colors.purple, Colors.blue]
        : [Colors.green, Colors.teal, Colors.lightGreen, Colors.cyan, Colors.lime, Colors.greenAccent];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 45,
                      sections: categories.take(6).toList().asMap().entries.map((entry) {
                        final value = (entry.value['total'] ?? 0).toDouble();
                        return PieChartSectionData(
                          value: value,
                          title: value / total > 0.05 ? '${(value / total * 100).toStringAsFixed(1)}%' : '',
                          color: colors[entry.key % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.take(6).toList().asMap().entries.map((entry) {
                      final s = entry.value;
                      final value = (s['total'] ?? 0).toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[entry.key % colors.length], borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s['category_name'] ?? '未知', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                            Text('¥${value.toStringAsFixed(0)}', style: TextStyle(color: baseColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...categories.map((s) {
            final value = (s['total'] ?? 0).toDouble();
            final percent = total > 0 ? value / total : 0.0;
            final colorIndex = categories.indexOf(s) % colors.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[colorIndex], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s['category_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      Text('¥${value.toStringAsFixed(2)}', style: TextStyle(color: baseColor, fontWeight: FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percent,
                    backgroundColor: baseColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(colors[colorIndex]),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, List categories, Color color) {
    final total = categories.fold<double>(0, (sum, s) => sum + (s['total'] ?? 0).toDouble());
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: categories.asMap().entries.map((entry) {
          final s = entry.value;
          final value = (s['total'] ?? 0).toDouble();
          final percent = total > 0 ? value / total : 0.0;
          final isLast = entry.key == categories.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${entry.key + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['category_name'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('¥${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${s['count'] ?? 0}笔', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendChart(BuildContext context, List dailyStats) {
    if (dailyStats.isEmpty) return _buildEmptyCard('暂无趋势数据');

    final expenseSpots = <FlSpot>[];
    double maxY = 0;

    for (var i = 0; i < dailyStats.length; i++) {
      final day = dailyStats[i];
      final expense = (day['expense'] ?? 0).toDouble();
      expenseSpots.add(FlSpot(i.toDouble(), expense));
      if (expense > maxY) maxY = expense;
    }

    if (maxY == 0) return _buildEmptyCard('暂无支出');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('每日支出', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                children: [
                  Container(width: 12, height: 3, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text('支出', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x + 1;
                      return BarTooltipItem('${day}日\n¥${rod.toY.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontSize: 12));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        if ([1, 7, 14, 21, 28].contains(day) || day == dailyStats.length) {
                          return Padding(padding: const EdgeInsets.only(top: 8), child: Text('${day}日', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 4 : 100),
                barGroups: expenseSpots.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.y,
                        color: Colors.red.withOpacity(0.7),
                        width: dailyStats.length > 15 ? 8 : 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
