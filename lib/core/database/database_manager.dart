// lib/core/database/database_manager.dart
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'table_schemas.dart';

class DatabaseManager {
  // Singleton pattern
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  // ✅ Unified DB file name (single file for all tables)
  static const String dbMain = 'vos_sfa_go.db';

  // ✅ Backward-compatible "names" (existing code references these)
  // They all map to the same unified file now.
  static const String dbUser = dbMain;
  static const String dbCustomer = dbMain;
  static const String dbSales = dbMain;
  static const String dbTasks = dbMain;

  // 🔺 bump version when you add/rename tables/columns
  // Version 7: Added sales_order_attachment
  // Version 8: Fix sales_return schema
  // Version 9: Added discount tables
  static const int _dbVersion = 9;

  Database? _db;

  // Keep this map only for compatibility with your existing code.
  // Internally, it will always point to the same DB instance.
  final Map<String, Database> _openDatabases = {};

  /// ✅ Backward-compatible method signature.
  /// Existing code passes dbUser/dbSales/etc. We ignore that and open ONE DB.
  Future<Database> getDatabase([String? dbName]) async {
    if (_db != null && _db!.isOpen) {
      // Cache entry for any dbName requested (compat)
      if (dbName != null) _openDatabases[dbName] = _db!;
      return _db!;
    }

    final db = await _initDatabase(); // always dbMain
    _db = db;

    // Cache for any name passed (compat)
    if (dbName != null) _openDatabases[dbName] = db;

    return db;
  }

  Future<Database> _initDatabase() async {
    // ✅ Put DB in the standard /databases folder (Android Device Explorer)
    final String dbDir = await getDatabasesPath();
    await Directory(dbDir).create(recursive: true);

    final String dbPath = join(dbDir, dbMain);
    // Optional debug:
    // print("SQLite DB Path: $dbPath");

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createAllTables(db);
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Ensure tables exist (safe)
        await _createAllTables(db);

        // ✅ Run real ALTER migrations for existing installs
        await _runMigrations(db, oldVersion, newVersion);

        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  /// ✅ Create ALL tables in ONE database.
  Future<void> _createAllTables(Database db) async {
    // --- USER / MASTER DATA ---
    await db.execute(TableSchemas.userTable);
    await db.execute(TableSchemas.salesmanTable);
    await db.execute(TableSchemas.departmentTable);

    // --- CUSTOMER ---
    await db.execute(TableSchemas.customerTable);
    await db.execute(TableSchemas.supplierTable);
    await db.execute(TableSchemas.customerSalesmanTable);

    // Create once in unified DB
    await db.execute(TableSchemas.productPerSupplierTable);

    // --- SALES ---
    await db.execute(TableSchemas.productTable);
    await db.execute(TableSchemas.unitTable);
    await db.execute(TableSchemas.salesOrderTable);
    await db.execute(TableSchemas.salesOrderDetailsTable);
    await db.execute(TableSchemas.salesOrderAttachmentTable); // ✅ NEW
    await db.execute(TableSchemas.salesInvoiceTable);
    await db.execute(TableSchemas.salesInvoiceDetailsTable);
    await db.execute(TableSchemas.salesReturnTable);
    await db.execute(TableSchemas.salesReturnDetailsTable);

    // --- TASKS ---
    await db.execute(TableSchemas.taskTable);
    await db.execute(TableSchemas.dailyActionPlanTable);
    await db.execute(TableSchemas.monthlyCoveragePlanTable);
    await db.execute(TableSchemas.dapAttachmentTable);

    // --- DISCOUNTS ---
    await db.execute(TableSchemas.discountTypeTable);
    await db.execute(TableSchemas.lineDiscountTable);
    await db.execute(TableSchemas.linePerDiscountTypeTable);
    await db.execute(TableSchemas.supplierCategoryDiscountPerCustomerTable);
    await db.execute(TableSchemas.productPerCustomerTable);
  }

  // ✅ Real migrations (ALTER TABLE) for existing installs
  Future<void> _runMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v5 migrations: user compatibility columns
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'user', 'user_dateOfHire', 'TEXT');
      await _addColumnIfMissing(db, 'user', 'updateAt', 'TEXT');
      await _addColumnIfMissing(db, 'user', 'update_at', 'TEXT');
      await _addColumnIfMissing(db, 'user', 'externalId', 'TEXT');
      await _addColumnIfMissing(db, 'user', 'isDeleted', 'INTEGER');
      await _addColumnIfMissing(db, 'user', 'isAdmin', 'INTEGER');
    }

    // v6 migrations: unit.sort_order (legacy had unit."order")
    if (oldVersion < 6) {
      await _addColumnIfMissing(db, 'unit', 'sort_order', 'INTEGER');

      final cols = await _getColumns(db, 'unit');
      if (cols.contains('order')) {
        await db.execute('''
          UPDATE unit
          SET sort_order = COALESCE(sort_order, "order")
          WHERE sort_order IS NULL;
        ''');
      }
    }

    // v7 migrations: sales_order_attachment
    if (oldVersion < 7) {
      await db.execute(TableSchemas.salesOrderAttachmentTable);
    }

    // v8 migrations: Fix sales_return schema (FK mismatch)
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS sales_return_details');
      await db.execute('DROP TABLE IF EXISTS sales_return');
      await db.execute(TableSchemas.salesReturnTable);
      await db.execute(TableSchemas.salesReturnTable);
      await db.execute(TableSchemas.salesReturnDetailsTable);
    }

    // v9 migrations: Discount tables
    if (oldVersion < 9) {
      await db.execute(TableSchemas.discountTypeTable);
      await db.execute(TableSchemas.lineDiscountTable);
      await db.execute(TableSchemas.linePerDiscountTypeTable);
      await db.execute(TableSchemas.supplierCategoryDiscountPerCustomerTable);
      await db.execute(TableSchemas.productPerCustomerTable);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final cols = await _getColumns(db, table);
    if (cols.contains(column)) return;

    await db.execute('ALTER TABLE "$table" ADD COLUMN "$column" $type;');
  }

  Future<Set<String>> _getColumns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    final set = <String>{};
    for (final r in rows) {
      final name = r['name'];
      if (name is String && name.isNotEmpty) set.add(name);
    }
    return set;
  }

  // ✅ Keep these for compatibility with existing code.
  Future<void> closeDatabase(String dbName) async {
    // In unified DB mode, closing “one” name closes the single DB.
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _openDatabases.clear();
  }

  Future<void> closeAll() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _openDatabases.clear();
  }
}
