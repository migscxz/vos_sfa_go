import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_manager.dart';
import '../../../../data/models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderRepository {
  Future<void> saveOrder(OrderModel order, List<CartItem> cartItems) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    // Ensure tables exist
    await _ensureSalesTablesExist(db);

    // Insert Header
    final headerRow = order.toSqlite();
    headerRow.remove('id');
    headerRow.remove('customer_name');
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
}
