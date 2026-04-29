import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_config.dart';
import '../../services/bill_import_service.dart';
import '../../services/auth_service.dart';

/// 账单导入页面
class BillImportPage extends ConsumerStatefulWidget {
  const BillImportPage({super.key});

  @override
  ConsumerState<BillImportPage> createState() => _BillImportPageState();
}

class _BillImportPageState extends ConsumerState<BillImportPage> {
  final BillImportService _importService = BillImportService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  BillParseResult? _parseResult;
  final Set<int> _selectedIndices = {};
  bool _selectAll = true; // 默认全选

  // 分类映射
  final Map<String, int> _categoryMapping = {
    '餐饮': 2, '交通': 3, '购物': 4, '娱乐': 5, '医疗': 6,
    '教育': 7, '居住': 8, '通讯': 9, '工资': 10, '奖金': 11,
    '投资': 12, '日用': 13, '服饰': 14, '其他': 15,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入账单'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_parseResult != null)
            TextButton.icon(
              onPressed: _importSelectedItems,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                '导入(${_selectedIndices.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 功能说明
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 支持格式',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('• 支付宝账单：导出 CSV 格式'),
                Text('• 微信支付账单：导出 Excel 格式'),
                SizedBox(height: 8),
                Text(
                  '💡 导入说明',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text('• 系统将自动识别账单类型并解析'),
                Text('• 根据交易对方自动匹配分类'),
                Text('• 可手动调整分类后再导入'),
              ],
            ),
          ),

          // 错误信息
          if (_errorMessage != null)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _errorMessage = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 加载状态
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在解析账单...'),
                  ],
                ),
              ),
            )
          // 解析结果
          else if (_parseResult != null)
            Expanded(
              child: Column(
                children: [
                  // 统计摘要
                  _buildSummaryCard(),
                  // 全选/取消全选
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectAll,
                          onChanged: (v) {
                            setState(() {
                              _selectAll = v ?? false;
                              if (_selectAll) {
                                _selectedIndices.addAll(
                                  List.generate(_parseResult!.items.length, (i) => i),
                                );
                              } else {
                                _selectedIndices.clear();
                              }
                            });
                          },
                        ),
                        const Text('全选'),
                        const Spacer(),
                        Text(
                          '已选 ${_selectedIndices.length} / ${_parseResult!.items.length} 条',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // 账单列表
                  Expanded(
                    child: ListView.builder(
                      itemCount: _parseResult!.items.length,
                      itemBuilder: (context, index) => _buildItemTile(index),
                    ),
                  ),
                ],
              ),
            )
          // 空状态 - 上传按钮
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '点击下方按钮上传账单',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 支付宝按钮
                    ElevatedButton.icon(
                      onPressed: () => _pickFile('alipay'),
                      icon: const Icon(Icons.description),
                      label: const Text('上传支付宝账单'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 微信按钮
                    ElevatedButton.icon(
                      onPressed: () => _pickFile('wechat'),
                      icon: const Icon(Icons.payment),
                      label: const Text('上传微信账单'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('稍后再说'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _parseResult!.source == '支付宝' ? Icons.description : Icons.payment,
                color: _parseResult!.source == '支付宝' ? Colors.blue : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _parseResult!.source,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '共 ${_parseResult!.items.length} 笔记录',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '支出',
                  _parseResult!.totalExpense,
                  Colors.red,
                  _parseResult!.expenseCount,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '收入',
                  _parseResult!.totalIncome,
                  Colors.green,
                  _parseResult!.incomeCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$count 笔',
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(int index) {
    final item = _parseResult!.items[index];
    final isSelected = _selectedIndices.contains(index);
    final categoryId = _getCategoryId(item.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_selectedIndices.contains(index)) {
                _selectedIndices.remove(index);
              } else {
                _selectedIndices.add(index);
              }
              _selectAll = _selectedIndices.length == _parseResult!.items.length;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 复选框
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedIndices.add(index);
                        } else {
                          _selectedIndices.remove(index);
                        }
                        _selectAll = _selectedIndices.length == _parseResult!.items.length;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // 类型标签
                Container(
                  width: 36,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: item.type == 'expense' ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.type == 'expense' ? '支' : '收',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: item.type == 'expense' ? Colors.red.shade700 : Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 金额和分类
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¥${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.counterparty ?? ''} ${item.description ?? ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 日期
                Text(
                  '${item.date.month}/${item.date.day}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(width: 8),
                // 分类标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(int index, int currentCategoryId, BillItem item) {
    final categories = _categoryMapping.entries.toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: categories.map((entry) {
        final isSelected = entry.value == currentCategoryId;
        return GestureDetector(
          onTap: () {
            // 更新分类
            setState(() {
              _parseResult!.items[index] = BillItem(
                source: item.source,
                date: item.date,
                type: item.type,
                amount: item.amount,
                category: entry.key,
                counterparty: item.counterparty,
                description: item.description,
                status: item.status,
                orderNo: item.orderNo,
              );
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              entry.key,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _getCategoryId(String category) {
    return _categoryMapping[category] ?? 15; // 默认"其他"
  }

  Future<void> _pickFile(String source) async {
    try {
      setState(() {
        _errorMessage = null;
        _parseResult = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: source == 'alipay' ? FileType.custom : FileType.custom,
        allowedExtensions: source == 'alipay' ? ['csv'] : ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() => _isLoading = true);

      if (source == 'alipay') {
        // 解析支付宝CSV
        if (file.bytes != null) {
          final result = await _importService.parseAlipayFile(file.bytes!);
          setState(() {
            _parseResult = result;
            _selectedIndices.addAll(List.generate(result.items.length, (i) => i));
          });
        } else {
          throw Exception('无法读取文件内容');
        }
      } else {
        // 解析微信Excel
        if (file.bytes != null) {
          final result = await _importService.parseWechatFile(file.bytes!);
          setState(() {
            _parseResult = result;
            _selectedIndices.addAll(List.generate(result.items.length, (i) => i));
          });
        } else {
          throw Exception('无法读取文件内容');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importSelectedItems() async {
    if (_selectedIndices.isEmpty) {
      setState(() => _errorMessage = '请至少选择一条记录');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // 获取token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.tokenKey);

      if (token == null) {
        throw Exception('请先登录');
      }

      // 准备导入的数据
      final itemsToImport = _selectedIndices
          .map((i) => _parseResult!.items[i])
          .toList();

      // 调用API导入
      final response = await _importService.importBills(itemsToImport, token);

      if (response['success'] == true || response['code'] == 200) {
        final importedCount = response['imported_count'] ?? itemsToImport.length;
        
        if (mounted) {
          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 成功导入 $importedCount 条记录'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 返回上一页（会触发首页刷新）
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['message'] ?? '导入失败');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
