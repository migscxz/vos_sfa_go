import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/global_remote_api.dart';
import '../../../core/database/database_manager.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/order_line_item.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../data/models/cart_item_model.dart';
import '../data/repositories/order_repository.dart';

class _ProductVariantMeta {
  final int productId;
  final int? baseId;
  final int? unitId;
  final double unitCount;

  const _ProductVariantMeta({
    required this.productId,
    required this.baseId,
    required this.unitId,
    required this.unitCount,
  });
}

class OrderController extends ChangeNotifier {
  final OrderRepository _repository;
  final GlobalRemoteApi _remoteApi = GlobalRemoteApi();

  OrderController(this._repository);

  // State
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<String> _suppliers = [];
  Map<String, String> _supplierShortcuts = {};
  Map<String, int> _supplierIdByName = {};
  Map<int, String> _supplierNameById = {};
  List<String> _allProducts = [];
  Map<String, List<String>> _productsBySupplier = {};
  Map<String, int> _productIdByDisplay = {};
  Map<String, _ProductVariantMeta> _productMetaByDisplay = {};
  Map<int, String> _unitShortcutById = {};
  Map<int, String> _unitNameById = {};

  final List<CartItem> _cartItems = [];
  String? _selectedSupplier;
  String? _selectedProduct;
  String? _selectedPriceType;
  Customer? _selectedCustomer;

  // Getters
  bool get isLoading => _isLoading;
  List<Customer> get customers => _customers;
  List<String> get suppliers => _suppliers;
  List<String> get allProducts => _allProducts;
  Map<String, List<String>> get productsBySupplier => _productsBySupplier;
  List<CartItem> get cartItems => _cartItems;
  String? get selectedSupplier => _selectedSupplier;
  String? get selectedProduct => _selectedProduct;
  String? get selectedPriceType => _selectedPriceType;
  Customer? get selectedCustomer => _selectedCustomer;

  double get grandTotal => _cartItems.fold(0.0, (sum, item) => sum + item.total);

  List<String> get currentProducts {
    if (_selectedSupplier == null) return _allProducts;
    final list = _productsBySupplier[_selectedSupplier];
    if (list == null || list.isEmpty) return _allProducts;
    return list;
  }

  // Initialization
  Future<void> initialize(WidgetRef ref) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCustomersFromDb();
      await _loadSuppliersFromDb();
      await _loadProductsFromDb();

      // Set price type from salesman
      final authState = ref.read(authProvider);
      final salesman = authState.salesman;
      final String? salesmanPriceType = salesman?.priceType;

      if (salesmanPriceType != null && salesmanPriceType.isNotEmpty) {
        _selectedPriceType = salesmanPriceType;
      } else {
        _selectedPriceType = 'Retail'; // Default
      }
    } catch (e) {
      debugPrint('Error initializing order controller: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Customer operations
  Future<void> _loadCustomersFromDb() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

    final rows = await db.query(
      'customer',
      columns: ['id', 'customer_name', 'customer_code', 'isActive'],
    );

    final List<Customer> customers = [];

    for (final row in rows) {
      final name = (row['customer_name'] ?? '').toString();
      if (name.isEmpty) continue;

      final rawIsActive = row['isActive'];
      final isActiveInt = (rawIsActive is num) ? rawIsActive.toInt() : 1;
      if (isActiveInt != 1) continue;

      final rawId = row['id'];
      final id = (rawId is num) ? rawId.toInt() : null;
      if (id == null) continue;

      final code = (row['customer_code'] ?? '').toString();

      customers.add(Customer(id: id, name: name, code: code));
    }

    customers.sort((a, b) => a.name.compareTo(b.name));
    _customers = customers;
  }

  void selectCustomer(Customer customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  // Supplier operations
  Future<void> _loadSuppliersFromDb() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

    final rows = await db.query(
      'supplier',
      columns: ['id', 'supplier_name', 'supplier_shortcut', 'supplier_type', 'isActive'],
    );

    final List<String> names = [];
    final Map<String, String> shortcuts = {};
    final Map<String, int> idByName = {};
    final Map<int, String> nameById = {};

    for (final row in rows) {
      final name = (row['supplier_name'] ?? '').toString();
      if (name.isEmpty) continue;

      final type = ((row['supplier_type'] ?? '').toString()).toUpperCase();
      if (type != 'TRADE') continue;

      final rawIsActive = row['isActive'];
      final isActiveInt = (rawIsActive is num) ? rawIsActive.toInt() : 1;
      if (isActiveInt != 1) continue;

      final rawId = row['id'];
      final id = (rawId is num) ? rawId.toInt() : null;
      if (id == null) continue;

      names.add(name);
      idByName[name] = id;
      nameById[id] = name;

      final shortcut = (row['supplier_shortcut'] ?? '').toString();
      if (shortcut.isNotEmpty) shortcuts[name] = shortcut;
    }

    names.sort();

    _suppliers = names;
    _supplierShortcuts = shortcuts;
    _supplierIdByName = idByName;
    _supplierNameById = nameById;
  }

  void selectSupplier(String supplier) {
    _selectedSupplier = supplier;
    _selectedProduct = null;
    _generatePoNumber();
    notifyListeners();
  }

  // Product operations
  Future<void> _loadProductsFromDb() async {
    final dbSales = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

    await _seedUnitsIfEmpty(dbSales);

    final unitRows = await dbSales.query(
      'unit',
      columns: ['unit_id', 'unit_name', 'unit_shortcut', 'sort_order'],
      orderBy: 'COALESCE(sort_order, 999999) ASC, unit_shortcut ASC',
    );

    final unitShortcutById = <int, String>{};
    final unitNameById = <int, String>{};

    for (final r in unitRows) {
      final id = (r['unit_id'] as num?)?.toInt();
      if (id == null) continue;
      unitShortcutById[id] = (r['unit_shortcut'] ?? '').toString().trim();
      unitNameById[id] = (r['unit_name'] ?? '').toString().trim();
    }

    final productRows = await dbSales.query(
      'product',
      columns: [
        'product_id',
        'product_name',
        'description',
        'parent_id',
        'unit_of_measurement',
        'unit_of_measurement_count',
      ],
    );

    final ppsRows = await dbSales.query(
      'product_per_supplier',
      columns: ['product_id', 'supplier_id'],
    );

    final baseNameByBaseId = <int, String>{};
    for (final row in productRows) {
      final pid = (row['product_id'] as num?)?.toInt();
      if (pid == null) continue;
      final parentId = (row['parent_id'] as num?)?.toInt();
      if (parentId == null) {
        final name = (row['product_name'] ?? '').toString().trim();
        if (name.isNotEmpty) baseNameByBaseId[pid] = name;
      }
    }

    final baseIdByProductId = <int, int>{};
    for (final row in productRows) {
      final pid = (row['product_id'] as num?)?.toInt();
      if (pid == null) continue;
      final parentId = (row['parent_id'] as num?)?.toInt();
      baseIdByProductId[pid] = parentId ?? pid;
    }

    final productIdByDisplay = <String, int>{};
    final displayByProductId = <int, String>{};
    final productMetaByDisplay = <String, _ProductVariantMeta>{};
    final allDisplays = <String>[];
    final displaysByBaseId = <int, List<String>>{};

    for (final row in productRows) {
      final pid = (row['product_id'] as num?)?.toInt();
      if (pid == null) continue;

      final parentId = (row['parent_id'] as num?)?.toInt();
      final baseId = parentId ?? pid;

      final baseName = baseNameByBaseId[baseId] ?? (row['product_name'] ?? '').toString().trim();
      if (baseName.isEmpty) continue;

      final uomId = (row['unit_of_measurement'] as num?)?.toInt();
      var count = (row['unit_of_measurement_count'] as num?)?.toDouble() ?? 1.0;

      final desc = (row['description'] ?? '').toString().trim();
      final pname = (row['product_name'] ?? '').toString().trim();

      var uom = (uomId != null)
          ? _uomLabelFromMaps(uomId, unitShortcutById, unitNameById)
          : _uomLabelFromDescription(desc, unitShortcutById, unitNameById);

      if (uom.toUpperCase() == 'UOM') {
        uom = _uomFallbackFromText('$pname $desc');
      }

      if (count <= 1) {
        final inferred1 = _inferCountFromText(pname);
        if (inferred1 > 1) {
          count = inferred1;
        } else {
          final inferred2 = _inferCountFromText(desc);
          if (inferred2 > 1) count = inferred2;
        }
      }

      final uomUpper = uom.trim().toUpperCase();
      final String variantLabel;
      if (count > 1) {
        final countText = (count % 1 == 0) ? count.toInt().toString() : count.toString();

        if (RegExp(r'\bPCS\b').hasMatch(uomUpper)) {
          variantLabel = '$countText PCS';
        } else {
          variantLabel = '$uom x$countText';
        }
      } else {
        variantLabel = uom;
      }

      final display = '$baseName ($variantLabel)';

      var safeDisplay = display;
      if (productIdByDisplay.containsKey(safeDisplay)) {
        safeDisplay = '$display #$pid';
      }

      productIdByDisplay[safeDisplay] = pid;
      displayByProductId[pid] = safeDisplay;

      productMetaByDisplay[safeDisplay] = _ProductVariantMeta(
        productId: pid,
        baseId: baseId,
        unitId: uomId,
        unitCount: count,
      );

      allDisplays.add(safeDisplay);

      displaysByBaseId.putIfAbsent(baseId, () => []);
      displaysByBaseId[baseId]!.add(safeDisplay);
    }

    allDisplays.sort();
    for (final e in displaysByBaseId.entries) {
      e.value.sort();
    }

    final productsBySupplierSets = <String, Set<String>>{};

    for (final row in ppsRows) {
      final productId = (row['product_id'] as num?)?.toInt();
      final supplierId = (row['supplier_id'] as num?)?.toInt();
      if (productId == null || supplierId == null) continue;

      final supplierName = _supplierNameById[supplierId];
      if (supplierName == null) continue;

      final baseId = baseIdByProductId[productId] ?? productId;
      final variantDisplays = displaysByBaseId[baseId];

      productsBySupplierSets.putIfAbsent(supplierName, () => <String>{});

      if (variantDisplays == null || variantDisplays.isEmpty) {
        final direct = displayByProductId[productId];
        if (direct != null) productsBySupplierSets[supplierName]!.add(direct);
      } else {
        productsBySupplierSets[supplierName]!.addAll(variantDisplays);
      }
    }

    final productsBySupplierName = <String, List<String>>{};
    for (final e in productsBySupplierSets.entries) {
      final list = e.value.toList()..sort();
      productsBySupplierName[e.key] = list;
    }

    if (productsBySupplierName.isEmpty && allDisplays.isNotEmpty) {
      for (final supplierName in _supplierNameById.values) {
        productsBySupplierName[supplierName] = List<String>.from(allDisplays);
      }
    }

    _unitShortcutById = unitShortcutById;
    _unitNameById = unitNameById;
    _productIdByDisplay = productIdByDisplay;
    _productMetaByDisplay = productMetaByDisplay;
    _allProducts = allDisplays;
    _productsBySupplier = productsBySupplierName;
  }

  Future<void> _seedUnitsIfEmpty(Database dbSales) async {
    final existing = await dbSales.query('unit', columns: ['unit_id'], limit: 1);
    if (existing.isNotEmpty) return;

    try {
      final unitList = await _remoteApi.fetchList(ApiConfig.units, query: {'limit': '-1'});
      if (unitList.isEmpty) return;

      final batch = dbSales.batch();
      batch.delete('unit');

      for (final u in unitList) {
        final m = Map<String, dynamic>.from(u);
        final unitIdRaw = m['unit_id'] ?? m['id'];
        final unitId = (unitIdRaw is num) ? unitIdRaw.toInt() : int.tryParse('$unitIdRaw');

        if (unitId == null) continue;

        final sortOrderRaw = m['sort_order'] ?? m['order'];
        final sortOrder = (sortOrderRaw is num)
            ? sortOrderRaw.toInt()
            : int.tryParse('$sortOrderRaw');

        final row = <String, Object?>{
          'unit_id': unitId,
          'unit_name': (m['unit_name'] ?? '').toString(),
          'unit_shortcut': (m['unit_shortcut'] ?? '').toString(),
          'sort_order': sortOrder,
        };

        batch.insert('unit', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[OrderController] Failed to seed units: $e');
    }
  }

  String _uomLabelFromMaps(int? unitId, Map<int, String> shortcutById, Map<int, String> nameById) {
    if (unitId == null) return 'UOM';

    final sc = shortcutById[unitId];
    if (sc != null && sc.trim().isNotEmpty) return sc.trim();

    final nm = nameById[unitId];
    if (nm != null && nm.trim().isNotEmpty) return nm.trim();

    return 'UOM';
  }

  String _uomLabelFromDescription(
    String description,
    Map<int, String> shortcutById,
    Map<int, String> nameById,
  ) {
    final d = description.trim().toLowerCase();
    if (d.isEmpty) return 'UOM';

    if (nameById.isNotEmpty || shortcutById.isNotEmpty) {
      final Map<String, String> tokenToShortcut = {};

      for (final e in nameById.entries) {
        final name = e.value.trim().toLowerCase();
        final shortcut = (shortcutById[e.key] ?? '').trim();
        if (name.isNotEmpty && shortcut.isNotEmpty) {
          tokenToShortcut[name] = shortcut;
        }
      }

      for (final sc in shortcutById.values) {
        final s = sc.trim();
        if (s.isNotEmpty) tokenToShortcut[s.toLowerCase()] = s;
      }

      final tokens = tokenToShortcut.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

      for (final token in tokens) {
        if (d.endsWith(' $token') || d == token) {
          return tokenToShortcut[token] ?? 'UOM';
        }
      }
    }

    return _uomFallbackFromText(description);
  }

  String _uomFallbackFromText(String text) {
    final s = text.toLowerCase();

    bool hasWord(String w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(s);

    if (hasWord('pcs') || hasWord('piece') || hasWord('pieces')) return 'PCS';
    if (hasWord('box') || hasWord('boxes')) return 'BOX';
    if (hasWord('carton') || hasWord('ctn')) return 'CTN';
    if (hasWord('pack') || hasWord('packs')) return 'PACK';
    if (hasWord('case') || hasWord('cases')) return 'CASE';

    return 'UOM';
  }

  double _inferCountFromText(String text) {
    final s = text.toLowerCase();

    final m1 = RegExp(r'\bx\s*(\d+(\.\d+)?)\b').firstMatch(s);
    if (m1 != null) return double.tryParse(m1.group(1)!) ?? 1.0;

    final m2 = RegExp(r"\b(\d+)\s*'s\b").firstMatch(s);
    if (m2 != null) return double.tryParse(m2.group(1)!) ?? 1.0;

    return 1.0;
  }

  void selectProduct(String product) {
    _selectedProduct = product;
    notifyListeners();
  }

  void addProductsToCart(List<String> productDisplays) {
    for (final productDisplay in productDisplays) {
      final meta = _productMetaByDisplay[productDisplay];
      if (meta != null) {
        final defaultUnitDisplay = _getDefaultUnitForProduct(productDisplay);
        _cartItems.add(
          CartItem(
            productDisplay: productDisplay,
            productId: meta.productId,
            productBaseId: meta.baseId,
            unitId: meta.unitId,
            unitCount: meta.unitCount,
            selectedUnitDisplay: defaultUnitDisplay,
            quantity: 1,
            price: 1500.0, // Default price
          ),
        );
      }
    }
    notifyListeners();
  }

  List<String> getAvailableUnitsForProduct(String productDisplay) {
    final meta = _productMetaByDisplay[productDisplay];
    if (meta == null) return [productDisplay];

    final baseId = meta.baseId ?? meta.productId;
    return _productMetaByDisplay.entries
        .where((e) => (e.value.baseId ?? e.value.productId) == baseId)
        .map((e) => e.key)
        .toList();
  }

  String _getDefaultUnitForProduct(String productDisplay) {
    final availableUnits = getAvailableUnitsForProduct(productDisplay);
    for (final unit in availableUnits) {
      if (unit.contains('(PCS)') || unit.contains('PCS')) {
        return unit;
      }
    }
    return availableUnits.isNotEmpty ? availableUnits.first : productDisplay;
  }

  void updateCartItem(int index, CartItem updatedItem) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = updatedItem;
      notifyListeners();
    }
  }

  void removeCartItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // Order operations
  void _generatePoNumber() {
    final supplierName = _selectedSupplier;
    if (supplierName == null) return;

    final shortcut = _supplierShortcuts[supplierName] ?? 'PO';
    final now = DateTime.now();
    final formatted = DateFormat('yyyyMMddHHmmss').format(now);

    // This would be used when saving the order
  }

  Future<void> saveOrder({
    required String customerName,
    required String customerCode,
    required String poNo,
    required String remarks,
    required WidgetRef ref,
    String? callsheetImagePath,
  }) async {
    final now = DateTime.now();
    final supplierId = (_selectedSupplier != null) ? _supplierIdByName[_selectedSupplier!] : null;
    final authState = ref.read(authProvider);
    final salesmanId = authState.salesman?.id ?? authState.user?.userId;

    final order = OrderModel(
      orderNo: poNo,
      poNo: poNo,
      customerName: customerName,
      customerCode: customerCode,
      salesmanId: salesmanId,
      supplierId: supplierId,
      orderDate: now,
      createdAt: now,
      totalAmount: grandTotal,
      netAmount: grandTotal,
      status: 'Pending',
      type: OrderType.manual,
      supplier: _selectedSupplier,
      priceType: _selectedPriceType,
      hasAttachment: callsheetImagePath != null,
      callsheetImagePath: callsheetImagePath,
      remarks: remarks,
    );

    await _repository.saveOrder(order, _cartItems);
    clearCart();
  }
}
