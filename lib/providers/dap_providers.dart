// lib/providers/dap_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dap_monitor/data/dap_model.dart';
import '../features/dap_monitor/data/dap_repository.dart';
import 'auth_provider.dart';

// For My Day customers (from SQLite)
import '../core/database/database_manager.dart';

/// =======================
/// DAP / DAILY PLAN LOGIC
/// =======================

final dapRepositoryProvider = Provider((ref) => DapRepository());

// Provider to fetch "Today's" Plan for the LOGGED IN USER
final dapByDateProvider =
FutureProvider.family.autoDispose<List<DapWithDetails>, DateTime>(
        (ref, date) async {
      final repo = ref.watch(dapRepositoryProvider);
      final authState = ref.watch(authProvider);

      if (authState.user == null) return [];

      // Fetch data for the SPECIFIC date passed in
      return repo.getDapForDate(date, authState.user!.userId);
    });

// Controller to handle actions (like checkbox toggling)
class DapController extends StateNotifier<AsyncValue<void>> {
  final DapRepository _repo;
  final Ref _ref;

  DapController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> toggleDap(int id, bool currentStatus) async {
    try {
      await _repo.toggleStatus(id, currentStatus);
      // Refresh all DAP entries (all dates) – this is okay for now
      _ref.invalidate(dapByDateProvider);
    } catch (e) {
      print(e);
    }
  }
}

final dapControllerProvider =
StateNotifierProvider<DapController, AsyncValue<void>>((ref) {
  return DapController(ref.watch(dapRepositoryProvider), ref);
});

/// =======================
/// MY DAY CUSTOMERS (NO DUPLICATES)
/// =======================

class MyDayCustomer {
  final int id;
  final String code;
  final String name;
  final String? brgy;
  final String? city;
  final String? province;

  MyDayCustomer({
    required this.id,
    required this.code,
    required this.name,
    this.brgy,
    this.city,
    this.province,
  });

  factory MyDayCustomer.fromMap(Map<String, dynamic> map) {
    return MyDayCustomer(
      id: map['id'] as int,
      code: (map['customer_code'] ?? '').toString(),
      name: (map['customer_name'] ?? '').toString(),
      brgy: map['brgy']?.toString(),
      city: map['city']?.toString(),
      province: map['province']?.toString(),
    );
  }
}

/// Customers assigned to a given salesman (no duplicates)
final myDayCustomersProvider =
FutureProvider.family<List<MyDayCustomer>, int?>((ref, salesmanId) async {
  if (salesmanId == null) return [];

  final db =
  await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

  // 1) DISTINCT at SQL level
  final rows = await db.rawQuery('''
    SELECT DISTINCT
      c.id,
      c.customer_code,
      c.customer_name,
      c.brgy,
      c.city,
      c.province
    FROM customer c
    INNER JOIN customer_salesman cs
      ON cs.customer_id = c.id
    WHERE cs.salesman_id = ?
    ORDER BY c.customer_name
  ''', [salesmanId]);

  // 2) Extra safety: dedupe in Dart using a map keyed by customer id
  final Map<int, MyDayCustomer> uniqueById = {};

  for (final row in rows) {
    final customer = MyDayCustomer.fromMap(row as Map<String, dynamic>);
    uniqueById[customer.id] = customer;
  }

  final result = uniqueById.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return result;
});
