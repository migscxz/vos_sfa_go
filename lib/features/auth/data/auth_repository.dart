// lib/features/auth/data/auth_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_manager.dart';
import '../../../core/api/remote_auth_api.dart';
import 'auth_models.dart';
import 'department_model.dart'; // adjust import if needed

class AuthRepository {
  final DatabaseManager _dbManager = DatabaseManager();
  final RemoteAuthApi _remoteApi = RemoteAuthApi();

  // Check if we need to sync
  Future<bool> hasUsers() async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbUser);
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM user'),
      );
      return (count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  // SYNC (User + Salesman + Department)
  Future<void> syncAuthData() async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbUser);

    final remoteUsers = await _remoteApi.fetchAllUsers();
    final remoteSalesmen = await _remoteApi.fetchAllSalesmen();
    final remoteDepartments = await _remoteApi.fetchAllDepartments();

    await db.transaction((txn) async {
      await txn.delete('user');
      await txn.delete('salesman');
      await txn.delete('department');

      // ✅ Load real SQLite columns so we only insert what exists
      final userCols = await _getTableColumns(txn, 'user');
      final salesmanCols = await _getTableColumns(txn, 'salesman');
      final deptCols = await _getTableColumns(txn, 'department');

      final batch = txn.batch();

      for (final u in remoteUsers) {
        batch.insert('user', _sanitizeForSqlite(u, allowedColumns: userCols, table: 'user'));
      }

      for (final s in remoteSalesmen) {
        batch.insert('salesman', _sanitizeForSqlite(s, allowedColumns: salesmanCols, table: 'salesman'));
      }

      for (final d in remoteDepartments) {
        batch.insert('department', _sanitizeForSqlite(d, allowedColumns: deptCols, table: 'department'));
      }

      await batch.commit(noResult: true);
    });
  }

  /// Returns a set of actual column names for a table.
  Future<Set<String>> _getTableColumns(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final cols = <String>{};
    for (final r in rows) {
      final name = r['name'];
      if (name != null) cols.add(name.toString());
    }
    return cols;
  }

  /// Returns a SQLite-safe map:
  /// - converts bool -> 0/1
  /// - converts Buffer objects -> first byte (your current behavior)
  /// - maps/normalizes some compatibility keys
  /// - ✅ drops keys that are not real SQLite columns for the target table
  Map<String, dynamic> _sanitizeForSqlite(
      Map<String, dynamic> json, {
        required Set<String> allowedColumns,
        required String table,
      }) {
    // Work on a copy so we can safely rewrite keys
    final Map<String, dynamic> input = Map<String, dynamic>.from(json);

    // ✅ Compatibility: API sends hash_password, SQLite table uses user_password
    if (input.containsKey('hash_password')) {
      final hp = input['hash_password'];
      final up = input['user_password'];

      final hpStr = hp == null ? '' : hp.toString();
      final upStr = up == null ? '' : up.toString();

      if (upStr.trim().isEmpty && hpStr.trim().isNotEmpty) {
        input['user_password'] = hp;
      }

      // Always remove to avoid "no column named hash_password"
      input.remove('hash_password');
    }

    // ✅ Compatibility: API may send "role" but SQLite doesn't have `role`
    // Your schema has role_id (int) and is_admin (int). We do safe mapping only if applicable.
    if (input.containsKey('role')) {
      final roleVal = input['role'];

      // If role_id exists in table and role is numeric, map it.
      if (allowedColumns.contains('role_id') && !input.containsKey('role_id')) {
        final parsed = int.tryParse(roleVal?.toString() ?? '');
        if (parsed != null) {
          input['role_id'] = parsed;
        }
      }

      // If is_admin exists in table and role looks like admin, set it.
      if (allowedColumns.contains('is_admin')) {
        final roleStr = (roleVal?.toString() ?? '').toLowerCase().trim();
        if (roleStr == 'admin' || roleStr.contains('admin')) {
          input['is_admin'] = 1;
        }
      }

      // Remove `role` since it is not a SQLite column in your schema.
      input.remove('role');
    }

    // ✅ Now whitelist keys strictly by the actual SQLite columns
    final Map<String, dynamic> clean = {};
    input.forEach((key, value) {
      if (!allowedColumns.contains(key)) return; // DROP unknown columns
      clean[key] = _normalizeSqliteValue(value);
    });

    return clean;
  }

  dynamic _normalizeSqliteValue(dynamic value) {
    if (value is bool) return value ? 1 : 0;

    // keep your existing buffer compatibility
    if (value is Map && value['type'] == 'Buffer' && value['data'] is List) {
      final list = value['data'] as List;
      return list.isNotEmpty ? list[0] : 0;
    }

    return value;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbUser);

    // 1) Find user
    final List<Map<String, dynamic>> userResult = await db.query(
      'user',
      where: 'user_email = ? AND user_password = ?',
      whereArgs: [email, password],
    );

    if (userResult.isEmpty) {
      throw Exception('Invalid Email or Password');
    }

    final user = User.fromJson(userResult.first);
    print('AuthRepository.login → userId=${user.userId}, dept=${user.department}');

    // 2) Department check (must be Sales)
    final List<Map<String, dynamic>> deptResult = await db.query(
      'department',
      where: 'department_id = ?',
      whereArgs: [user.department],
    );

    if (deptResult.isEmpty) {
      throw Exception('User department not found in database. Please Sync.');
    }

    final department = Department.fromJson(deptResult.first);
    final deptName = (department.name).toLowerCase();

    if (!deptName.contains('sales')) {
      throw Exception(
        'Access Denied: Only Sales Department can log in.\nYour Role: ${department.name}',
      );
    }

    // 3) Load ALL salesman accounts for this user (multi-account support)
    // 🔑 MAIN RULE: salesman.employee_id == user.user_id
    List<Map<String, dynamic>> salesmanRows = await db.query(
      'salesman',
      where: 'employee_id = ? AND IFNULL(isActive, 0) = 1',
      whereArgs: [user.userId],
    );

    // 🔁 FALLBACK: encoder_id == user.user_id
    if (salesmanRows.isEmpty) {
      salesmanRows = await db.query(
        'salesman',
        where: 'encoder_id = ? AND IFNULL(isActive, 0) = 1',
        whereArgs: [user.userId],
      );
    }

    final salesmen = salesmanRows.map((r) => Salesman.fromJson(r)).toList();

    if (salesmen.isNotEmpty) {
      print('AuthRepository.login → linked salesman accounts: ${salesmen.length}');
    } else {
      print(
        'AuthRepository.login → NO salesman linked for userId=${user.userId}. '
            'Sales dept can still login, but sync will be global.',
      );
    }

    return {
      'user': user,
      'salesmen': salesmen, // ✅ List<Salesman>
    };
  }
}
