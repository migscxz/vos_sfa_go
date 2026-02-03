class Customer {
  final int id;
  final String name;
  final String code;

  const Customer({required this.id, required this.name, required this.code});

  @override
  String toString() => '$name ($code)';
}
