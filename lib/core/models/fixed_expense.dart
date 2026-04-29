/// 月固定费用模型
class FixedExpense {
  final int? id;
  final int userId;
  final String name;
  final double amount;
  final String categoryId;
  final String? note;
  final bool isEnabled;
  final int dayOfMonth;
  final DateTime createdAt;
  final DateTime updatedAt;

  FixedExpense({
    this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.categoryId,
    this.note,
    this.isEnabled = true,
    this.dayOfMonth = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'amount': amount,
      'category_id': categoryId,
      'note': note,
      'is_enabled': isEnabled,
      'day_of_month': dayOfMonth,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FixedExpense.fromJson(Map<String, dynamic> json) {
    return FixedExpense(
      id: json['id'],
      userId: json['user_id'] ?? 1,
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      categoryId: json['category_id'] ?? '',
      note: json['note'],
      isEnabled: json['is_enabled'] ?? true,
      dayOfMonth: json['day_of_month'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  FixedExpense copyWith({
    int? id,
    int? userId,
    String? name,
    double? amount,
    String? categoryId,
    String? note,
    bool? isEnabled,
    int? dayOfMonth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FixedExpense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      isEnabled: isEnabled ?? this.isEnabled,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  double get monthlyTotal => amount;

  @override
  String toString() {
    return 'FixedExpense(id: $id, name: $name, amount: $amount, isEnabled: $isEnabled)';
  }
}
