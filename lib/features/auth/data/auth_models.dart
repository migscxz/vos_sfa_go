class User {
  final int userId;
  final String email;
  final String password;
  final String fname;
  final String lname;
  final int department; // <--- ADD THIS

  User({
    required this.userId,
    required this.email,
    required this.password,
    required this.fname,
    required this.lname,
    required this.department, // <--- ADD THIS
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int,
      email: json['user_email'] ?? '',
      password: json['user_password'] ?? '',
      fname: json['user_fname'] ?? '',
      lname: json['user_lname'] ?? '',
      // Make sure to default to 0 if null
      department: json['user_department'] is int ? json['user_department'] : 0,
    );
  }
}

class Salesman {
  final int id;
  final String code;
  final String name;
  final int? branchId;
  final String? priceType; // 🔹 NEW

  Salesman({
    required this.id,
    required this.code,
    required this.name,
    this.branchId,
    this.priceType, // 🔹 NEW
  });

  factory Salesman.fromJson(Map<String, dynamic> json) {
    return Salesman(
      id: json['id'] as int,
      code: json['salesman_code'] ?? '',
      name: json['salesman_name'] ?? '',
      branchId: json['branch_code'] as int?,
      priceType: json['price_type']?.toString(), // 🔹 maps "A", "B", etc.
    );
  }
}