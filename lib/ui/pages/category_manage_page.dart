import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/category.dart';

/// 分类Provider
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final response = await apiClient.get('/api/categories/');
  final List data = response.data;
  return data.map((e) => Category.fromJson(e)).toList();
});

/// 分类管理页面
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _resetSystemCategories(context),
            tooltip: '重置系统分类',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(context),
            tooltip: '添加分类',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出分类'),
            Tab(text: '收入分类'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryList(type: 'expense', onEdit: _showEditCategoryDialog),
          _CategoryList(type: 'income', onEdit: _showEditCategoryDialog),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    _showCategoryDialog(context, null);
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    _showCategoryDialog(context, category);
  }

  /// 重置系统分类
  Future<void> _resetSystemCategories(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置系统分类'),
        content: const Text('这将删除所有自定义分类，恢复系统默认分类。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await apiClient.post('/api/categories/reset');
      ref.invalidate(categoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('系统分类已重置'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCategoryDialog(BuildContext context, Category? category) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final type = category?.type ?? 'expense';
    
    // 如果是编辑，继承原类型；如果是新增，根据当前Tab确定类型
    String selectedType = type;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑分类' : '添加分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEdit) ...[
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('支出')),
                    ButtonSegment(value: 'income', label: Text('收入')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (value) {
                    setDialogState(() => selectedType = value.first);
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                  hintText: '例如：餐饮、工资',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((icon) {
                  return InkWell(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入分类名称')),
                  );
                  return;
                }
                
                try {
                  if (isEdit) {
                    await apiClient.put('/api/categories/${category!.id}', data: {
                      'name': name,
                    });
                  } else {
                    await apiClient.post('/api/categories/', data: {
                      'name': name,
                      'type': selectedType,
                      'is_system': false,
                    });
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(categoriesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? '修改成功' : '添加成功'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  static const _availableIcons = [
    '🍜', '🥡', '🍱', '☕', '🧋', '🍪', '🍎', '🎂', '🍺', '🍲',
    '🚗', '🚕', '🚌', '🚇', '✈️', '⛽', '🚙', '🔧',
    '🛒', '📦', '🛍️', '🧴', '👔', '👟', '👜', '💄',
    '🏠', '🏢', '💡', '🏗️', '🔥', '📶',
    '📱', '📞',
    '🎮', '🎬', '🎯', '🌍', '🏋️', '⚽', '🎵', '🎤',
    '🏥', '💊', '🩺',
    '📚', '🎓', '📖', '✏️',
    '🐱', '🐶', '🛡️',
    '💰', '🎁', '💼', '📈', '💹', '↩️', '🧧', '💵',
    '🎯', '📌',
  ];
}

class _CategoryList extends ConsumerWidget {
  final String type;
  final Function(BuildContext, Category) onEdit;

  const _CategoryList({required this.type, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final filtered = categories.where((c) => c.type == type).toList();
        
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '暂无${type == 'expense' ? '支出' : '收入'}分类',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('添加分类'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final category = filtered[index];
            return Card(
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category.name).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      Category.getIcon(category.name),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(
                  category.isSystem == true ? '系统分类' : '自定义',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(context, category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, category),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $error'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(categoriesProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分类'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '输入分类名称',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              
              try {
                await apiClient.post('/api/categories/', data: {
                  'name': name,
                  'type': type,
                  'is_system': false,
                });
                ref.invalidate(categoriesProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类 "${category.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await apiClient.delete('/api/categories/${category.id}');
                ref.invalidate(categoriesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String name) {
    final colors = {
      '餐饮': Colors.orange, '外卖': Colors.deepOrange, '交通': Colors.teal,
      '购物': Colors.pink, '居住': Colors.blue, '娱乐': Colors.purple,
      '医疗': Colors.red, '教育': Colors.indigo, '通讯': Colors.cyan,
      '工资': Colors.green, '奖金': Colors.lightGreen, '其他': Colors.grey,
    };
    return colors[name] ?? Colors.blueGrey;
  }
}
