// lib/core/api/global_sync_service.dart

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_manager.dart';
import 'global_remote_api.dart';
import 'api_config.dart';

class GlobalSyncService {
  final GlobalRemoteApi _api = GlobalRemoteApi();
  final DatabaseManager _dbManager = DatabaseManager();

  // Cache table columns so we can safely filter out unknown API keys
  final Map<String, Set<String>> _tableColumnsCache = {};

  /// Triggers a Full Sync of all modules.
  ///
  /// If [salesmanId] is provided, SALES DATA (orders, invoices, returns)
  /// and CUSTOMERS will be filtered per salesman.
  Future<void> syncAllData({int? salesmanId}) async {
    // IMPORTANT: clear cached columns so schema changes are reflected immediately
    _tableColumnsCache.clear();

    print('GlobalSyncService.syncAllData → salesmanId=$salesmanId');

    // 1) USER DB (always global)
    await _syncModule(
      dbName: DatabaseManager.dbUser,
      tasks: {
        'user': ApiConfig.user,
        'salesman': ApiConfig.salesman,
        'department': ApiConfig.department,
      },
    );

    // 2) CUSTOMER DB
    if (salesmanId == null) {
      await _syncModule(
        dbName: DatabaseManager.dbCustomer,
        tasks: {
          'customer': ApiConfig.customer,
          'supplier': ApiConfig.suppliers,
          'customer_salesman': ApiConfig.customerSalesmen,
        },
      );
    } else {
      await _syncCustomersForSalesman(salesmanId);
    }

    // 3) SALES DB
    if (salesmanId == null) {
      await _syncModule(
        dbName: DatabaseManager.dbSales,
        tasks: {
          'product': ApiConfig.products,
          'unit': ApiConfig.units,
          'product_per_supplier': ApiConfig.productPerSupplier,
          'sales_order': ApiConfig.salesOrder,
          'sales_order_details': ApiConfig.salesOrderDetails,
          'sales_invoice': ApiConfig.salesInvoice,
          'sales_invoice_details': ApiConfig.salesInvoiceDetails,
          'sales_return': ApiConfig.salesReturn,
          'sales_return_details': ApiConfig.salesReturnDetails,
        },
      );
    } else {
      await _syncSalesForSalesman(salesmanId);
    }

    // 4) TASKS DB (global)
    await _syncModule(
      dbName: DatabaseManager.dbTasks,
      tasks: {
        'task': ApiConfig.task,
        'daily_action_plan': ApiConfig.dap,
        'monthly_coverage_plan': ApiConfig.mcp,
        'daily_action_plan_attachment': ApiConfig.dailyActionPlanAttachment,
      },
    );
  }

  /// Generic helper to sync ALL records for a set of endpoints into a DB.
  Future<void> _syncModule({
    required String dbName,
    required Map<String, String> tasks, // Map<tableName, endpoint>
  }) async {
    final db = await _dbManager.getDatabase(dbName);

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final entry in tasks.entries) {
        final tableName = entry.key;
        final endpoint = entry.value;

        try {
          final dataList = await _api.fetchList(
            endpoint,
            query: {'limit': '-1'},
          );

          final columns = await _getTableColumns(
            executor: txn,
            cacheKey: '$dbName::$tableName',
            tableName: tableName,
          );

          // Full refresh: clear table then insert
          batch.delete(tableName);

          // If we cannot determine columns, do NOT insert raw payloads.
          if (columns.isEmpty) {
            print(
              'WARNING: PRAGMA returned 0 columns for $dbName::$tableName. '
                  'Skipping inserts to avoid unknown-column crashes.',
            );
            continue;
          }

          for (final item in dataList) {
            final normalized = _normalizeForTable(tableName, item);
            final sanitized = _sanitizeForSqlite(normalized);
            final filtered = _filterByColumns(sanitized, columns);

            if (filtered.isEmpty) continue;

            batch.insert(
              tableName,
              filtered,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('Synced $tableName: ${dataList.length} records.');
        } catch (e) {
          print('Error syncing table $tableName: $e');
        }
      }

      await batch.commit(noResult: true);
    });
  }

  /// Special sync for CUSTOMERS filtered by [salesmanId].
  Future<void> _syncCustomersForSalesman(int salesmanId) async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbCustomer);

    await db.transaction((txn) async {
      final batch = txn.batch();

      try {
        final csColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbCustomer}::customer_salesman',
          tableName: 'customer_salesman',
        );
        final cColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbCustomer}::customer',
          tableName: 'customer',
        );
        final sColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbCustomer}::supplier',
          tableName: 'supplier',
        );

        // 1) customer_salesman mapping filtered by salesman
        final mappingList = await _api.fetchList(
          ApiConfig.customerSalesmen,
          query: {
            'filter[salesman_id][_eq]': '$salesmanId',
            'limit': '-1',
          },
        );

        batch.delete('customer_salesman');

        final Set<int> customerIds = {};

        for (final row in mappingList) {
          final cid = row['customer_id'];
          if (cid is int) customerIds.add(cid);

          final normalized = _normalizeForTable('customer_salesman', row);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, csColumns);

          if (filtered.isEmpty) continue;

          batch.insert(
            'customer_salesman',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print(
          'Synced customer_salesman for salesman $salesmanId: ${mappingList.length} records.',
        );

        // 2) customer only those ids
        batch.delete('customer');

        if (customerIds.isNotEmpty) {
          final customers = await _api.fetchList(
            ApiConfig.customer,
            query: {
              'filter[id][_in]': customerIds.join(','),
              'limit': '-1',
            },
          );

          for (final c in customers) {
            final normalized = _normalizeForTable('customer', c);
            final sanitized = _sanitizeForSqlite(normalized);
            final filtered = _filterByColumns(sanitized, cColumns);

            if (filtered.isEmpty) continue;

            batch.insert(
              'customer',
              filtered,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('Synced customer for salesman $salesmanId: ${customers.length} records.');
        } else {
          print('No mapped customers for salesman $salesmanId → local customer table will be empty.');
        }

        // 3) suppliers global
        final suppliers = await _api.fetchList(
          ApiConfig.suppliers,
          query: {'limit': '-1'},
        );

        batch.delete('supplier');

        for (final s in suppliers) {
          final normalized = _normalizeForTable('supplier', s);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, sColumns);

          if (filtered.isEmpty) continue;

          batch.insert(
            'supplier',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced supplier: ${suppliers.length} records.');
      } catch (e) {
        print('Error syncing customers for salesman $salesmanId: $e');
      }

      await batch.commit(noResult: true);
    });
  }

  /// Special sync for SALES DB filtered by [salesmanId].
  Future<void> _syncSalesForSalesman(int salesmanId) async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbSales);

    await db.transaction((txn) async {
      final batch = txn.batch();

      try {
        final pColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::product',
          tableName: 'product',
        );
        final uColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::unit',
          tableName: 'unit',
        );
        final ppsColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::product_per_supplier',
          tableName: 'product_per_supplier',
        );
        final soColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_order',
          tableName: 'sales_order',
        );
        final sodColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_order_details',
          tableName: 'sales_order_details',
        );
        final siColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_invoice',
          tableName: 'sales_invoice',
        );
        final sidColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_invoice_details',
          tableName: 'sales_invoice_details',
        );
        final srColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_return',
          tableName: 'sales_return',
        );
        final srdColumns = await _getTableColumns(
          executor: txn,
          cacheKey: '${DatabaseManager.dbSales}::sales_return_details',
          tableName: 'sales_return_details',
        );

        // 1) product global
        final products = await _api.fetchList(
          ApiConfig.products,
          query: {'limit': '-1'},
        );

        batch.delete('product');

        for (final item in products) {
          final normalized = _normalizeForTable('product', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, pColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'product',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced product: ${products.length} records.');

        // 1a) unit global
        try {
          final units = await _api.fetchList(
            ApiConfig.units,
            query: {'limit': '-1'},
          );

          batch.delete('unit');

          for (final item in units) {
            final normalized = _normalizeForTable('unit', item); // "order"→"sort_order"
            final sanitized = _sanitizeForSqlite(normalized);
            final filtered = _filterByColumns(sanitized, uColumns);
            if (filtered.isEmpty) continue;

            batch.insert(
              'unit',
              filtered,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('Synced unit: ${units.length} records.');
        } catch (e) {
          print('Error syncing unit: $e');
        }

        // 1b) product_per_supplier global
        try {
          final ppsList = await _api.fetchList(
            ApiConfig.productPerSupplier,
            query: {'limit': '-1'},
          );

          batch.delete('product_per_supplier');

          for (final row in ppsList) {
            final normalized = _normalizeForTable('product_per_supplier', row);
            final sanitized = _sanitizeForSqlite(normalized);
            final filtered = _filterByColumns(sanitized, ppsColumns);
            if (filtered.isEmpty) continue;

            batch.insert(
              'product_per_supplier',
              filtered,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('Synced product_per_supplier (global): ${ppsList.length} records.');
        } catch (e) {
          print('Error syncing product_per_supplier: $e');
        }

        // 2) sales_order filtered by salesman
        final salesOrders = await _api.fetchList(
          ApiConfig.salesOrder,
          query: {
            'filter[salesman_id][_eq]': '$salesmanId',
            'limit': '-1',
          },
        );

        batch.delete('sales_order');

        for (final item in salesOrders) {
          final normalized = _normalizeForTable('sales_order', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, soColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_order',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_order for salesman $salesmanId: ${salesOrders.length} records.');

        final Set<String> soOrderIds = {};
        for (final o in salesOrders) {
          final oid = o['order_id'];
          if (oid != null) soOrderIds.add(oid.toString());
        }

        // 3) sales_invoice filtered by salesman
        final invoices = await _api.fetchList(
          ApiConfig.salesInvoice,
          query: {
            'filter[salesman_id][_eq]': '$salesmanId',
            'limit': '-1',
          },
        );

        batch.delete('sales_invoice');

        for (final item in invoices) {
          final normalized = _normalizeForTable('sales_invoice', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, siColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_invoice',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_invoice for salesman $salesmanId: ${invoices.length} records.');

        final Set<String> siOrderIds = {};
        for (final inv in invoices) {
          final oid = inv['order_id'];
          if (oid != null) siOrderIds.add(oid.toString());
        }

        // 4) sales_return filtered by salesman
        final returns = await _api.fetchList(
          ApiConfig.salesReturn,
          query: {
            'filter[salesman_id][_eq]': '$salesmanId',
            'limit': '-1',
          },
        );

        batch.delete('sales_return');

        for (final item in returns) {
          final normalized = _normalizeForTable('sales_return', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, srColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_return',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_return for salesman $salesmanId: ${returns.length} records.');

        final Set<String> returnNos = {};
        for (final r in returns) {
          final rn = r['return_number'] ?? r['return_no'];
          if (rn != null) returnNos.add(rn.toString());
        }

        // 5) details (chunked _in)
        final soDetails = await _fetchDetailsForIds(
          endpoint: ApiConfig.salesOrderDetails,
          fieldName: 'order_id',
          ids: soOrderIds,
        );

        batch.delete('sales_order_details');

        for (final item in soDetails) {
          final normalized = _normalizeForTable('sales_order_details', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, sodColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_order_details',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_order_details (filtered): ${soDetails.length} records.');

        final siDetails = await _fetchDetailsForIds(
          endpoint: ApiConfig.salesInvoiceDetails,
          fieldName: 'order_id',
          ids: siOrderIds,
        );

        batch.delete('sales_invoice_details');

        for (final item in siDetails) {
          final normalized = _normalizeForTable('sales_invoice_details', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, sidColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_invoice_details',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_invoice_details (filtered): ${siDetails.length} records.');

        final srDetails = await _fetchDetailsForIds(
          endpoint: ApiConfig.salesReturnDetails,
          fieldName: 'return_no',
          ids: returnNos,
        );

        batch.delete('sales_return_details');

        for (final item in srDetails) {
          final normalized = _normalizeForTable('sales_return_details', item);
          final sanitized = _sanitizeForSqlite(normalized);
          final filtered = _filterByColumns(sanitized, srdColumns);
          if (filtered.isEmpty) continue;

          batch.insert(
            'sales_return_details',
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print('Synced sales_return_details (filtered): ${srDetails.length} records.');
      } catch (e) {
        print('Error syncing sales module for salesman $salesmanId: $e');
      }

      await batch.commit(noResult: true);
    });
  }

  /// Helper: fetch detail records using `_in` filter on a given field.
  Future<List<Map<String, dynamic>>> _fetchDetailsForIds({
    required String endpoint,
    required String fieldName,
    required Set<String> ids,
  }) async {
    if (ids.isEmpty) {
      print('No IDs for $endpoint → skipping details fetch.');
      return <Map<String, dynamic>>[];
    }

    final all = <Map<String, dynamic>>[];
    final list = ids.toList();
    const chunkSize = 100;

    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.sublist(
        i,
        i + chunkSize > list.length ? list.length : i + chunkSize,
      );

      final query = <String, String>{
        'filter[$fieldName][_in]': chunk.join(','),
        'limit': '-1',
      };

      try {
        final partial = await _api.fetchList(endpoint, query: query);
        all.addAll(partial);
      } catch (e) {
        print('Error fetching $endpoint chunk: $e');
      }
    }

    return all;
  }

  // --- COLUMN HELPERS ---

  Future<Set<String>> _getTableColumns({
    required DatabaseExecutor executor,
    required String cacheKey,
    required String tableName,
  }) async {
    final cached = _tableColumnsCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    // Try without quotes first, then with quotes
    List<Map<String, Object?>> rows = await executor.rawQuery('PRAGMA table_info($tableName)');
    if (rows.isEmpty) {
      rows = await executor.rawQuery('PRAGMA table_info("$tableName")');
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
    // STRICT MODE: if we don't know table columns, don't insert anything.
    if (allowedCols.isEmpty) return <String, dynamic>{};

    final filtered = <String, dynamic>{};
    row.forEach((k, v) {
      if (allowedCols.contains(k)) filtered[k] = v;
    });
    return filtered;
  }

  // --- TABLE-SPECIFIC NORMALIZATION (key remaps + hard drops) ---

  Map<String, dynamic> _normalizeForTable(
      String tableName,
      Map<String, dynamic> json,
      ) {
    final m = Map<String, dynamic>.from(json);

    void renameKey(String from, String to) {
      if (from == to) return;

      if (m.containsKey(from)) {
        // If destination doesn't exist, move it.
        if (!m.containsKey(to)) {
          m[to] = m[from];
        }
        // Always remove the source key (prevents "no such column ..." crashes)
        m.remove(from);
      }
    }

    if (tableName == 'user') {
      // Align to your SQLite schema columns
      renameKey('updateAt', 'updated_at'); // API has updateAt
      renameKey('update_at', 'updated_at'); // API sometimes includes update_at

      renameKey('externalId', 'external_id'); // API has externalId
      renameKey('isDeleted', 'is_deleted'); // API has isDeleted (nullable)
      renameKey('isAdmin', 'is_admin'); // API has isAdmin (bool)

      // ✅ REQUIRED: API user_dateOfHire → SQLite user_date_of_hire
      renameKey('user_dateOfHire', 'user_date_of_hire');
      renameKey('user_dateOfhire', 'user_date_of_hire');
      renameKey('dateOfHire', 'user_date_of_hire');
      renameKey('date_of_hire', 'user_date_of_hire');

      // ✅ HARD DROP (extra safety): make sure these can never leak to insert
      m.remove('user_dateOfHire');
      m.remove('user_dateOfhire');
      m.remove('dateOfHire');
      m.remove('date_of_hire');
    }

    if (tableName == 'unit') {
      // API uses "order" → SQLite uses "sort_order"
      renameKey('order', 'sort_order');
      m.remove('order'); // extra safety
    }

    return m;
  }

  // --- DATA CLEANER (booleans, Buffers, geo points, arrays, etc.) ---

  Map<String, dynamic> _sanitizeForSqlite(Map<String, dynamic> json) {
    final Map<String, dynamic> clean = {};

    json.forEach((key, value) {
      if (value == null) {
        clean[key] = null;
      } else if (value is bool) {
        clean[key] = value ? 1 : 0;
      } else if (value is Map && value['type'] == 'Buffer' && value['data'] is List) {
        // Directus Buffer → store first byte as int
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
