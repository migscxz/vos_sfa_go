import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';
import 'package:vos_sfa_go/core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/orders/data/models/cart_item_model.dart';

import '../../../data/models/order_model.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.orderTemplate,
    required this.initialItems,
  });

  final OrderModel orderTemplate;
  final List<CartItem> initialItems;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late List<CartItem> _items;
  bool _isSaving = false;

  double get _grandTotal => _items.fold(0.0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _updateQuantity(int index, int newQty) {
    if (newQty < 1) return;
    setState(() {
      final old = _items[index];
      _items[index] = old.copyWith(quantity: newQty);
    });
  }

  void _itemsDelete(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _processCheckout() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      Navigator.pop(context); // Go back to add items
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

      // Verify tables exist (same logic as OrderFormPage)
      await _ensureSalesTablesExist(db);

      // Prepare final order model
      final now = DateTime.now();
      final finalOrder = OrderModel(
        orderNo: widget.orderTemplate.orderNo,
        poNo: widget.orderTemplate.poNo,
        customerName: widget.orderTemplate.customerName,
        customerCode: widget.orderTemplate.customerCode,
        salesmanId: widget.orderTemplate.salesmanId,
        supplierId: widget.orderTemplate.supplierId,
        orderDate: widget.orderTemplate.orderDate,
        createdAt: widget.orderTemplate.createdAt,
        totalAmount: _grandTotal,
        netAmount: _grandTotal,
        status: 'For Approval', // ✅ Set status
        forApprovalAt: now.toIso8601String(), // ✅ Set approval date
        type: widget.orderTemplate.type,
        supplier: widget.orderTemplate.supplier,
        priceType: widget.orderTemplate.priceType,
        hasAttachment: widget.orderTemplate.hasAttachment,
        callsheetImagePath: widget.orderTemplate.callsheetImagePath,
        remarks: widget.orderTemplate.remarks,
        // The following fields are primarily for single-line-item orders in some views,
        // but for multi-line orders they might be ambiguous. We'll leave them if they were set.
        product: widget.orderTemplate.product,
        productId: widget.orderTemplate.productId,
        productBaseId: widget.orderTemplate.productBaseId,
        unitId: widget.orderTemplate.unitId,
        unitCount: widget.orderTemplate.unitCount,
        quantity: _items
            .length, // Or sum? Usually header qty is line count or total units.
      );

      // Insert Header
      final headerRow = finalOrder.toSqlite();
      headerRow.remove('id'); // let auto-increment work

      // Remove UI-only fields that might not exist in the table (matching OrderFormPage legacy logic)
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

      final orderId = await db.insert('sales_order', headerRow);

      // Insert Details
      final batch = db.batch();
      for (final item in _items) {
        batch.insert('sales_order_details', {
          'order_id': orderId,
          'product_id': item.productId,
          'unit_price': item.price,
          'ordered_quantity': item.quantity,
          'allocated_quantity': 0,
          'served_quantity': 0,
          'discount_type': 0,
          'discount_amount': 0,
          'gross_amount': item.total,
          'net_amount': item.total,
          'allocated_amount': 0,
          'remarks': '',
          'created_date': now.toIso8601String(),
          'modified_date': now.toIso8601String(),
        });
      }
      await batch.commit(noResult: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved successfully!')),
        );
        // Pop back to list or home?
        // Usually, we want to pop twice (Checkout -> OrderForm -> Home/List)
        // OR just pop with a result.
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error saving order: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- DUPLICATED HELPERS (TO AVOID BREAKING CHANGES) ---
  // Ideally this should be in a repo.
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

    // Migration checks (simplified)
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
    } catch (e) {
      debugPrint('Error migrating sales_order table: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.selectedUnitDisplay} • ${currency.format(item.price)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            // Quantity Controls
                            Row(
                              children: [
                                _QuantityButton(
                                  icon: Icons.remove,
                                  onTap: () =>
                                      _updateQuantity(index, item.quantity - 1),
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                  ),
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _QuantityButton(
                                  icon: Icons.add,
                                  onTap: () =>
                                      _updateQuantity(index, item.quantity + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Total & Delete
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(item.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _itemsDelete(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Bottom Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        currency.format(_grandTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _processCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirm Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}
