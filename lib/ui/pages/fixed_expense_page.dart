import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/fixed_expense.dart';
import '../../core/models/category.dart';
import '../../services/fixed_expense_service.dart';
import '../../core/api/api_client.dart';

/// 固定费用Provider
final fixedExpensesProvider = FutureProvider.autoDispose<List<FixedExpense>>((ref) async {
  final service = FixedExpenseService();
  return service.getAllFixedExpenses();
});

/// 固定费用管理页面
class FixedExpensePage extends ConsumerStatefulWidget {
  const FixedExpensePage({super.key});

  @override
  ConsumerState<FixedExpensePage> createState() => _FixedExpensePageState();
}

class _FixedExpensePageState extends ConsumerState<FixedExpensePage> {
  final FixedExpenseService _service = FixedExpenseService();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.get('/api/categories/');
      final List data = response.data;
      final categories = data.map((e) => Category.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(fixedExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('月固定费用'),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : expensesAsync.when(
              data: (expenses) => _buildContent(expenses),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('加载失败: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(fixedExpensesProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('添加固定费用'),
      ),
    );
  }

  Widget _buildContent(List<FixedExpense> expenses) {
    final enabled = expenses.where((e) => e.isEnabled).toList();
    final disabled = expenses.where((e) => !e.isEnabled).toList();
    final monthlyTotal = enabled.fold(0.0, (sum, e) => sum + e.amount);

    return CustomScrollView(
      slivers: [
        // 统计卡片
        SliverToBoxAdapter(
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
            child: Column(
              children: [
                const Text(
                  '每月固定支出',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${monthlyTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${enabled.length} 项固定费用',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // 提示信息
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFF9A3C), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '固定费用会在每月指定日期自动添加到您的记账记录中',
                    style: TextStyle(color: Color(0xFFE65100), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // 已启用列表
        if (enabled.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  const Text(
                    '已启用',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D)),
                  ),
                  const Spacer(),
                  Text('${enabled.length} 项', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildExpenseItem(enabled[index]),
              childCount: enabled.length,
            ),
          ),
        ],

        // 已禁用列表
        if (disabled.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '已暂停',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF8E8E8E)),
                  ),
                  const Spacer(),
                  Text('${disabled.length} 项', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildExpenseItem(disabled[index]),
              childCount: disabled.length,
            ),
          ),
        ],

        // 空状态
        if (expenses.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无固定费用', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('点击右下角添加每月固定支出', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildExpenseItem(FixedExpense expense) {
    final category = _categories.firstWhere(
      (c) => c.id.toString() == expense.categoryId,
      orElse: () => Category(id: 0, name: '未分类', icon: 'other', color: '#9E9E9E', type: 'expense'),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditDialog(expense),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category.name).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getCategoryIcon(category.icon ?? 'other'), color: _getCategoryColor(category.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: expense.isEnabled ? const Color(0xFF2D2D2D) : Colors.grey,
                          decoration: expense.isEnabled ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(category.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('每月${expense.dayOfMonth}日', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${expense.amount.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: expense.isEnabled ? const Color(0xFFFF6B6B) : Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Switch(
                      value: expense.isEnabled,
                      onChanged: (value) => _toggleEnabled(expense),
                      activeColor: const Color(0xFFFF6B6B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String name) {
    final colorMap = {
      '餐饮': const Color(0xFFFF9A3C), '购物': const Color(0xFFFF6B6B), '交通': const Color(0xFF2196F3),
      '居住': const Color(0xFF9C27B0), '娱乐': const Color(0xFFE91E63), '医疗': const Color(0xFF4CAF50),
      '教育': const Color(0xFF00BCD4), '通讯': const Color(0xFF607D8B), '日用': const Color(0xFF795548),
      '服饰': const Color(0xFFFF5722), '美容': const Color(0xFFFF4081), '水果': const Color(0xFF8BC34A),
      '零食': const Color(0xFFFFEB3B), '宠物': const Color(0xFF9E9E9E), '汽车': const Color(0xFF3F51B5),
      '保险': const Color(0xFF009688), '社交': const Color(0xFF673AB7), '旅行': const Color(0xFF03A9F4),
      '其他': const Color(0xFF8E8E8E),
    };
    return colorMap[name] ?? const Color(0xFFFF6B6B);
  }

  IconData _getCategoryIcon(String iconName) {
    final iconMap = {
      'home': Icons.home_outlined, 'car': Icons.directions_car_outlined, 'shopping': Icons.shopping_bag_outlined,
      'food': Icons.restaurant_outlined, 'medical': Icons.medical_services_outlined, 'education': Icons.school_outlined,
      'insurance': Icons.security_outlined, 'phone': Icons.phone_android_outlined, 'entertainment': Icons.movie_outlined,
      'sport': Icons.fitness_center_outlined, 'beauty': Icons.spa_outlined, 'pet': Icons.pets_outlined,
      'traffic': Icons.directions_bus_outlined, 'work': Icons.work_outlined, 'gift': Icons.card_giftcard_outlined,
      'other': Icons.more_horiz,
    };
    return iconMap[iconName] ?? Icons.category_outlined;
  }

  Future<void> _toggleEnabled(FixedExpense expense) async {
    try {
      await _service.toggleEnabled(expense);
      ref.invalidate(fixedExpensesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换失败: $e')));
      }
    }
  }

  void _showAddDialog() {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分类数据加载中，请稍后再试')),
      );
      return;
    }
    _showEditDialog(null);
  }

  void _showEditDialog(FixedExpense? expense) {
    final isEdit = expense != null;
    final nameController = TextEditingController(text: expense?.name ?? '');
    final amountController = TextEditingController(text: expense?.amount.toStringAsFixed(2) ?? '');
    final noteController = TextEditingController(text: expense?.note ?? '');
    String selectedCategoryId = expense?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id.toString() : '1');
    int selectedDay = expense?.dayOfMonth ?? 1;
    bool isEnabled = expense?.isEnabled ?? true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        final maxHeight = screenHeight * 0.85;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // 顶部拖动条
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          isEdit ? '编辑固定费用' : '添加固定费用',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (isEdit)
                          IconButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: sheetContext,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('删除确认'),
                                  content: Text('确定要删除 "${expense.name}" 吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                try {
                                  await _service.deleteFixedExpense(expense.id!);
                                  ref.invalidate(fixedExpensesProvider);
                                  Navigator.pop(sheetContext);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // 表单内容
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 费用名称
                          const Text('费用名称 *', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: '如：房租、水电费、社保',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 金额
                          const Text('每月金额 *', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                            decoration: InputDecoration(
                              hintText: '0.00',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.attach_money),
                              prefixText: '¥ ',
                            ),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          // 分类选择
                          const Text('所属分类', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButton<String>(
                              value: selectedCategoryId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                  value: c.id.toString(),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(c.name).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(_getCategoryIcon(c.icon ?? 'other'), size: 18, color: _getCategoryColor(c.name)),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(c.name),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) setModalState(() => selectedCategoryId = value);
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 记账日期
                          const Text('每月记账日期', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('选择每月哪一天将此费用记入账单', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 28,
                              itemBuilder: (ctx, index) {
                                final day = index + 1;
                                final isSelected = day == selectedDay;
                                return GestureDetector(
                                  onTap: () => setModalState(() => selectedDay = day),
                                  child: Container(
                                    width: 44,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 备注
                          const Text('备注（可选）', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: '添加备注信息...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 启用开关
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('自动记账', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('开启后每月自动记入账单', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isEnabled,
                                  onChanged: (value) => setModalState(() => isEnabled = value),
                                  activeColor: const Color(0xFFFF6B6B),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // 保存按钮
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (nameController.text.isEmpty) {
                                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                                          const SnackBar(content: Text('请输入费用名称')),
                                        );
                                        return;
                                      }
                                      if (amountController.text.isEmpty) {
                                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                                          const SnackBar(content: Text('请输入金额')),
                                        );
                                        return;
                                      }
                                      setModalState(() => isSubmitting = true);
                                      final expenseData = FixedExpense(
                                        id: expense?.id,
                                        userId: 1,
                                        name: nameController.text,
                                        amount: double.tryParse(amountController.text) ?? 0,
                                        categoryId: selectedCategoryId,
                                        note: noteController.text.isEmpty ? null : noteController.text,
                                        isEnabled: isEnabled,
                                        dayOfMonth: selectedDay,
                                      );
                                      try {
                                        if (isEdit) {
                                          await _service.updateFixedExpense(expenseData);
                                        } else {
                                          await _service.addFixedExpense(expenseData);
                                        }
                                        ref.invalidate(fixedExpensesProvider);
                                        if (mounted) Navigator.pop(sheetContext);
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B6B),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFFF6B6B).withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                    )
                                  : Text(isEdit ? '保存修改' : '添加固定费用', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
