class DiscountType {
  final int id;
  final String discountType;

  DiscountType({required this.id, required this.discountType});

  factory DiscountType.fromMap(Map<String, dynamic> map) {
    return DiscountType(
      id: (map['id'] as num?)?.toInt() ?? 0,
      discountType: map['discount_type'] as String? ?? '',
    );
  }
}

class LineDiscount {
  final int id;
  final String lineDiscount;
  final double percentage;

  LineDiscount({
    required this.id,
    required this.lineDiscount,
    required this.percentage,
  });

  factory LineDiscount.fromMap(Map<String, dynamic> map) {
    return LineDiscount(
      id: (map['id'] as num?)?.toInt() ?? 0,
      lineDiscount: map['line_discount'] as String? ?? '',
      percentage: double.tryParse(map['percentage']?.toString() ?? '') ?? 0.0,
    );
  }
}

class LinePerDiscountType {
  final int id;
  final int typeId;
  final int lineId;

  LinePerDiscountType({
    required this.id,
    required this.typeId,
    required this.lineId,
  });

  factory LinePerDiscountType.fromMap(Map<String, dynamic> map) {
    return LinePerDiscountType(
      id: (map['id'] as num?)?.toInt() ?? 0,
      typeId: (map['type_id'] as num?)?.toInt() ?? 0,
      lineId: (map['line_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupplierCategoryDiscountPerCustomer {
  final int id;
  final String customerCode;
  final int discountType;
  final int supplierId;
  final int? categoryId;

  SupplierCategoryDiscountPerCustomer({
    required this.id,
    required this.customerCode,
    required this.discountType,
    required this.supplierId,
    this.categoryId,
  });

  factory SupplierCategoryDiscountPerCustomer.fromMap(
    Map<String, dynamic> map,
  ) {
    return SupplierCategoryDiscountPerCustomer(
      id: (map['id'] as num?)?.toInt() ?? 0,
      customerCode: map['customer_code'] as String? ?? '',
      discountType: (map['discount_type'] as num?)?.toInt() ?? 0,
      supplierId: (map['supplier_id'] as num?)?.toInt() ?? 0,
      categoryId: (map['category_id'] as num?)?.toInt(),
    );
  }
}

class ProductPerCustomer {
  final int id;
  final String customerCode;
  final int productId;
  final int? discountType;
  final double unitPrice;
  final String dateAdded;

  ProductPerCustomer({
    required this.id,
    required this.customerCode,
    required this.productId,
    this.discountType,
    required this.unitPrice,
    required this.dateAdded,
  });

  factory ProductPerCustomer.fromMap(Map<String, dynamic> map) {
    return ProductPerCustomer(
      id: (map['id'] as num?)?.toInt() ?? 0,
      customerCode: map['customer_code'] as String? ?? '',
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      discountType: (map['discount_type'] as num?)?.toInt(),
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '') ?? 0.0,
      dateAdded: map['date_added'] as String? ?? '',
    );
  }
}

class ProductPerSupplier {
  final int id;
  final int productId;
  final int supplierId;
  final int discountType;

  ProductPerSupplier({
    required this.id,
    required this.productId,
    required this.supplierId,
    required this.discountType,
  });

  factory ProductPerSupplier.fromMap(Map<String, dynamic> map) {
    return ProductPerSupplier(
      id: (map['id'] as num?)?.toInt() ?? 0,
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      supplierId: (map['supplier_id'] as num?)?.toInt() ?? 0,
      discountType: (map['discount_type'] as num?)?.toInt() ?? 0,
    );
  }
}
