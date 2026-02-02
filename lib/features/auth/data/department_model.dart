class Department {
  final int id;
  final String name;
  final String description;

  Department({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['department_id'] as int,
      name: json['department_name'] ?? '',
      description: json['department_description'] ?? '',
    );
  }
}
