import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/record.dart';
import '../../core/models/category.dart';
import 'home_page.dart';
import 'add_record_page.dart';

/// 筛选状态
final recordFilterProvider = StateProvider<RecordFilter>((ref) => RecordFilter());

class RecordFilter {
  final String? searchText;
  final String? recordType; // 'expense', 'income', null表示全部
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;

  RecordFilter({
    this.searchText,
    this.recordType,
    this.categoryId,
    this.startDate,
    this.endDate,
  });

  RecordFilter copyWith({
    String? searchText,
    String? recordType,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool clearSearch = false,
    bool clearType = false,
    bool clearCategory = false,
    bool clearDate = false,
  }) {
    return RecordFilter(
      searchText: clearSearch ? null : (searchText ?? this.searchText),
      recordType: clearType ? null : (recordType ?? this.recordType),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startDate: clearDate ? null : (startDate ?? this.startDate),
      endDate: clearDate ? null : (endDate ?? this.endDate),
    );
  }
}

/// 筛选后的记录Provider
final filteredRecordsProvider = FutureProvider.autoDispose<List<Record>>((ref) async {
  final allRecords = await ref.watch(recordsProvider.future);
  final filter = ref.watch(recordFilterProvider);

  return allRecords.where((record) {
    // 搜索文本筛选
    if (filter.searchText != null && filter.searchText!.isNotEmpty) {
      final searchLower = filter.searchText!.toLowerCase();
      final matchCategory = record.categoryName?.toLowerCase().contains(searchLower) ?? false;
      final matchDesc = record.description?.toLowerCase().contains(searchLower) ?? false;
      final matchAmount = record.amount.toString().contains(searchLower);
      if (!matchCategory && !matchDesc && !matchAmount) return false;
    }

    // 类型筛选
    if (filter.recordType != null && record.recordType != filter.recordType) {
      return false;
    }

    // 分类筛选
    if (filter.categoryId != null && record.categoryId.toString() != filter.categoryId) {
      return false;
    }

    // 日期筛选 - 只比较年月日
    if (filter.startDate != null) {
      final recordDate = DateTime.parse(record.recordDate);
      final startDateOnly = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
      final recordDateOnly = DateTime(recordDate.year, recordDate.month, recordDate.day);
      if (recordDateOnly.isBefore(startDateOnly)) return false;
    }
    if (filter.endDate != null) {
      final recordDate = DateTime.parse(record.recordDate);
      final endDateOnly = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day);
      final recordDateOnly = DateTime(recordDate.year, recordDate.month, recordDate.day);
      if (recordDateOnly.isAfter(endDateOnly)) return false;
    }

    return true;
  }).toList();
});

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(filteredRecordsProvider);
    final filter = ref.watch(recordFilterProvider);
    final hasFilter = filter.searchText != null || filter.recordType != null || filter.categoryId != null;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索记录...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  ref.read(recordFilterProvider.notifier).state = filter.copyWith(searchText: value);
                },
              )
            : const Text('记账记录'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(recordFilterProvider.notifier).state = filter.copyWith(clearSearch: true);
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(recordsProvider);
              ref.invalidate(filteredRecordsProvider);
            },
          ),
        ],
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState(hasFilter);
          }
          
          // 按日期分组
          final grouped = <String, List<Record>>{};
          for (var record in records) {
            grouped.putIfAbsent(record.recordDate, () => []).add(record);
          }
          
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
          
          return ListView.builder(
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayRecords = grouped[date]!;
              final dayIncome = dayRecords.where((r) => r.recordType == 'income').fold<double>(0, (sum, r) => sum + r.amount);
              final dayExpense = dayRecords.where((r) => r.recordType == 'expense').fold<double>(0, (sum, r) => sum + r.amount);
              final dayBalance = dayIncome - dayExpense;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期标题
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    color: Colors.grey.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDate(date),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getWeekday(date),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (dayIncome > 0) ...[
                              Text('收 ${dayIncome.toStringAsFixed(0)}', style: TextStyle(color: Colors.green.shade600, fontSize: 12)),
                              const SizedBox(width: 8),
                            ],
                            if (dayExpense > 0)
                              Text('支 ${dayExpense.toStringAsFixed(0)}', style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 记录列表
                  ...dayRecords.map((record) => _RecordCard(
                    record: record,
                    onEdit: () => _editRecord(context, record),
                    onDelete: () => _deleteRecord(context, record),
                  )),
                  
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(filteredRecordsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hasFilter ? Icons.filter_alt_off : Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(hasFilter ? '没有符合条件的记录' : '暂无记录', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          if (hasFilter) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.read(recordFilterProvider.notifier).state = RecordFilter();
                _searchController.clear();
              },
              child: const Text('清除筛选'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text('点击底部按钮开始记账', style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final parts = date.split('-');
    if (parts.length == 3) {
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return '${month}月${day}日';
    }
    return date;
  }

  String _getWeekday(String date) {
    try {
      final parts = date.split('-');
      final dateTime = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[dateTime.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  void _showFilterSheet(BuildContext context) {
    final filter = ref.read(recordFilterProvider);
    final categoriesAsync = ref.read(categoriesProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => _FilterSheetContent(
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _editRecord(BuildContext context, Record record) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddRecordPage(editRecord: record),
    ));
  }

  void _deleteRecord(BuildContext context, Record record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除这条 ${record.categoryName ?? '记录'} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await apiClient.delete('/api/records/${record.id}');
                ref.invalidate(recordsProvider);
                ref.invalidate(filteredRecordsProvider);
                ref.invalidate(monthlyStatsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _FilterSheetContent extends ConsumerWidget {
  final ScrollController scrollController;

  const _FilterSheetContent({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(recordFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖动条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('筛选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ref.read(recordFilterProvider.notifier).state = RecordFilter();
                  Navigator.pop(context);
                },
                child: const Text('清除全部'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 可滚动内容
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型筛选
                  const Text('类型', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: filter.recordType == null,
                        onSelected: (_) => ref.read(recordFilterProvider.notifier).state = filter.copyWith(clearType: true),
                      ),
                      ChoiceChip(
                        label: const Text('支出'),
                        selected: filter.recordType == 'expense',
                        onSelected: (_) => ref.read(recordFilterProvider.notifier).state = filter.copyWith(recordType: 'expense'),
                      ),
                      ChoiceChip(
                        label: const Text('收入'),
                        selected: filter.recordType == 'income',
                        onSelected: (_) => ref.read(recordFilterProvider.notifier).state = filter.copyWith(recordType: 'income'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 日期区间筛选
                  const Text('日期区间', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerButton(
                          label: '开始日期',
                          date: filter.startDate,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: filter.startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              ref.read(recordFilterProvider.notifier).state =
                                  filter.copyWith(startDate: date);
                            }
                          },
                          onClear: filter.startDate != null
                              ? () => ref.read(recordFilterProvider.notifier).state =
                                  filter.copyWith(startDate: null, clearDate: filter.endDate == null)
                              : null,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('至', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(
                        child: _DatePickerButton(
                          label: '结束日期',
                          date: filter.endDate,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: filter.endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              ref.read(recordFilterProvider.notifier).state =
                                  filter.copyWith(endDate: date);
                            }
                          },
                          onClear: filter.endDate != null
                              ? () => ref.read(recordFilterProvider.notifier).state =
                                  filter.copyWith(endDate: null, clearDate: filter.startDate == null)
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 快捷日期选项
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('今天'),
                        onPressed: () {
                          final today = DateTime.now();
                          ref.read(recordFilterProvider.notifier).state =
                              filter.copyWith(startDate: today, endDate: today);
                        },
                      ),
                      ActionChip(
                        label: const Text('本周'),
                        onPressed: () {
                          final now = DateTime.now();
                          final weekStart = now.subtract(Duration(days: now.weekday - 1));
                          ref.read(recordFilterProvider.notifier).state =
                              filter.copyWith(startDate: weekStart, endDate: now);
                        },
                      ),
                      ActionChip(
                        label: const Text('本月'),
                        onPressed: () {
                          final now = DateTime.now();
                          final monthStart = DateTime(now.year, now.month, 1);
                          ref.read(recordFilterProvider.notifier).state =
                              filter.copyWith(startDate: monthStart, endDate: now);
                        },
                      ),
                      ActionChip(
                        label: const Text('上月'),
                        onPressed: () {
                          final now = DateTime.now();
                          final lastMonthStart = DateTime(now.year, now.month - 1, 1);
                          final lastMonthEnd = DateTime(now.year, now.month, 0);
                          ref.read(recordFilterProvider.notifier).state =
                              filter.copyWith(startDate: lastMonthStart, endDate: lastMonthEnd);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 分类筛选
                  const Text('分类', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: filter.categoryId == null,
                          onSelected: (_) => ref.read(recordFilterProvider.notifier).state = filter.copyWith(clearCategory: true),
                        ),
                        ...categories.map((cat) => ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(Category.getIcon(cat.name)),
                              const SizedBox(width: 4),
                              Text(cat.name),
                            ],
                          ),
                          selected: filter.categoryId == cat.id.toString(),
                          onSelected: (_) => ref.read(recordFilterProvider.notifier).state = filter.copyWith(categoryId: cat.id.toString()),
                        )),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('加载失败'),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 底部按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('应用筛选'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  final Record record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = record.recordType == 'expense';
    final categoriesAsync = ref.watch(categoriesProvider);
    
    return Dismissible(
      key: Key('record_${record.id}'),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
            child: Text(
              categoriesAsync.whenOrNull(
                data: (cats) {
                  final cat = cats.where((c) => c.id == record.categoryId).firstOrNull;
                  return cat != null ? Category.getIcon(cat.name) : '📦';
                },
              ) ?? '📦',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(record.categoryName ?? '未知分类', style: const TextStyle(fontWeight: FontWeight.w500))),
              Text(
                '${isExpense ? '-' : '+'}¥${record.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          subtitle: record.description != null && record.description!.isNotEmpty
              ? Text(record.description!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onEdit,
        ),
      ),
    );
  }
}

/// 日期选择按钮组件
class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: date != null ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null 
                    ? '${date!.month}/${date!.day}' 
                    : label,
                style: TextStyle(
                  color: date != null ? Colors.black87 : Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}