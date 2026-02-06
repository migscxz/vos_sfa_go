import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_manager.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/models/product_model.dart'; // Needed for Product.getPrice
import '../../../../data/models/discount_models.dart';
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
        // Store BASE price if available, else Net
        'unit_price': item.originalPrice ?? item.price,
        'ordered_quantity': item.quantity,
        // Gross = Base * Qty
        'gross_amount': (item.originalPrice ?? item.price) * item.quantity,
        'net_amount': item.total, // Net * Qty
        // Discount Amount (Total for this line)
        'discount_amount': item.quantity * item.discountAmount,
        'discount_type': item.discountTypeId, // ID
        'allocated_quantity': item.quantity, // Auto-allocate on creation
        'served_quantity': 0, // Not served yet
        'allocated_amount': item.total, // Net amount
        'created_date': order.createdAt.toIso8601String(),
        'remarks': '',
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

      // Check sales_order_details columns
      final List<Map<String, dynamic>> detailCols = await db.rawQuery(
        'PRAGMA table_info(sales_order_details)',
      );
      final existingDetailCols = detailCols
          .map((c) => c['name'] as String)
          .toSet();

      final missingDetailCols = {
        'discount_type': 'REAL',
        'discount_amount': 'REAL',
        'allocated_quantity': 'INTEGER',
        'served_quantity': 'INTEGER',
        'allocated_amount': 'REAL',
        'gross_amount': 'REAL',
        'net_amount': 'REAL',
      };

      for (final entry in missingDetailCols.entries) {
        if (!existingDetailCols.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE sales_order_details ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
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

  Future<Map<String, dynamic>> getCallsheetData(
    String customerCode, {
    int limit = 7,
    int offset = 0,
  }) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    // 1. Get last N limit order dates with offset
    final dateRows = await db.rawQuery(
      '''
      SELECT DISTINCT substr(created_date, 1, 10) as day 
      FROM sales_order 
      WHERE customer_code = ? 
      ORDER BY created_date DESC 
      LIMIT ? OFFSET ?
    ''',
      [customerCode, limit, offset],
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
        p.description,
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
      final description = (row['description'] ?? '').toString();
      // Use description if available, else name
      final display = description.isNotEmpty ? description : name;

      final price = (row['price_per_unit'] as num?)?.toDouble() ?? 0.0;

      if (!productMap.containsKey(pid)) {
        productMap[pid] = {
          'id': pid,
          'name': display,
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

  Future<List<Map<String, dynamic>>> getPendingCallsheetsByCustomer(
    String customerCode,
  ) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    // Ensure table exists just in case
    try {
      final result = await db.query(
        'sales_order_attachment',
        where: 'customer_code = ? AND (is_synced = 0 OR is_synced IS NULL)',
        whereArgs: [customerCode],
        orderBy: 'created_date DESC',
      );
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteCallsheetAttachment(int id) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
    await db.delete('sales_order_attachment', where: 'id = ?', whereArgs: [id]);
  }

  // --- PRICE & DISCOUNT LOGIC ---

  Future<PriceCalculationResult> calculateProductPrice({
    required Product product,
    required String customerCode,
    required int supplierId,
    required String priceType, // from Customer or Salesman
  }) async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    double basePrice = 0.0;
    int? discountTypeId;
    String discountName = "";

    // Step A: Determine Base Price & Check for Product-Customer Override
    // -------------------------------------------------------------
    // Priority 1: Check product_per_customer
    final List<Map<String, dynamic>> ppcRows = await db.query(
      'product_per_customer',
      where: 'customer_code = ? AND product_id = ?',
      whereArgs: [customerCode, product.id],
    );

    ProductPerCustomer? ppc;
    if (ppcRows.isNotEmpty) {
      ppc = ProductPerCustomer.fromMap(ppcRows.first);
    }

    // Logic: If unit_price > 0 in Override, use it. Else use standard list price.
    if (ppc != null && ppc.unitPrice > 0) {
      basePrice = ppc.unitPrice;
    } else {
      basePrice = product.getPrice(priceType);
    }

    // Step B: Determine Discount Scheme (Priority Order)
    // -------------------------------------------------------------

    // 1. Product-Customer Specific
    if (ppc != null && ppc.discountType != null) {
      discountTypeId = ppc.discountType;
    }

    // 2. Supplier-Category-Customer Specific (if not found yet)
    if (discountTypeId == null) {
      // Note: We might need product category_id here.
      // Assuming 0 or null for now if not strictly enforced, asking DB.
      // Or query strictly by customer + supplier.
      // The schema has category_id. We'll try to match exact first.
      // For now, let's query broad matches for this customer+supplier
      final List<Map<String, dynamic>> scdRows = await db.query(
        'supplier_category_discount_per_customer',
        where: 'customer_code = ? AND supplier_id = ?',
        whereArgs: [customerCode, supplierId],
      );

      if (scdRows.isNotEmpty) {
        // Filter in memory if we need strict category matching
        // For simple logic, take the first one or match category if product has it.
        // Assuming product.product_category match.
        // If product.product_category is int.
        // Let's iterate
        for (var row in scdRows) {
          final scd = SupplierCategoryDiscountPerCustomer.fromMap(row);
          if (scd.categoryId == null ||
              scd.categoryId == 0 ||
              scd.categoryId == product.productCategory) {
            discountTypeId = scd.discountType;
            break;
          }
        }
      }
    }

    // 3. Product-Supplier Specific (if not found yet)
    if (discountTypeId == null) {
      // product_per_supplier
      final List<Map<String, dynamic>> ppsRows = await db.query(
        'product_per_supplier',
        where: 'product_id = ? AND supplier_id = ?',
        whereArgs: [product.id, supplierId],
      );
      if (ppsRows.isNotEmpty) {
        final pps = ProductPerSupplier.fromMap(ppsRows.first);
        discountTypeId = pps.discountType;
      }
    }

    // 4. Global Customer Discount (if not found yet)
    if (discountTypeId == null) {
      // We need to fetch customer discount_type string "L7/L2" and find its ID in discount_type table?
      // The customer table has `discount_type` text column (e.g. "L7/L2") OR is it an ID?
      // User Request sample: "discount_type": "L7/L2" (id 125).
      // Customer table sample: "discount_type": null (TEXT).
      // We need to resolve the TEXT "L7/L2" to `discount_type.id`.
      // OR maybe `discount_type` column in customer IS the ID?
      // Schema says `discount_type TEXT` in customer table.
      // But `discount_type` TABLE has `id` and `discount_type` (name).
      // So likely customer stores the NAME "L7/L2". We need to find ID where name = "L7/L2".

      final List<Map<String, dynamic>> custRows = await db.query(
        'customer',
        columns: ['discount_type'],
        where: 'customer_code = ?',
        whereArgs: [customerCode],
      );

      if (custRows.isNotEmpty && custRows.first['discount_type'] != null) {
        final String? dTypeStr = custRows.first['discount_type']?.toString();
        if (dTypeStr != null && dTypeStr.isNotEmpty) {
          // Find ID in discount_type table
          final List<Map<String, dynamic>> dtRows = await db.query(
            'discount_type',
            where: 'discount_type = ?',
            whereArgs: [dTypeStr],
          );
          if (dtRows.isNotEmpty) {
            discountTypeId = (dtRows.first['id'] as num?)?.toInt();
          }
        }
      }
    }

    // Step C: Calculate Net Amount
    // -------------------------------------------------------------
    double netPrice = basePrice;
    double totalDiscountAmount = 0.0;

    if (discountTypeId != null) {
      // Fetch name for completeness
      if (discountName.isEmpty) {
        final List<Map<String, dynamic>> dtRows = await db.query(
          'discount_type',
          where: 'id = ?',
          whereArgs: [discountTypeId],
        );
        if (dtRows.isNotEmpty) {
          discountName = dtRows.first['discount_type'] as String? ?? '';
        }
      }

      // Fetch components: line_per_discount_type -> line_discount
      // Join query would be nicer but let's do split queries for safety/compat
      final List<Map<String, dynamic>> lineLinks = await db.query(
        'line_per_discount_type',
        where: 'type_id = ?',
        whereArgs: [discountTypeId],
      );

      for (var link in lineLinks) {
        final lineId = (link['line_id'] as num?)?.toInt() ?? 0;
        final List<Map<String, dynamic>> lineRows = await db.query(
          'line_discount',
          where: 'id = ?',
          whereArgs: [lineId],
        );

        if (lineRows.isNotEmpty) {
          final line = LineDiscount.fromMap(lineRows.first);
          // Assuming CHAIN discount.
          // Percentage: If stored as 1.0 (mean 1%) -> divide by 100.
          // If stored as 0.01 (mean 1%) -> use as is.
          // User sample: "1.0000" for "L1". Most likely means 1%.
          // "7.0000" for "L7".
          // So we divide by 100.
          double factor = line.percentage / 100.0;
          netPrice = netPrice * (1.0 - factor);
        }
      }
    }

    totalDiscountAmount = basePrice - netPrice;

    return PriceCalculationResult(
      basePrice: basePrice,
      netPrice: netPrice,
      discountTypeId: discountTypeId,
      discountAmount: totalDiscountAmount,
      discountName: discountName,
    );
  }
}

class PriceCalculationResult {
  final double basePrice;
  final double netPrice;
  final int? discountTypeId;
  final double discountAmount;
  final String discountName;

  PriceCalculationResult({
    required this.basePrice,
    required this.netPrice,
    this.discountTypeId,
    required this.discountAmount,
    this.discountName = '',
  });
}
