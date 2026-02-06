class CartItem {
  final String productDisplay;
  final int productId;
  final int? productBaseId;
  final int? unitId;
  final double unitCount;
  final String selectedUnitDisplay;
  final int quantity;
  final double price;

  const CartItem({
    required this.productDisplay,
    required this.productId,
    this.productBaseId,
    this.unitId,
    required this.unitCount,
    required this.selectedUnitDisplay,
    required this.quantity,
    required this.price,
    this.originalPrice,
    this.discountAmount = 0.0,
    this.discountTypeId,
    this.discountName,
  });

  final double? originalPrice;
  final double discountAmount;
  final int? discountTypeId;
  final String? discountName;

  double get total => price * quantity;

  CartItem copyWith({
    String? productDisplay,
    int? productId,
    int? productBaseId,
    int? unitId,
    double? unitCount,
    String? selectedUnitDisplay,
    int? quantity,
    double? price,
    double? originalPrice,
    double? discountAmount,
    int? discountTypeId,
    String? discountName,
  }) {
    return CartItem(
      productDisplay: productDisplay ?? this.productDisplay,
      productId: productId ?? this.productId,
      productBaseId: productBaseId ?? this.productBaseId,
      unitId: unitId ?? this.unitId,
      unitCount: unitCount ?? this.unitCount,
      selectedUnitDisplay: selectedUnitDisplay ?? this.selectedUnitDisplay,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      discountTypeId: discountTypeId ?? this.discountTypeId,
      discountName: discountName ?? this.discountName,
    );
  }
}
