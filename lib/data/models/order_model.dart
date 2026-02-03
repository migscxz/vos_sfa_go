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

  // Business fields
  final String orderNo; // PO Number
  final String customerName;
  final String? customerCode;
  final DateTime createdAt;
  final double totalAmount;
  final String status;

  // UI fields
  final OrderType type;
  final String? supplier; // display name (optional)
  final int? supplierId; // optional (recommended if you will post later)

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
    required this.orderNo,
    required this.customerName,
    this.customerCode,
    required this.createdAt,
    required this.totalAmount,
    required this.status,

    this.type = OrderType.manual,
    this.supplier,
    this.supplierId,

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

      orderNo: (map['order_no'] ?? '').toString(),

      // Prefer explicit name if present; otherwise fallback to code.
      customerName: (map['customer_name'] ?? map['customer_code'] ?? 'Unknown').toString(),

      customerCode: map['customer_code']?.toString(),

      createdAt:
          DateTime.tryParse((map['created_date'] ?? map['created_at'] ?? '').toString()) ??
          DateTime.now(),

      totalAmount:
          (map['total_amount'] as num?)?.toDouble() ??
          (map['net_amount'] as num?)?.toDouble() ??
          0.0,

      status: (map['order_status'] ?? map['status'] ?? 'Pending').toString(),

      type: OrderTypeDb.fromDb(map['order_type']?.toString()),

      supplier: map['supplier']?.toString(),
      supplierId: (map['supplier_id'] as num?)?.toInt(),

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
      'id': id,

      'order_no': orderNo,
      'customer_name': customerName,
      'customer_code': customerCode,

      'created_date': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'order_status': status,

      'order_type': type.dbValue,

      'supplier': supplier,
      'supplier_id': supplierId,

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
