import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_manager.dart';
import '../../../../data/models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderRepository {
  Future<List<OrderModel>> getOrdersByCustomer(String customerCode) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    final result = await db.query(
      'sales_order',
      where: 'customer_code = ?',
      whereArgs: [customerCode],
      orderBy: 'order_date DESC',
    );

    if (result.isEmpty) return [];

    return result.map((json) => OrderModel.fromSqlite(json)).toList();
  }

  Future<List<OrderModel>> getPendingOrdersByCustomer(
    String customerCode,
  ) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    final result = await db.query(
      'sales_order',
      where: 'customer_code = ? AND is_synced = 0',
      whereArgs: [customerCode],
      orderBy: 'created_date DESC',
    );

    if (result.isEmpty) return [];

    return result.map((json) => OrderModel.fromSqlite(json)).toList();
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    await db.delete('sales_order', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> saveOrder(OrderModel order, List<CartItem> cartItems) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    // Ensure tables exist
    await _ensureSalesTablesExist(db);

    // Insert Header
    final headerRow = order.toSqlite();
    headerRow.remove('id');
    // headerRow.remove('customer_name'); // Keep customer_name
    headerRow.remove('supplier');
    headerRow.remove('order_type');
    headerRow.remove('product');
    headerRow.remove('product_id');
    headerRow.remove('product_base_id');
    headerRow.remove('unit_id');
    headerRow.remove('unit_count');
    headerRow.remove('price_type');
    headerRow.remove('quantity');
    headerRow.remove('has_attachment');
    headerRow.remove('callsheet_image_path');

    final newOrderId = await db.insert(
      'sales_order',
      headerRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert Details
    final batch = db.batch();
    for (final item in cartItems) {
      batch.insert('sales_order_details', {
        'order_id': newOrderId,
        'product_id': item.productId,
        'unit_price': item.price,
        'ordered_quantity': item.quantity,
        'gross_amount': item.total,
        'net_amount': item.total,
        'created_date': order.createdAt.toIso8601String(),
        'remarks': '',
        // Note: discount_type and other nullable fields not included
        // to avoid foreign key errors when syncing to Directus
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureSalesTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_order (
        order_id INTEGER PRIMARY KEY,
        order_no TEXT,
        po_no TEXT,
        customer_code TEXT,
        salesman_id INTEGER,
        supplier_id INTEGER,
        branch_id INTEGER,
        order_date TEXT,
        delivery_date TEXT,
        due_date TEXT,
        payment_terms TEXT,
        order_status TEXT,
        total_amount REAL,
        allocated_amount REAL,
        sales_type TEXT,
        receipt_type TEXT,
        discount_amount REAL,
        net_amount REAL,
        created_by INTEGER,
        created_date TEXT,
        modified_by INTEGER,
        modified_date TEXT,
        posted_by INTEGER,
        posted_date TEXT,
        remarks TEXT,
        isDelivered INTEGER,
        isCancelled INTEGER,
        for_approval_at TEXT,
        for_consolidation_at TEXT,
        for_picking_at TEXT,
        for_invoicing_at TEXT,
        for_loading_at TEXT,
        for_shipping_at TEXT,
        delivered_at TEXT,
        on_hold_at TEXT,
        cancelled_at TEXT,
        customer_name TEXT,
        is_synced INTEGER DEFAULT 0,
        order_type TEXT,
        supplier TEXT,
        product TEXT,
        product_id INTEGER,
        product_base_id INTEGER,
        unit_id INTEGER,
        unit_count REAL,
        price_type TEXT,
        quantity INTEGER,
        has_attachment INTEGER,
        callsheet_image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_order_details (
        detail_id INTEGER PRIMARY KEY,
        product_id INTEGER,
        order_id INTEGER,
        unit_price REAL,
        ordered_quantity INTEGER,
        allocated_quantity INTEGER,
        served_quantity INTEGER,
        discount_type REAL,
        discount_amount REAL,
        gross_amount REAL,
        net_amount REAL,
        allocated_amount REAL,
        remarks TEXT,
        created_date TEXT,
        modified_date TEXT,
        FOREIGN KEY(order_id) REFERENCES sales_order(order_id) ON DELETE CASCADE
      )
    ''');

    // Migration logic
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(sales_order)',
      );
      final existingColumns = columns.map((c) => c['name'] as String).toSet();

      if (!existingColumns.contains('po_no')) {
        await db.execute('ALTER TABLE sales_order ADD COLUMN po_no TEXT');
      }
      if (!existingColumns.contains('remarks')) {
        await db.execute('ALTER TABLE sales_order ADD COLUMN remarks TEXT');
      }
      if (!existingColumns.contains('salesman_id')) {
        await db.execute(
          'ALTER TABLE sales_order ADD COLUMN salesman_id INTEGER',
        );
      }
      if (!existingColumns.contains('is_synced')) {
        await db.execute(
          'ALTER TABLE sales_order ADD COLUMN is_synced INTEGER DEFAULT 0',
        );
      }
      // Ensure allocated_amount exists (for orders created before this fix)
      if (!existingColumns.contains('allocated_amount')) {
        await db.execute(
          'ALTER TABLE sales_order ADD COLUMN allocated_amount REAL',
        );
      } else {
        // Update existing null values to total_amount
        await db.execute(
          'UPDATE sales_order SET allocated_amount = total_amount WHERE allocated_amount IS NULL AND total_amount IS NOT NULL',
        );
      }
    } catch (e) {
      // Ignore migration errors
    }
  }

  Future<List<OrderModel>> getOrders() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    final rows = await db.query('sales_order', orderBy: 'created_date DESC');

    return rows.map((row) => OrderModel.fromSqlite(row)).toList();
  }

  Future<OrderModel?> getOrderById(int orderId) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    final rows = await db.query(
      'sales_order',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    if (rows.isEmpty) return null;

    return OrderModel.fromSqlite(rows.first);
  }

  Future<List<CartItem>> getOrderItems(int orderId) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    final rows = await db.query(
      'sales_order_details',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    return rows.map((row) {
      // This is a simplified mapping - in a real app you'd need to join with product tables
      return CartItem(
        productDisplay: 'Product ${row['product_id']}', // Placeholder
        productId: row['product_id'] as int,
        productBaseId: null,
        unitId: null,
        unitCount: 1.0,
        selectedUnitDisplay: 'PCS', // Placeholder
        quantity: row['ordered_quantity'] as int,
        price: row['unit_price'] as double,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> getCallsheetData(String customerCode) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    // 1. Get last 8 order dates
    final dateRows = await db.rawQuery(
      '''
      SELECT DISTINCT substr(created_date, 1, 10) as day 
      FROM sales_order 
      WHERE customer_code = ? 
      ORDER BY created_date DESC 
      LIMIT 8
    ''',
      [customerCode],
    );

    final List<String> dates = dateRows.map((r) => r['day'] as String).toList();

    if (dates.isEmpty) {
      return {'dates': <String>[], 'products': <Map<String, dynamic>>[]};
    }

    // 2. Get product history
    final placeHolders = List.filled(dates.length, '?').join(',');
    final query =
        '''
      SELECT 
        d.product_id, 
        p.product_name, 
        p.price_per_unit, 
        substr(s.created_date, 1, 10) as day, 
        SUM(d.ordered_quantity) as qty
      FROM sales_order_details d
      JOIN sales_order s ON d.order_id = s.order_id
      JOIN product p ON d.product_id = p.product_id
      WHERE s.customer_code = ? 
        AND day IN ($placeHolders)
      GROUP BY d.product_id, day
    ''';

    final rows = await db.rawQuery(query, [customerCode, ...dates]);

    // 3. Process into structure
    final Map<int, Map<String, dynamic>> productMap = {};

    for (final row in rows) {
      final pid = row['product_id'] as int;
      final day = row['day'] as String;
      final qty = (row['qty'] as num).toDouble();
      final name = (row['product_name'] ?? '').toString();
      final price = (row['price_per_unit'] as num?)?.toDouble() ?? 0.0;

      if (!productMap.containsKey(pid)) {
        productMap[pid] = {
          'id': pid,
          'name': name,
          'price': price,
          'history': <String, double>{},
        };
      }
      (productMap[pid]!['history'] as Map<String, double>)[day] = qty;
    }

    return {'dates': dates, 'products': productMap.values.toList()};
  }

  Future<void> saveCallsheetAttachment({
    required int? salesmanId,
    required String customerCode,
    required String attachmentName,
    required String salesOrderNo,
    required int createdBy,
  }) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    // 1. Ensure table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_order_attachment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salesman_id INTEGER,
        created_by INTEGER,
        customer_code TEXT,
        attachment_name TEXT,
        sales_order_no TEXT,
        created_date TEXT,
        is_synced INTEGER DEFAULT 0,
        file_id TEXT
      )
    ''');

    // 2. Migration: Ensure all columns exist (in case table was created with fewer columns)
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(sales_order_attachment)',
      );
      final existingColumns = columns.map((c) => c['name'] as String).toSet();

      if (!existingColumns.contains('salesman_id')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN salesman_id INTEGER',
        );
      }
      if (!existingColumns.contains('customer_code')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN customer_code TEXT',
        );
      }
      if (!existingColumns.contains('attachment_name')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN attachment_name TEXT',
        );
      }
      if (!existingColumns.contains('sales_order_no')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN sales_order_no TEXT',
        );
      }
      if (!existingColumns.contains('created_by')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN created_by INTEGER',
        );
      }
      if (!existingColumns.contains('created_date')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN created_date TEXT',
        );
      }
      if (!existingColumns.contains('is_synced')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN is_synced INTEGER DEFAULT 0',
        );
      }
      if (!existingColumns.contains('file_id')) {
        await db.execute(
          'ALTER TABLE sales_order_attachment ADD COLUMN file_id TEXT',
        );
      }
    } catch (e) {
      // Ignore errors if columns already exist or other harmless SQL issues
      // logging might be useful but sticking to silent resilience for now
    }

    // 3. Insert Record
    await db.insert('sales_order_attachment', {
      'salesman_id': salesmanId,
      'created_by': createdBy,
      'customer_code': customerCode,
      'attachment_name': attachmentName,
      'sales_order_no': salesOrderNo,
      'created_date': DateTime.now().toIso8601String(),
      'is_synced': 0, // Explicitly set unsynced
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttachments() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    // Ensure table exists (in case getUnsynced called before save)
    // Actually safe to just query, if not exists it throws, but we usually ensure creation on save.
    // For safety, we can wrap in try catch or ensure creation here too, but lazy approach:
    try {
      return await db.query(
        'sales_order_attachment',
        where: 'is_synced = 0 OR is_synced IS NULL',
      );
    } catch (e) {
      return []; // Table might not exist yet
    }
  }

  Future<void> markAttachmentAsSynced(int id, {String? fileId}) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    final Map<String, dynamic> updates = {'is_synced': 1};
    if (fileId != null) {
      updates['file_id'] = fileId;
    }

    await db.update(
      'sales_order_attachment',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
