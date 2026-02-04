class Customer {
  final int id;
  final String name;
  final String code;

  const Customer({required this.id, required this.name, required this.code});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int? ?? 0,
      name: (json['customer_name'] ?? json['name'] ?? '').toString(),
      code: (json['customer_code'] ?? json['code'] ?? '').toString(),
    );
  }

  @override
  String toString() => '$name ($code)';
}
