class Product {
  final int id;
  final String name;
  final String code;
  final String description;
  final String uom; // label derived from ID or fallback
  final double uomCount;

  // Prices
  final double pricePerUnit;
  final double costPerUnit;
  final double priceA;
  final double priceB;
  final double priceC;
  final double priceD;
  final double priceE;

  final int? unitId;
  final int? parentId;

  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    this.unitId,
    this.parentId,
    this.uom = '',
    this.uomCount = 1.0,
    this.pricePerUnit = 0.0,
    this.costPerUnit = 0.0,
    this.priceA = 0.0,
    this.priceB = 0.0,
    this.priceC = 0.0,
    this.priceD = 0.0,
    this.priceE = 0.0,
  });

  /// Helper to get effective price based on type
  double getPrice(String priceType) {
    // Determine price based on your business logic mapping
    // example: "Retail" -> priceA (or price_per_unit)
    // "Wholesale" -> priceB
    switch (priceType.toLowerCase()) {
      case 'retail':
      case 'pricea':
      case 'a':
        return priceA > 0 ? priceA : pricePerUnit;
      case 'wholesale':
      case 'priceb':
      case 'b':
        return priceB > 0 ? priceB : pricePerUnit; // Fallback
      case 'promo':
      case 'pricec':
      case 'c':
        return priceC > 0 ? priceC : pricePerUnit; // Fallback
      case 'priced':
      case 'd':
        return priceD > 0 ? priceD : pricePerUnit;
      case 'pricee':
      case 'e':
        return priceE > 0 ? priceE : pricePerUnit;
      default:
        // Fallback to standard price_per_unit
        if (priceType.toLowerCase().contains('b')) return priceB;
        if (priceType.toLowerCase().contains('c')) return priceC;
        if (priceType.toLowerCase().contains('d')) return priceD;
        if (priceType.toLowerCase().contains('e')) return priceE;
        return priceA > 0 ? priceA : pricePerUnit;
    }
  }

  factory Product.fromMap(Map<String, dynamic> map, {String uomLabel = ''}) {
    final uomId = (map['unit_of_measurement'] is num)
        ? (map['unit_of_measurement'] as num).toInt()
        : null;
    final pId = (map['parent_id'] is num)
        ? (map['parent_id'] as num).toInt()
        : null;

    return Product(
      id: (map['product_id'] ?? 0) as int,
      name: (map['product_name'] ?? '').toString(),
      code: (map['product_code'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      unitId: uomId,
      parentId: pId,
      uom: uomLabel,
      uomCount: (map['unit_of_measurement_count'] is num)
          ? (map['unit_of_measurement_count'] as num).toDouble()
          : 1.0,
      pricePerUnit: (map['price_per_unit'] is num)
          ? (map['price_per_unit'] as num).toDouble()
          : 0.0,
      costPerUnit: (map['cost_per_unit'] is num)
          ? (map['cost_per_unit'] as num).toDouble()
          : 0.0,
      priceA: (map['priceA'] is num) ? (map['priceA'] as num).toDouble() : 0.0,
      priceB: (map['priceB'] is num) ? (map['priceB'] as num).toDouble() : 0.0,
      priceC: (map['priceC'] is num) ? (map['priceC'] as num).toDouble() : 0.0,
      priceD: (map['priceD'] is num) ? (map['priceD'] as num).toDouble() : 0.0,
      priceE: (map['priceE'] is num) ? (map['priceE'] as num).toDouble() : 0.0,
    );
  }
}
