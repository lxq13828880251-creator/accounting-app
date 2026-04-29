class Record {
  final int? id;
  final double amount;
  final String recordType; // 'expense' | 'income'
  final int? categoryId;
  final String? categoryName;
  final String recordDate;
  final String? description;
  final DateTime? createdAt;
  
  Record({
    this.id,
    required this.amount,
    required this.recordType,
    this.categoryId,
    this.categoryName,
    required this.recordDate,
    this.description,
    this.createdAt,
  });
  
  factory Record.fromJson(Map<String, dynamic> json) {
    // 处理金额：可能是字符串或数字
    double amount = 0;
    final amountValue = json['amount'];
    if (amountValue is num) {
      amount = amountValue.toDouble();
    } else if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0;
    }
    
    return Record(
      id: json['id'],
      amount: amount,
      recordType: json['record_type'] ?? 'expense',
      categoryId: json['category_id'],
      // 后端可能没有返回category_name，尝试多个字段名
      categoryName: json['category_name'] ?? json['categoryName'],
      recordDate: json['record_date'],
      // 后端字段是note，不是description
      description: json['description'] ?? json['note'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'record_type': recordType,
      'category_id': categoryId,
      'record_date': recordDate,
      if (description != null) 'description': description,
    };
  }
  
  Record copyWith({
    int? id,
    double? amount,
    String? recordType,
    int? categoryId,
    String? categoryName,
    String? recordDate,
    String? description,
  }) {
    return Record(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      recordType: recordType ?? this.recordType,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      recordDate: recordDate ?? this.recordDate,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
