class Category {
  final int id;
  final String name;
  final String type; // 'expense' | 'income'
  final String? icon;
  final String? color;
  final bool? isSystem;
  
  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isSystem,
  });
  
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['category_type'] ?? json['type'] ?? 'expense',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isSystem: json['is_system'] as bool?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    };
  }
  
  // 预设图标映射（覆盖微信/支付宝常用分类）
  static String getIcon(String name) {
    final icons = {
      // 餐饮类
      '餐饮': '🍜', '早餐': '🥣', '午餐': '🍱', '晚餐': '🍲', '外卖': '🥡', '夜宵': '🍢',
      '零食': '🍪', '水果': '🍎', '咖啡': '☕', '奶茶': '🧋', '蛋糕': '🎂',
      // 交通类
      '交通': '🚗', '打车': '🚕', '公交': '🚌', '地铁': '🚇', '火车': '🚂', '飞机': '✈️',
      '停车': '🅿️', '加油': '⛽', '汽车': '🚙', '保养': '🔧',
      // 购物类
      '购物': '🛒', '网购': '📦', '超市': '🛍️', '日用品': '🧴', '服饰': '👔', '鞋': '👟',
      '包': '👜', '化妆品': '💄', '美容': '💅', '护肤': '🧴',
      // 居住类
      '居住': '🏠', '房租': '🏢', '水电费': '💡', '物业费': '🏗️', '燃气': '🔥', '宽带': '📶',
      // 娱乐类
      '娱乐': '🎮', '电影': '🎬', '游戏': '🎯', '旅游': '🌍', '健身': '🏋️', '运动': '⚽',
      '音乐': '🎵', '演唱会': '🎤', '酒吧': '🍺', 'KTV': '🎤',
      // 医疗类
      '医疗': '🏥', '药品': '💊', '挂号': '📋', '体检': '🩺',
      // 教育类
      '教育': '📚', '学费': '🎓', '培训': '📖', '书籍': '📕', '文具': '✏️',
      // 通讯类
      '通讯': '📱', '话费': '📞', '网费': '📶',
      // 收入类
      '工资': '💰', '奖金': '🎁', '兼职': '💼', '投资收益': '📈', '理财收益': '💹',
      '退款': '↩️', '红包': '🧧', '其他收入': '💵',
      // 其他
      '宠物': '🐱', '保险': '🛡️', '红包': '🧧', '其他': '📦', '待分类': '📦',
    };
    return icons[name] ?? '📦';
  }
}
