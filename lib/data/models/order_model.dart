// lib/data/models/order_model.dart

// Define the Enum
enum OrderType { manual, callsheet }

extension OrderTypeDb on OrderType {
  String get dbValue => this == OrderType.callsheet ? 'callsheet' : 'manual';

  static OrderType fromDb(String? v) {
    if (v == null) return OrderType.manual;
    final x = v.toLowerCase().trim();
    return x == 'callsheet' ? OrderType.callsheet : OrderType.manual;
  }
}

class OrderModel {
  final int? id; // Local/SQLite ID (if you store to your own table)
  final int? orderId; // Server ID (from API)

  // Business fields
  final String orderNo; // System SO Number
  final String? poNo; // Customer PO Number
  final String customerName;
  final String? customerCode;
  final int? salesmanId;
  final int? supplierId;
  final DateTime orderDate;
  final String? deliveryDate;
  final String? paymentTerms;
  final String? remarks;
  final DateTime createdAt;
  final double totalAmount;
  final double? discountAmount;
  final double netAmount;
  final String status;
  final int isSynced; // 0 = false, 1 = true

  // UI fields
  final OrderType type;
  final String? supplier; // display name

  /// IMPORTANT:
  /// This should now store the DISPLAY string (variant) from dropdown,
  /// e.g. "Richeese Wafer 24g x 20ib x 10pcs (BOX x10)"
  final String? product;

  /// Variant Product ID (child row if applicable).
  /// Example: parent_id = 22172 (base), product_id = 22174 (BOX variant) → store 22174 here.
  final int? productId;

  /// Base Product ID (parent). If selected product has parent_id, this is that parent_id.
  /// If selected product is itself the parent, this equals productId (or can be null if unknown).
  final int? productBaseId;

  /// From product.unit_of_measurement
  final int? unitId;

  /// From product.unit_of_measurement_count (e.g. 10 for BOX x10)
  final double? unitCount;

  final String? priceType;
  final int? quantity;

  final bool hasAttachment;

  /// Store local path (optional, but very useful for callsheet orders)
  final String? callsheetImagePath;

  OrderModel({
    this.id,
    this.orderId,
    required this.orderNo,
    this.poNo,
    required this.customerName,
    this.customerCode,
    this.salesmanId,
    this.supplierId,
    required this.orderDate,
    this.deliveryDate,
    this.paymentTerms,
    this.remarks,
    required this.createdAt,
    required this.totalAmount,
    this.discountAmount,
    required this.netAmount,
    required this.status,
    this.isSynced = 0,

    this.type = OrderType.manual,
    this.supplier,

    this.product,
    this.productId,
    this.productBaseId,
    this.unitId,
    this.unitCount,

    this.priceType,
    this.quantity,
    this.hasAttachment = false,
    this.callsheetImagePath,
  });

  // --- Helpers (optional but useful) ---
  bool get isCallsheet => type == OrderType.callsheet;

  // Map from SQLite
  // NOTE: This is only accurate if you are mapping from your OWN local table.
  // If you are mapping from `sales_order`, those columns will not exist (and that’s okay).
  factory OrderModel.fromSqlite(Map<String, dynamic> map) {
    return OrderModel(
      id: (map['id'] as num?)?.toInt() ?? (map['order_id'] as num?)?.toInt(),
      orderId: (map['order_id'] as num?)?.toInt(), // Server ID if present

      orderNo: (map['order_no'] ?? '').toString(),
      poNo: map['po_no']?.toString(),

      // Prefer explicit name if present; otherwise fallback to code.
      customerName: (map['customer_name'] ?? map['customer_code'] ?? 'Unknown').toString(),
      customerCode: map['customer_code']?.toString(),
      salesmanId: (map['salesman_id'] as num?)?.toInt(),
      supplierId: (map['supplier_id'] as num?)?.toInt(),

      orderDate: DateTime.tryParse((map['order_date'] ?? '').toString()) ?? DateTime.now(),
      deliveryDate: map['delivery_date']?.toString(),
      paymentTerms: map['payment_terms']?.toString(),
      remarks: map['remarks']?.toString(),

      createdAt:
          DateTime.tryParse((map['created_date'] ?? map['created_at'] ?? '').toString()) ??
          DateTime.now(),

      totalAmount:
          (map['total_amount'] as num?)?.toDouble() ??
          (map['net_amount'] as num?)?.toDouble() ??
          0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0.0,

      status: (map['order_status'] ?? map['status'] ?? 'Pending').toString(),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,

      type: OrderTypeDb.fromDb(map['order_type']?.toString()),

      supplier: map['supplier']?.toString(),

      product: map['product']?.toString(),
      productId: (map['product_id'] as num?)?.toInt(),
      productBaseId: (map['product_base_id'] as num?)?.toInt(),
      unitId: (map['unit_id'] as num?)?.toInt(),
      unitCount: (map['unit_count'] as num?)?.toDouble(),

      priceType: map['price_type']?.toString(),
      quantity: (map['quantity'] as num?)?.toInt(),

      hasAttachment: ((map['has_attachment'] as num?)?.toInt() ?? 0) == 1,
      callsheetImagePath: map['callsheet_image_path']?.toString(),
    );
  }

  // Map to SQLite
  // NOTE: If you insert into `sales_order`, it won’t have these extra columns.
  // For best practice, store UI orders to a separate local table (recommended).
  Map<String, dynamic> toSqlite() {
    return {
      // 'id': id, // Auto-increment, usually don't insert explicitly unless syncing
      'order_id': orderId,

      'order_no': orderNo,
      'po_no': poNo,
      'customer_name': customerName,
      'customer_code': customerCode,
      'salesman_id': salesmanId,
      'supplier_id': supplierId,
      'order_date': orderDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      'delivery_date': deliveryDate,
      'payment_terms': paymentTerms,
      'remarks': remarks,

      'created_date': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'net_amount': netAmount,
      'order_status': status,
      'is_synced': isSynced,

      'order_type': type.dbValue,

      'supplier': supplier,

      'product': product,
      'product_id': productId,
      'product_base_id': productBaseId,
      'unit_id': unitId,
      'unit_count': unitCount,

      'price_type': priceType,
      'quantity': quantity,

      'has_attachment': hasAttachment ? 1 : 0,
      'callsheet_image_path': callsheetImagePath,
    };
  }
}
