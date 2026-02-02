// lib/core/api/local_db_api.dart

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../database/database_manager.dart';

class LocalDbApi {
  final DatabaseManager _dbManager = DatabaseManager();

  // Cache table columns to prevent "no such column" insert errors
  final Map<String, Set<String>> _tableColumnsCache = {};

  void clearColumnCache() => _tableColumnsCache.clear();

  /// Insert/Replace one row safely.
  Future<void> upsertRow({
    required String dbName,
    required String tableName,
    required Map<String, dynamic> row,
  }) async {
    final db = await _dbManager.getDatabase(dbName);

    await db.transaction((txn) async {
      final cols = await _getTableColumns(
        executor: txn,
        cacheKey: '$dbName::$tableName',
        tableName: tableName,
      );

      if (cols.isEmpty) return;

      final normalized = _normalizeForTable(tableName, row);
      final sanitized = _sanitizeForSqlite(normalized);
      final filtered = _filterByColumns(sanitized, cols);

      if (filtered.isEmpty) return;

      await txn.insert(
        tableName,
        filtered,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Full refresh: delete all then insert list.
  Future<void> replaceAll({
    required String dbName,
    required String tableName,
    required List<Map<String, dynamic>> rows,
  }) async {
    final db = await _dbManager.getDatabase(dbName);

    await db.transaction((txn) async {
      final batch = txn.batch();

      final cols = await _getTableColumns(
        executor: txn,
        cacheKey: '$dbName::$tableName',
        tableName: tableName,
      );

      // If we can't read columns, skip inserts to prevent crashes.
      batch.delete(tableName);
      if (cols.isEmpty) {
        await batch.commit(noResult: true);
        return;
      }

      for (final r in rows) {
        final normalized = _normalizeForTable(tableName, r);
        final sanitized = _sanitizeForSqlite(normalized);
        final filtered = _filterByColumns(sanitized, cols);
        if (filtered.isEmpty) continue;

        batch.insert(
          tableName,
          filtered,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  // --- COLUMN HELPERS ---

  Future<Set<String>> _getTableColumns({
    required DatabaseExecutor executor,
    required String cacheKey,
    required String tableName,
  }) async {
    final cached = _tableColumnsCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    List<Map<String, Object?>> rows = [];
    try {
      rows = await executor.rawQuery('PRAGMA table_info($tableName)');
    } catch (_) {}

    if (rows.isEmpty) {
      try {
        rows = await executor.rawQuery('PRAGMA table_info("$tableName")');
      } catch (_) {}
    }

    final cols = <String>{};
    for (final r in rows) {
      final name = r['name'];
      if (name is String && name.isNotEmpty) cols.add(name);
    }

    _tableColumnsCache[cacheKey] = cols;
    return cols;
  }

  Map<String, dynamic> _filterByColumns(
      Map<String, dynamic> row,
      Set<String> allowedCols,
      ) {
    // STRICT: if columns are unknown, do not insert raw row.
    if (allowedCols.isEmpty) return <String, dynamic>{};

    final filtered = <String, dynamic>{};
    row.forEach((k, v) {
      if (allowedCols.contains(k)) filtered[k] = v;
    });
    return filtered;
  }

  // --- NORMALIZATION ---

  Map<String, dynamic> _normalizeForTable(
      String tableName,
      Map<String, dynamic> json,
      ) {
    final m = Map<String, dynamic>.from(json);

    void renameKey(String from, String to) {
      if (from == to) return;

      if (m.containsKey(from)) {
        if (!m.containsKey(to)) {
          m[to] = m[from];
        }
        m.remove(from); // always remove source
      }
    }

    if (tableName == 'user') {
      renameKey('updateAt', 'updated_at');
      renameKey('update_at', 'updated_at');

      renameKey('externalId', 'external_id');
      renameKey('isDeleted', 'is_deleted');
      renameKey('isAdmin', 'is_admin');

      // API user_dateOfHire → SQLite user_date_of_hire
      renameKey('user_dateOfHire', 'user_date_of_hire');
      renameKey('user_dateOfhire', 'user_date_of_hire');
      renameKey('dateOfHire', 'user_date_of_hire');
      renameKey('date_of_hire', 'user_date_of_hire');

      // extra safety
      m.remove('user_dateOfHire');
      m.remove('user_dateOfhire');
      m.remove('dateOfHire');
      m.remove('date_of_hire');
    }

    if (tableName == 'unit') {
      renameKey('order', 'sort_order');
      m.remove('order');
    }

    return m;
  }

  // --- SANITIZER ---

  Map<String, dynamic> _sanitizeForSqlite(Map<String, dynamic> json) {
    final Map<String, dynamic> clean = {};

    json.forEach((key, value) {
      if (value == null) {
        clean[key] = null;
      } else if (value is bool) {
        clean[key] = value ? 1 : 0;
      } else if (value is Map && value['type'] == 'Buffer' && value['data'] is List) {
        final list = value['data'] as List;
        clean[key] = list.isNotEmpty ? list[0] : 0;
      } else if (value is Map) {
        clean[key] = jsonEncode(value);
      } else if (value is List) {
        clean[key] = jsonEncode(value);
      } else {
        clean[key] = value;
      }
    });

    return clean;
  }
}
