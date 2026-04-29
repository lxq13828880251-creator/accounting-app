import '../core/api/api_client.dart';
import '../core/models/record.dart';

/// AI智能解析服务
class AiParseService {
  final ApiClient _apiClient = apiClient;
  
  /// 解析自然语言文本
  Future<ParseResult> parseText(String text) async {
    try {
      final response = await _apiClient.post(
        '/api/ai/parse',
        data: {'text': text},
      );
      
      final data = response.data;
      
      return ParseResult(
        success: true,
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        recordType: data['record_type'] ?? 'expense',
        categoryId: data['category_id'],
        categoryName: data['category_name'],
        recordDate: data['record_date'] ?? _getTodayDate(),
        description: data['description'] ?? text,
      );
    } catch (e) {
      // 如果API解析失败，使用本地规则解析
      return _parseLocally(text);
    }
  }
  
  /// 使用本地规则解析
  ParseResult _parseLocally(String text) {
    double amount = 0;
    String recordType = 'expense';
    String? categoryName;
    
    // 提取金额 - 支持多种格式
    final amountPatterns = [
      RegExp(r'([Y$]?\s*[\d,]+\.?\d{0,2})'),
      RegExp(r'(\d+\.?\d{0,2})\s*(?:yuan|kuai|kuai|qian)'),
      RegExp(r'hua\s*liao?\s*(\d+\.?\d{0,2})', caseSensitive: false),
      RegExp(r'(\d+\.?\d{0,2})'),
    ];
    
    for (var pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        String numStr = match.group(1) ?? '0';
        numStr = numStr.replaceAll(RegExp(r'[Y$,\s]'), '');
        amount = double.tryParse(numStr) ?? 0;
        if (amount > 0) break;
      }
    }
    
    // 判断收入/支出
    if (text.contains('income') || text.contains('salary') || text.contains('wage') || 
        text.contains('bonus') || text.contains('revenue') ||
        text.contains('收入') || text.contains('到账') || text.contains('工资') || 
        text.contains('奖金') || text.contains('转账') || text.contains('收款')) {
      recordType = 'income';
    }
    
    // 匹配分类 - 扩展关键词库（英文关键词 + 中文）
    final categoryKeywords = {
      '餐饮': ['food', 'meal', 'lunch', 'dinner', 'breakfast', 'takeout', 'restaurant', 'cafe', 
               'coffee', 'snack', 'drink', 'supermarket', 'grocery',
               '吃饭', '午餐', '晚餐', '早餐', '夜宵', '外卖', '餐厅', '食堂', 
               '奶茶', '咖啡', '饮料', '零食', '水果', '买菜', '超市'],
      '交通': ['taxi', 'subway', 'metro', 'bus', 'parking', 'gas', 'fuel', 'uber', 'didi',
               'train', 'flight', 'highway', 'toll',
               '打车', '地铁', '公交', '班车', '停车', '油费', '加油', 
               '打车费', '滴滴', '过路', '高速', '火车', '高铁', '飞机'],
      '购物': ['shopping', 'buy', 'clothes', 'shoes', 'bag', 'cosmetics', 'skincare',
               'taobao', 'jd', 'tmall', 'pinduoduo',
               '买', '购物', '网购', '淘宝', '京东', '天猫', '拼多多', 
               '衣服', '鞋子', '包', '化妆品', '护肤', '日用品', '生活用品'],
      '娱乐': ['movie', 'film', 'game', 'ktv', 'sing', 'travel', 'gym', 'fitness', 'sport',
               'movie', 'game', '按摩', '洗脚', '理发', '美发',
               '电影', '游戏', 'KTV', '唱歌', '旅游', '电影票', '门票', 
               '健身', '运动', '跑步', '游泳', '羽毛球', '篮球', '足球'],
      '医疗': ['hospital', 'medicine', 'doctor', 'medical', 'pharmacy', 'clinic', 'checkup',
               '医院', '买药', '看病', '医疗', '药店', '诊所', '挂号', 
               '检查', '化验', '手术', '牙医', '体检'],
      '教育': ['tuition', 'training', 'book', 'education', 'course', 'exam', 'study',
               '学费', '培训', '买书', '教育', '学习', '课程', 
               '报名', '考试', '补习', '家教', '文具', '教材'],
      '居住': ['rent', 'electric', 'water', 'property', 'housing', 'gas', 'internet', 'tv',
               '房租', '水电', '物业', '住房', '房租费', '租金', 
               '燃气', '宽带', '网费', '电视', '家具', '装修'],
      '通讯': ['phone', 'mobile', 'call', 'data', 'internet', 'bill',
               '话费', '流量', '宽带', '通讯', '手机', '电话费', '月租', '套餐'],
      '工资': ['salary', 'wage', 'income', 'pay', 'payroll', 'base', 'commission',
               '工资', '薪资', '收入', '到账', '底薪', '提成'],
      '奖金': ['bonus', 'reward', 'prize', 'hongbao', 'gift',
               '奖金', '红包', '奖励', '年终奖', '过节费', '补贴'],
      '理财': ['investment', 'fund', 'stock', 'dividend', 'interest', 'financial',
               '理财', '基金', '股票', '投资收益', '利息', '分红'],
      '转账': ['transfer', 'remit', 'payment received',
               '转账', '收款', '收款到账'],
    };
    
    for (var entry in categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (text.toLowerCase().contains(keyword.toLowerCase())) {
          categoryName = entry.key;
          break;
        }
      }
      if (categoryName != null) break;
    }
    
    // 根据类型设置默认分类
    if (categoryName == null) {
      if (recordType == 'income') {
        categoryName = '工资';
      } else {
        categoryName = '其他';
      }
    }
    
    return ParseResult(
      success: true,
      amount: amount,
      recordType: recordType,
      categoryId: 0, // 需要后续匹配
      categoryName: categoryName,
      recordDate: _getTodayDate(),
      description: text,
    );
  }
  
  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 解析结果
class ParseResult {
  final bool success;
  final double amount;
  final String recordType;
  final int? categoryId;
  final String? categoryName;
  final String recordDate;
  final String description;
  final String? error;
  
  ParseResult({
    required this.success,
    required this.amount,
    required this.recordType,
    this.categoryId,
    this.categoryName,
    required this.recordDate,
    required this.description,
    this.error,
  });
  
  Record toRecord() {
    return Record(
      amount: amount,
      recordType: recordType,
      categoryId: categoryId ?? 1,
      categoryName: categoryName,
      recordDate: recordDate,
      description: description,
    );
  }
}
