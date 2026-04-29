import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/models/category.dart';
import '../../core/models/record.dart';
import '../../services/ai_parse_service.dart';
import '../../services/volc_asr_service.dart';
import '../../services/volc_ocr_service.dart';
import '../../services/doubao_api_service.dart';
import 'home_page.dart';
import 'bill_import_page.dart';

/// 预填充数据（用于语音/拍照识别后跳转）
class AddRecordPrefill {
  final String? recognizedText;
  final double? amount;
  final String? recordType;
  final String? categoryName;
  final String? description;
  final DateTime? recordDate;

  AddRecordPrefill({
    this.recognizedText,
    this.amount,
    this.recordType,
    this.categoryName,
    this.description,
    this.recordDate,
  });
}

class AddRecordPage extends ConsumerStatefulWidget {
  final String? initialMode;
  final Record? editRecord;
  final AddRecordPrefill? prefillData;

  const AddRecordPage({super.key, this.initialMode, this.editRecord, this.prefillData});

  @override
  ConsumerState<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends ConsumerState<AddRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _asrService = VolcAsrService();
  final _ocrService = VolcOcrService();
  final _aiService = AiParseService();      // 后端AI解析（备用）
  final _doubaoService = DoubaoApiService(); // 豆包API解析（方舟ARK Key）
  final _picker = ImagePicker();
  
  late String _recordType;
  int? _categoryId;
  late DateTime _recordDate;
  bool _isLoading = false;
  String? _recognizedText;
  bool _isEditing = false;

  // 常用分类（默认置顶）
  final List<String> _commonCategories = ['餐饮', '交通', '购物', '娱乐', '日用品', '工资', '奖金'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.editRecord != null;
    
    if (_isEditing) {
      // 编辑模式：填充现有数据
      final record = widget.editRecord!;
      _amountController.text = record.amount.toString();
      _descController.text = record.description ?? '';
      _recordType = record.recordType;
      _categoryId = record.categoryId;
      try {
        _recordDate = DateTime.parse(record.recordDate);
      } catch (_) {
        _recordDate = DateTime.now();
      }
    } else {
      // 新增模式
      _recordType = 'expense';
      _recordDate = DateTime.now();
      
      // 预填充数据（语音/拍照识别）
      if (widget.prefillData != null) {
        final prefill = widget.prefillData!;
        if (prefill.amount != null && prefill.amount! > 0) {
          _amountController.text = prefill.amount!.toStringAsFixed(2);
        }
        if (prefill.recordType != null) {
          _recordType = prefill.recordType!;
        }
        // 语音识别的原始内容填入备注
        if (prefill.recognizedText != null && prefill.recognizedText!.isNotEmpty) {
          _descController.text = prefill.recognizedText!;
        } else if (prefill.description != null) {
          _descController.text = prefill.description!;
        }
        if (prefill.recognizedText != null) {
          _recognizedText = prefill.recognizedText;
        }
        if (prefill.recordDate != null) {
          _recordDate = prefill.recordDate!;
        }
        // 分类ID需要异步获取
        if (prefill.categoryName != null) {
          Future.microtask(() => _autoMatchCategory(prefill.categoryName!));
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _isLoading = true);
        
        try {
          final bytes = await image.readAsBytes();
          final base64 = base64Encode(bytes);
          
          final result = await _ocrService.recognizeFromBase64(base64);
          
          if (result.success) {
            setState(() => _recognizedText = result.combinedText);
            
            final parseResult = await _aiService.parseText(result.combinedText);
            _applyParseResult(parseResult);
            
            if (result.maxAmount != null && _amountController.text.isEmpty) {
              _amountController.text = result.maxAmount!.toStringAsFixed(2);
            }
          } else {
            throw Exception(result.error ?? '识别失败');
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('识别失败: $e')),
            );
          }
        } finally {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _startVoiceInput() async {
    try {
      setState(() => _isLoading = true);

      // ══════════════════════════════════════════════════════════════
      // 流程：麦克风录音 → 火山ASR → 豆包API智能解析（方舟ARK Key）
      // ══════════════════════════════════════════════════════════════

      // 1. 开始录音
      if (!await _asrService.startRecording()) {
        throw Exception('无法访问麦克风');
      }

      // 显示录音中提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic, color: Colors.white),
                SizedBox(width: 12),
                Text('🎙 正在录音，请说话...（3秒后自动识别）'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // 2. 录音3秒
      await Future.delayed(const Duration(seconds: 3));

      // 3. 停止录音并ASR识别
      final recognizedText = await _asrService.stopRecordingAndRecognize();

      if (recognizedText.isEmpty) {
        throw Exception('未识别到语音内容');
      }

      setState(() => _recognizedText = recognizedText);

      // 4. 豆包API智能解析（使用方舟ARK Key）
      final doubaoResult = await _doubaoService.parseAccountingText(recognizedText);

      if (doubaoResult.success) {
        // 应用豆包解析结果
        _applyDoubaoResult(doubaoResult);
      } else {
        // 豆包API失败，使用本地规则解析作为备选
        debugPrint('豆包API解析失败，使用本地规则: ${doubaoResult.error}');
        final parseResult = await _aiService.parseText(recognizedText);
        _applyParseResult(parseResult);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyParseResult(ParseResult result) {
    // 立即同步匹配分类
    int? matchedCategoryId;
    if (result.categoryName != null) {
      matchedCategoryId = _syncMatchCategory(result.categoryName!, result.recordType);
    }

    // 在 setState 中更新所有状态
    setState(() {
      if (result.amount > 0) {
        _amountController.text = result.amount.toStringAsFixed(2);
      }
      _recordType = result.recordType;
      _descController.text = result.description;

      if (result.recordDate.isNotEmpty) {
        try {
          _recordDate = DateTime.parse(result.recordDate);
        } catch (_) {}
      }

      if (result.categoryId != null && result.categoryId! > 0) {
        _categoryId = result.categoryId;
      } else if (matchedCategoryId != null) {
        _categoryId = matchedCategoryId;
      }
    });

    // 如果同步匹配失败，异步匹配
    if (result.categoryName != null && matchedCategoryId == null) {
      _autoMatchCategoryAsync(result.categoryName!);
    }
  }

  /// 应用豆包API解析结果（方舟ARK Key）
  void _applyDoubaoResult(DoubaoParseResult result) {
    // 立即同步匹配分类
    int? matchedCategoryId;
    if (result.category.isNotEmpty) {
      matchedCategoryId = _syncMatchCategory(result.category, result.recordType);
    }

    // 在 setState 中更新所有状态
    setState(() {
      if (result.amount > 0) {
        _amountController.text = result.amount.toStringAsFixed(2);
      }
      _recordType = result.recordType;
      _descController.text = result.description;

      if (matchedCategoryId != null) {
        _categoryId = matchedCategoryId;
      }
    });

    // 如果同步匹配失败，异步匹配
    if (result.category.isNotEmpty && matchedCategoryId == null) {
      _autoMatchCategoryAsync(result.category);
    }

    // 显示豆包解析结果提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 豆包AI解析：${result.amount > 0 ? "支出 ¥${result.amount}" : ""} ${result.category}${matchedCategoryId != null ? " ✓" : ""}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 同步分类匹配（基于后端分类名称）
  int? _syncMatchCategory(String categoryName, String recordType) {
    // 分类名称匹配表（按类型分类）
    final expenseCategories = ['餐饮', '外卖', '交通', '打车', '购物', '日用品', '服饰', '美容', 
      '居住', '水电费', '通讯', '娱乐', '电影', '旅游', '健身', '医疗', '教育', '书籍', 
      '咖啡', '零食', '水果', '宠物', '汽车', '保险', '红包', '其他'];
    
    final incomeCategories = ['工资', '奖金', '兼职', '投资收益', '理财收益', '退款', '红包', '其他收入'];
    
    final name = categoryName.toLowerCase();
    
    // 遍历对应类型的分类进行匹配
    final targetCategories = recordType == 'expense' ? expenseCategories : incomeCategories;
    
    for (var catName in targetCategories) {
      final catLower = catName.toLowerCase();
      // 精确匹配或包含匹配
      if (name == catLower || name.contains(catLower) || catLower.contains(name)) {
        // 返回null，让异步方法从后端获取实际ID
        return null;
      }
    }
    
    return null;
  }

  /// 异步分类匹配（从后端获取分类列表）
  void _autoMatchCategoryAsync(String categoryName) async {
    try {
      final response = await apiClient.get('/api/categories/');
      final List categories = response.data;

      for (var cat in categories) {
        final name = (cat['name'] ?? '').toString().toLowerCase();
        final targetName = categoryName.toLowerCase();

        // 模糊匹配
        if (name == targetName ||
            name.contains(targetName) ||
            targetName.contains(name) ||
            _isSimilar(name, targetName)) {
          if (mounted) {
            setState(() {
              _categoryId = cat['id'];
            });
          }
          return;
        }
      }
    } catch (_) {}
  }

  /// 判断两个字符串是否相似
  bool _isSimilar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    // 简单的相似度判断
    if (a.contains(b) || b.contains(a)) return true;
    // 首字符相同
    if (a[0] == b[0]) return true;
    return false;
  }

  /// 旧的分类匹配方法（保留兼容）
  void _autoMatchCategory(String categoryName) async {
    try {
      final response = await apiClient.get('/api/categories/');
      final List categories = response.data;

      for (var cat in categories) {
        final name = (cat['name'] ?? '').toString().toLowerCase();
        final targetName = categoryName.toLowerCase();

        if (name == targetName || name.contains(targetName) || targetName.contains(name)) {
          if (mounted) {
            setState(() {
              _categoryId = cat['id'];
            });
          }
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final date = '${_recordDate.year}-${_recordDate.month.toString().padLeft(2, '0')}-${_recordDate.day.toString().padLeft(2, '0')}';
      
      if (_isEditing) {
        // 编辑模式
        await apiClient.put('/api/records/${widget.editRecord!.id}', data: {
          'amount': double.parse(_amountController.text),
          'record_type': _recordType,
          'category_id': _categoryId,
          'record_date': date,
          'note': _descController.text,
        });
      } else {
        // 新增模式
        await apiClient.post('/api/records/', data: {
          'amount': double.parse(_amountController.text),
          'record_type': _recordType,
          'category_id': _categoryId,
          'record_date': date,
          'note': _descController.text,
        });
      }

      if (mounted) {
        // 显示成功动画
        _showSuccessAnimation();
        
        ref.invalidate(recordsProvider);
        ref.invalidate(monthlyStatsProvider);
        ref.invalidate(budgetUsageProvider); // 刷新预算
        
        // 延迟返回，让动画显示
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 显示成功动画
  void _showSuccessAnimation() {
    // 获取分类名称
    String categoryName = '未知';
    try {
      final categoriesAsync = ref.read(categoriesProvider);
      categoriesAsync.whenData((categories) {
        for (var cat in categories) {
          if (cat.id == _categoryId) {
            categoryName = cat.name;
            break;
          }
        }
      });
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SuccessAnimation(
        recordType: _recordType,
        amount: double.tryParse(_amountController.text) ?? 0,
        categoryName: categoryName,
        note: _descController.text,
        recordDate: _recordDate,
        onClose: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  /// 快速金额按钮组件
  Widget _buildQuickAmountButtons() {
    final color = _recordType == 'expense' ? Colors.red : Colors.green;
    final amounts = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('快速金额', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amounts.map((amount) {
            return InkWell(
              onTap: () {
                setState(() {
                  _amountController.text = amount.toStringAsFixed(0);
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  '¥$amount',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑' : '记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, size: 26),
            onPressed: _pickImage,
            tooltip: '拍照识别',
          ),
          IconButton(
            icon: const Icon(Icons.mic, size: 26),
            onPressed: _startVoiceInput,
            tooltip: '语音记账',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 识别结果提示
                  if (_recognizedText != null) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI识别结果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(_recognizedText!, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _recognizedText = null),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 顶部四个按钮：支出、收入、删除、保存
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: '支出',
                          icon: Icons.arrow_downward,
                          color: Colors.red,
                          isSelected: _recordType == 'expense',
                          onTap: () => setState(() {
                            _recordType = 'expense';
                            _categoryId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: '收入',
                          icon: Icons.arrow_upward,
                          color: Colors.green,
                          isSelected: _recordType == 'income',
                          onTap: () => setState(() {
                            _recordType = 'income';
                            _categoryId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isEditing)
                        Expanded(
                          child: _ActionButton(
                            label: '删除',
                            icon: Icons.delete_outline,
                            color: Colors.red,
                            isSelected: false,
                            onTap: _confirmDelete,
                          ),
                        ),
                      if (_isEditing) const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: '保存',
                          icon: Icons.check,
                          color: _recordType == 'expense' ? Colors.red : Colors.green,
                          isSelected: false,
                          isPrimary: true,
                          onTap: _isLoading ? null : _submit,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 金额输入
                  Card(
                    color: (_recordType == 'expense' ? Colors.red : Colors.green).shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '¥',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: _recordType == 'expense' ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _recordType == 'expense' ? Colors.red : Colors.green,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入金额';
                                }
                                if (double.tryParse(value) == null) {
                                  return '请输入有效金额';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 快速金额按钮
                  _buildQuickAmountButtons(),
                  
                  const SizedBox(height: 16),
                  
                  // 备注输入（在分类上方）
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '备注（选填）',
                          hintText: '添加一些备注信息...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 分类选择标题
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('选择分类', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        onPressed: () => _showDatePicker(context),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${_recordDate.month}/${_recordDate.day}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 分类选择
                  categoriesAsync.when(
                    data: (categories) {
                      // 分离系统分类和自定义分类
                      final systemCategories = categories.where((c) => c.type == _recordType && c.isSystem == true).toList();
                      final customCategories = categories.where((c) => c.type == _recordType && c.isSystem != true).toList();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 系统分类 - 网格布局
                          if (systemCategories.isNotEmpty) ...[
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.0,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: systemCategories.length,
                              itemBuilder: (context, index) {
                                final cat = systemCategories[index];
                                return _CategoryGridItem(
                                  category: cat,
                                  isSelected: _categoryId == cat.id,
                                  onTap: () => setState(() => _categoryId = cat.id),
                                );
                              },
                            ),
                          ],
                          // 自定义分类
                          if (customCategories.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('自定义分类', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.0,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: customCategories.length,
                              itemBuilder: (context, index) {
                                final cat = customCategories[index];
                                return _CategoryGridItem(
                                  category: cat,
                                  isSelected: _categoryId == cat.id,
                                  onTap: () => setState(() => _categoryId = cat.id),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('加载分类失败'),
                  ),
                  
                  const SizedBox(height: 100), // 底部留白
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
  
  /// 日期选择
  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _recordDate = date);
    }
  }
  
  /// 确认删除
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRecord();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  /// 删除记录
  Future<void> _deleteRecord() async {
    if (widget.editRecord == null) return;
    
    setState(() => _isLoading = true);
    try {
      await apiClient.delete('/api/records/${widget.editRecord!.id}');
      
      if (mounted) {
        ref.invalidate(recordsProvider);
        ref.invalidate(monthlyStatsProvider);
        ref.invalidate(budgetUsageProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary 
        ? color 
        : (isSelected ? color : Colors.grey.shade200);
    final textColor = isSelected || isPrimary ? Colors.white : Colors.black87;
    
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.type == 'expense' ? Colors.red : Colors.green;
    
    return Material(
      color: isSelected ? color : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Category.getIcon(category.name),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 网格布局分类项组件
class _CategoryGridItem extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.type == 'expense' ? Colors.red : Colors.green;
    
    return Material(
      color: isSelected ? color : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Category.getIcon(category.name),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 成功动画组件
class _SuccessAnimation extends StatefulWidget {
  final String recordType;
  final double amount;
  final String categoryName;
  final String? note;
  final DateTime recordDate;
  final VoidCallback? onShare;
  final VoidCallback? onClose;

  const _SuccessAnimation({
    required this.recordType,
    required this.amount,
    required this.categoryName,
    this.note,
    required this.recordDate,
    this.onShare,
    this.onClose,
  });

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 生成分享卡片组件
  Widget _buildShareCard() {
    final isExpense = widget.recordType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final emoji = isExpense ? '💸' : '💰';
    final typeText = isExpense ? '支出' : '收入';
    final tips = [
      '今天也要好好吃饭哦~',
      '存钱是一种快乐~',
      '每一笔都是生活的小确幸',
      '记账让生活更美好~',
      '小钱积少成多~',
    ];
    final tip = tips[DateTime.now().second % tips.length];

    return RepaintBoundary(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isExpense 
                ? [const Color(0xFFFF8C8C), const Color(0xFFFF6B6B)]
                : [const Color(0xFF56C596), const Color(0xFF4CAF50)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$emoji 金算盘记账',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(widget.recordDate),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 金额
            Text(
              '$typeText',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 分类
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '📂 ${widget.categoryName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            if (widget.note != null && widget.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.note!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            // 小贴士
            Text(
              tip,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '分享记账卡片',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 卡片预览
            _buildShareCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onClose?.call();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('关闭'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '记账成功!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '已为您保存记录',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              // 分享按钮
              ElevatedButton.icon(
                onPressed: _showShareDialog,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('分享记账卡片'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('继续记账'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}