class Customer {
  final int id;
  final String name;
  final String code;
  final String? priceType;

  final int isActive;

  const Customer({
    required this.id,
    required this.name,
    required this.code,
    this.priceType,
    this.isActive = 1,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int? ?? 0,
      name: (json['customer_name'] ?? json['name'] ?? '').toString(),
      code: (json['customer_code'] ?? json['code'] ?? '').toString(),
      priceType: json['price_type'] as String?,
      isActive: (json['isActive'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  String toString() => '$name ($code)';
}
