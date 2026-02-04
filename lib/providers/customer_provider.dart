import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_manager.dart';
import '../data/models/customer_model.dart';

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final db = await DatabaseManager().getDatabase();
  final result = await db.query('customer');

  if (result.isEmpty) {
    return <Customer>[];
  }

  return result.map((json) {
    final Map<String, dynamic> modifiableJson = Map.from(json);
    return Customer.fromJson(modifiableJson);
  }).toList();
});

final customersWithHistoryProvider = FutureProvider<List<Customer>>((
  ref,
) async {
  final db = await DatabaseManager().getDatabase();
  // Join customer with sales_order to get only those with orders
  final result = await db.rawQuery('''
    SELECT DISTINCT c.* 
    FROM customer c 
    JOIN sales_order s ON c.customer_code = s.customer_code
  ''');

  if (result.isEmpty) {
    return <Customer>[];
  }

  return result.map((json) {
    final Map<String, dynamic> modifiableJson = Map.from(json);
    return Customer.fromJson(modifiableJson);
  }).toList();
});
