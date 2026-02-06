// ib/features/orders/presentation/order_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vos_sfa_go/core/api/api_config.dart';
import 'package:vos_sfa_go/core/api/global_remote_api.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';
import 'package:vos_sfa_go/features/orders/presentation/widgets/modals/customer_picker_modal.dart';
import 'package:vos_sfa_go/features/orders/presentation/widgets/modals/supplier_picker_modal.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../callsheet/presentation/callsheet_capture_page.dart';
import '../data/models/cart_item_model.dart';
import 'widgets/modals/product_picker_modal.dart';
import 'checkout_page.dart';
import '../data/repositories/order_repository.dart';

class OrderFormPage extends ConsumerStatefulWidget {
  const OrderFormPage({
    super.key,
    this.initialCustomer,
    this.initialType,
    this.initialOrder,
  });

  final Customer? initialCustomer;
  final OrderType? initialType;
  final OrderModel? initialOrder;

  @override
  ConsumerState<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends ConsumerState<OrderFormPage> {
  final _formKey = GlobalKey<FormState>();

  final GlobalRemoteApi _remoteApi = GlobalRemoteApi();

  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerCodeCtrl = TextEditingController();

  // Customer dropdown state
  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  final List<Customer> _filteredCustomers = [];
  // Supplier text controller (instead of dropdown value)
  final TextEditingController _supplierCtrl = TextEditingController();

  final TextEditingController _poNumberCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  String? _selectedSupplier;
  String? _selectedProduct; // display string (variant)
  String? _selectedPriceType;
  String? _callsheetImagePath;

  // Cart items for cart-style ordering
  final List<CartItem> _cartItems = [];

  double get _grandTotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.total);

  // === Supplier data from SQLite ===
  List<String> _suppliers = [];
  Map<String, String> _supplierShortcuts = {};
  Map<String, int> _supplierIdByName = {}; // Used for efficient lookup

  // === Units ===
  Map<int, String> _unitShortcutById = {};
  Map<int, String> _unitNameById = {};

  // Products
  List<Product> _allProducts = [];
  Map<int, Set<int>> _productIdsBySupplierId = {};

  List<Product> get _currentProducts {
    if (_selectedSupplier == null) return _allProducts;

    // Get supplier ID
    final supplierId = _supplierIdByName[_selectedSupplier!];
    if (supplierId == null) return _allProducts;

    // Filter by supplier-product mapping if available
    // (Note: The current DB structure has product_per_supplier table.
    // We need to use that. In _loadProductsFromDb we can build a map of SupplierID -> List<ProductID>)

    // Better approach: We have `_productIdsBySupplierName` or similar.
    // Let's implement robust filtering in `_loadProductsFromDb` and store a map.
    final allowedIds = _productIdsBySupplierId[supplierId];
    if (allowedIds == null || allowedIds.isEmpty) {
      // Fallback or empty?
      // If strict: return [];
      // If lenient: return _allProducts;
      return [];
    }

    return _allProducts.where((p) => allowedIds.contains(p.id)).toList();
  }

  // This will be overridden or used as base
  List<String> _priceTypes = const [
    'Retail',
    'Wholesale',
    'Promo',
    'A',
    'B',
    'C',
    'D',
    'E',
  ];

  bool _isLoadingMasters = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialOrder != null) {
      final order = widget.initialOrder!;
      _selectedCustomer = Customer(
        id:
            order.id ??
            0, // ID might not be available or needed for UI display purposes here if we have name/code
        name: order.customerName,
        code: order.customerCode ?? '',
      );
      _customerNameCtrl.text = order.customerName;
      _customerCodeCtrl.text = order.customerCode ?? '';
      _poNumberCtrl.text = order.poNo ?? '';
      _remarksCtrl.text = order.remarks ?? '';
      _selectedSupplier = order.supplier;
      _supplierCtrl.text = order.supplier ?? '';
      _callsheetImagePath = order.callsheetImagePath;
      // Note: Cart items will be loaded async
    } else if (widget.initialCustomer != null) {
      _selectedCustomer = widget.initialCustomer;
      _customerNameCtrl.text = widget.initialCustomer!.name;
      _customerCodeCtrl.text = widget.initialCustomer!.code;
    }

    if (widget.initialOrder == null) {
      _poNumberCtrl.text = '';
    }

    // 🔹 Lock price type to logged-in salesman’s price_type
    final authState = ref.read(authProvider);
    final salesman = authState.salesman;
    final String? salesmanPriceType = salesman?.priceType;

    if (salesmanPriceType != null && salesmanPriceType.isNotEmpty) {
      // Ensure the salesman's type is in the list
      if (!_priceTypes.contains(salesmanPriceType)) {
        _priceTypes = [..._priceTypes, salesmanPriceType];
      }
      _selectedPriceType = salesmanPriceType;
    } else {
      _selectedPriceType = 'Retail'; // Default
    }

    // Auto-select based on initial customer if present
    if (_selectedCustomer != null && _selectedCustomer!.priceType != null) {
      if (_priceTypes.contains(_selectedCustomer!.priceType)) {
        _selectedPriceType = _selectedCustomer!.priceType;
      }
    }

    _loadMasterData();

    if (widget.initialOrder != null) {
      _loadOrderItems(widget.initialOrder!.orderId!);
    }
  }

  Future<void> _loadOrderItems(int orderId) async {
    try {
      final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);
      final rows = await db.query(
        'sales_order_details',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final List<CartItem> loadedItems = [];

      for (final row in rows) {
        final productId = (row['product_id'] as num?)?.toInt();
        if (productId == null) continue;

        final quantity = (row['ordered_quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = (row['unit_price'] as num?)?.toDouble() ?? 0.0;

        // Wait for products to be loaded if they aren't yet?
        // Actually this runs in parallel with _loadMasterData.
        // We should delay slightly or retry if _allProducts is empty.
        // Simple retry loop:
        int retries = 0;
        while (_allProducts.isEmpty && retries < 5) {
          await Future.delayed(const Duration(milliseconds: 300));
          retries++;
        }

        String display = 'Product #$productId';
        int? unitId;
        double unitCount = 1.0;
        String unitDisplay = 'PCS';
        int baseId = productId;

        try {
          final product = _allProducts.firstWhere((p) => p.id == productId);
          display = product.name;
          unitId = product.unitId;
          unitCount = product.uomCount;
          unitDisplay = product.uom.isNotEmpty ? product.uom : 'PCS';
          baseId = product.parentId ?? product.id;

          if (unitCount > 1) {
            final countText = (unitCount % 1 == 0)
                ? unitCount.toInt().toString()
                : unitCount.toString();
            if (RegExp(r'\bPCS\b').hasMatch(unitDisplay.toUpperCase())) {
              display = '$display ($countText PCS)';
            } else {
              display = '$display ($unitDisplay x$countText)';
            }
          } else {
            display = '$display ($unitDisplay)';
          }
        } catch (_) {
          // Not found
        }

        loadedItems.add(
          CartItem(
            productDisplay: display,
            productId: productId,
            productBaseId: baseId,
            unitId: unitId,
            unitCount: unitCount,
            selectedUnitDisplay: unitDisplay,
            quantity: quantity,
            price: unitPrice,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _cartItems.addAll(loadedItems);
        });
      }
    } catch (e) {
      debugPrint('Error loading order items: $e');
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerCodeCtrl.dispose();
    _poNumberCtrl.dispose();
    _remarksCtrl.dispose();
    _quantityCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoadingMasters = true);

    try {
      await _loadCustomersFromDb();
      await _loadSuppliersFromDb();
      await _loadProductsFromDb();
    } catch (e) {
      debugPrint('Error loading master data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMasters = false);
    }
  }

  Future<void> _loadCustomersFromDb() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

    final rows = await db.query(
      'customer',
      columns: [
        'id',
        'customer_name',
        'customer_code',
        'isActive',
        'price_type',
      ],
    );

    final List<Customer> customers = [];

    for (final row in rows) {
      final name = (row['customer_name'] ?? '').toString();
      if (name.isEmpty) continue;

      // only active
      final rawIsActive = row['isActive'];
      final isActiveInt = (rawIsActive is num) ? rawIsActive.toInt() : 1;
      if (isActiveInt != 1) continue;

      final rawId = row['id'];
      final id = (rawId is num) ? rawId.toInt() : null;
      if (id == null) continue;

      final code = (row['customer_code'] ?? '').toString();
      final pType = row['price_type'] as String?;

      customers.add(Customer(id: id, name: name, code: code, priceType: pType));
    }

    customers.sort((a, b) => a.name.compareTo(b.name));

    _customers = customers;
  }

  void _showSupplierSearchDialog() async {
    // Show new premium modal
    await showDialog(
      context: context,
      builder: (context) => SupplierPickerModal(
        suppliers: _suppliers,
        selectedSupplier: _selectedSupplier,
        onSupplierSelected: (supplier) {
          if (supplier != null) {
            setState(() {
              _selectedSupplier = supplier;
              _supplierCtrl.text = supplier;
              _selectedProduct = null;
              _cartItems.clear(); // Clear cart when supplier changes
            });
            _generatePoNumberForSupplier();
          }
        },
      ),
    );
  }

  void _showCustomerSearchDialog() async {
    await showDialog(
      context: context,
      builder: (context) => CustomerPickerModal(
        customers: _customers,
        selectedCustomer: _selectedCustomer,
        onCustomerSelected: (customer) {
          if (customer != null) {
            setState(() {
              _selectedCustomer = customer;
              _customerNameCtrl.text = customer.name;
              _customerCodeCtrl.text = customer.code;

              // Auto-select price type if available
              if (customer.priceType != null &&
                  customer.priceType!.isNotEmpty &&
                  _priceTypes.contains(customer.priceType)) {
                _selectedPriceType = customer.priceType;
              } else {
                // If customer has NO price type, revert to Salesman default (if set) or Retail
                final authState = ref.read(authProvider);
                final salesman = authState.salesman;
                if (salesman?.priceType != null &&
                    salesman!.priceType!.isNotEmpty) {
                  _selectedPriceType = salesman.priceType;
                } else {
                  _selectedPriceType = 'Retail';
                }
              }
            });
          }
        },
      ),
    );
  }

  void _showProductPicker() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier first')),
      );
      return;
    }

    final supplierId = _supplierIdByName[_selectedSupplier!];
    final customerCode = _selectedCustomer?.code;

    if (supplierId == null || customerCode == null) {
      // Should not happen if validation passes
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => ProductPickerModal(
        products: _currentProducts,
        priceType: _selectedPriceType ?? 'Retail',
        onProductsSelected: (selections) async {
          if (selections.isEmpty) return;

          // Show loading indicator while calculating prices?
          // Or just do it quickly. SQLite is fast.
          // Ideally show a loader if many items.

          final repo = OrderRepository();
          final List<CartItem> newItems = [];

          for (final sel in selections) {
            final product = sel.product;
            final qty = sel.quantity;

            try {
              // Calculate Price/Discount
              final priceResult = await repo.calculateProductPrice(
                product: product,
                customerCode: customerCode,
                supplierId: supplierId,
                priceType: _selectedPriceType ?? 'Retail',
              );

              newItems.add(
                CartItem(
                  productDisplay: product.description.isNotEmpty
                      ? product.description
                      : product.name,
                  productId: product.id,
                  productBaseId: product.parentId ?? product.id,
                  unitId: product.unitId,
                  unitCount: product.uomCount,
                  selectedUnitDisplay: product.uom.isNotEmpty
                      ? product.uom
                      : 'UNIT',
                  quantity: qty,
                  price: priceResult.netPrice, // NET Price
                  originalPrice: priceResult.basePrice,
                  discountAmount: priceResult.discountAmount, // Per Unit
                  discountTypeId: priceResult.discountTypeId,
                  discountName: priceResult.discountName,
                ),
              );
            } catch (e) {
              debugPrint('Error calculating price for ${product.name}: $e');
              // Fallback: Add with base prices
              newItems.add(
                CartItem(
                  productDisplay: product.description.isNotEmpty
                      ? product.description
                      : product.name,
                  productId: product.id,
                  productBaseId: product.parentId ?? product.id,
                  unitId: product.unitId,
                  unitCount: product.uomCount,
                  selectedUnitDisplay: product.uom.isNotEmpty
                      ? product.uom
                      : 'UNIT',
                  quantity: qty,
                  price: product.getPrice(_selectedPriceType ?? 'Retail'),
                  originalPrice: product.getPrice(
                    _selectedPriceType ?? 'Retail',
                  ),
                  discountAmount: 0.0,
                  discountTypeId: null,
                  discountName: null,
                ),
              );
            }
          }

          if (!mounted) return;

          setState(() {
            for (final newItem in newItems) {
              final existingIndex = _cartItems.indexWhere(
                (item) => item.productId == newItem.productId,
              );

              if (existingIndex >= 0) {
                // Update existing
                final existing = _cartItems[existingIndex];
                _cartItems[existingIndex] = existing.copyWith(
                  quantity: existing.quantity + newItem.quantity,
                  // Should we update price? Yes, in case it changed or context changed.
                  price: newItem.price,
                  originalPrice: newItem.originalPrice,
                  discountAmount: newItem.discountAmount,
                  discountTypeId: newItem.discountTypeId,
                  discountName: newItem.discountName,
                );
              } else {
                // Add new
                _cartItems.add(newItem);
              }
            }
          });
        },
      ),
    );
  }

  Future<void> _loadSuppliersFromDb() async {
    final db = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

    final rows = await db.query(
      'supplier',
      columns: [
        'id',
        'supplier_name',
        'supplier_shortcut',
        'supplier_type',
        'isActive',
      ],
    );

    final List<String> names = [];
    final Map<String, String> shortcuts = {};
    final Map<String, int> idByName = {};

    for (final row in rows) {
      final name = (row['supplier_name'] ?? '').toString();
      if (name.isEmpty) continue;

      // only TRADE
      final type = ((row['supplier_type'] ?? '').toString()).toUpperCase();
      if (type != 'TRADE') continue;

      // only active
      final rawIsActive = row['isActive'];
      final isActiveInt = (rawIsActive is num) ? rawIsActive.toInt() : 1;
      if (isActiveInt != 1) continue;

      final rawId = row['id'];
      final id = (rawId is num) ? rawId.toInt() : null;
      if (id == null) continue;

      names.add(name);
      idByName[name] = id;

      final shortcut = (row['supplier_shortcut'] ?? '').toString();
      if (shortcut.isNotEmpty) shortcuts[name] = shortcut;
    }

    names.sort();

    setState(() {
      _suppliers = names;
      _supplierShortcuts = shortcuts;
      _supplierIdByName = idByName;
    });
  }

  // -------- UNIT SYNC (LOCAL SEED) --------

  Future<void> _seedUnitsIfEmpty(Database dbSales) async {
    // If already has units, do nothing.
    final existing = await dbSales.query(
      'unit',
      columns: ['unit_id'],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    debugPrint(
      '[OrderForm] unit table is empty → seeding from API ${ApiConfig.units}',
    );

    try {
      final unitList = await _remoteApi.fetchList(
        ApiConfig.units,
        query: {'limit': '-1'},
      );
      if (unitList.isEmpty) {
        debugPrint('[OrderForm] units API returned 0 rows; cannot seed.');
        return;
      }

      final batch = dbSales.batch();
      batch.delete('unit');

      for (final u in unitList) {
        final m = Map<String, dynamic>.from(u);

        // Support either "unit_id" or "id"
        final unitIdRaw = m['unit_id'] ?? m['id'];
        final unitId = (unitIdRaw is num)
            ? unitIdRaw.toInt()
            : int.tryParse('$unitIdRaw');

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
      debugPrint('[OrderForm] Seeded unit rows: ${unitList.length}');
    } catch (e) {
      debugPrint('[OrderForm] Failed to seed units: $e');
    }
  }

  // -------- UOM HELPERS --------

  String _uomLabelFromMaps(
    int? unitId,
    Map<int, String> shortcutById,
    Map<int, String> nameById,
  ) {
    if (unitId == null) return 'UOM';

    final sc = shortcutById[unitId];
    if (sc != null && sc.trim().isNotEmpty) return sc.trim();

    final nm = nameById[unitId];
    if (nm != null && nm.trim().isNotEmpty) return nm.trim();

    return 'UOM';
  }

  /// Fallback: try to infer from common keywords if unit master is missing.
  String _uomFallbackFromText(String text) {
    final s = text.toLowerCase();

    bool hasWord(String w) =>
        RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(s);

    if (hasWord('pcs') || hasWord('piece') || hasWord('pieces')) return 'PCS';
    if (hasWord('box') || hasWord('boxes')) return 'BOX';
    if (hasWord('carton') || hasWord('ctn')) return 'CTN';
    if (hasWord('pack') || hasWord('packs')) return 'PACK';
    if (hasWord('case') || hasWord('cases')) return 'CASE';

    return 'UOM';
  }

  /// Fallback: infer UOM using unit master tokens; if not available, use common keyword fallback.
  String _uomLabelFromDescription(
    String description,
    Map<int, String> shortcutById,
    Map<int, String> nameById,
  ) {
    final d = description.trim().toLowerCase();
    if (d.isEmpty) return 'UOM';

    // If unit master exists, map unit_name -> shortcut
    if (nameById.isNotEmpty || shortcutById.isNotEmpty) {
      final Map<String, String> tokenToShortcut = {};

      // name -> shortcut
      for (final e in nameById.entries) {
        final name = e.value.trim().toLowerCase();
        final shortcut = (shortcutById[e.key] ?? '').trim();
        if (name.isNotEmpty && shortcut.isNotEmpty) {
          tokenToShortcut[name] = shortcut;
        }
      }

      // shortcut -> shortcut
      for (final sc in shortcutById.values) {
        final s = sc.trim();
        if (s.isNotEmpty) tokenToShortcut[s.toLowerCase()] = s;
      }

      // Prefer longest tokens first
      final tokens = tokenToShortcut.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final token in tokens) {
        if (d.endsWith(' $token') || d == token) {
          return tokenToShortcut[token] ?? 'UOM';
        }
      }
    }

    // Otherwise: basic keyword fallback
    return _uomFallbackFromText(description);
  }

  Future<void> _loadProductsFromDb() async {
    final dbSales = await DatabaseManager().getDatabase(
      DatabaseManager.dbSales,
    );

    // 1) Ensure units exist locally (critical for correct labels)
    await _seedUnitsIfEmpty(dbSales);

    // 2) Load unit master (PCS/BOX/etc.)
    List<Map<String, Object?>> unitRows = [];
    try {
      unitRows = await dbSales.query(
        'unit',
        columns: ['unit_id', 'unit_name', 'unit_shortcut', 'sort_order'],
        orderBy: 'COALESCE(sort_order, 999999) ASC, unit_shortcut ASC',
      );
    } catch (e) {
      debugPrint('[OrderForm] unit table not available yet: $e');
    }

    final unitShortcutById = <int, String>{};
    final unitNameById = <int, String>{};

    for (final r in unitRows) {
      final id = (r['unit_id'] as num?)?.toInt();
      if (id == null) continue;
      unitShortcutById[id] = (r['unit_shortcut'] ?? '').toString().trim();
      unitNameById[id] = (r['unit_name'] ?? '').toString().trim();
    }

    // 3) Load products + mapping
    List<Map<String, Object?>> productRows = [];
    List<Map<String, Object?>> ppsRows = [];

    final columnsToFetch = [
      'product_id',
      'product_name',
      'product_code',
      'description',
      'parent_id',
      'unit_of_measurement',
      'unit_of_measurement_count',
      'price_per_unit',
      'cost_per_unit',
      'priceA',
      'priceB',
      'priceC',
    ];

    try {
      productRows = await dbSales.query('product', columns: columnsToFetch);

      ppsRows = await dbSales.query(
        'product_per_supplier',
        columns: ['product_id', 'supplier_id'],
      );

      debugPrint(
        '[OrderForm] Loaded from dbSales → products=${productRows.length}, pps=${ppsRows.length}, units=${unitRows.length}',
      );
    } catch (e) {
      debugPrint('[OrderForm] Error querying dbSales product/pps: $e');
    }

    // 4) Fallback to CUSTOMER DB if no products
    if (productRows.isEmpty) {
      final dbCustomer = await DatabaseManager().getDatabase(
        DatabaseManager.dbCustomer,
      );

      try {
        productRows = await dbCustomer.query(
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

        ppsRows = await dbCustomer.query(
          'product_per_supplier',
          columns: ['product_id', 'supplier_id'],
        );

        debugPrint(
          '[OrderForm] Fallback dbCustomer → products=${productRows.length}, pps=${ppsRows.length}',
        );
      } catch (e) {
        debugPrint('[OrderForm] Error querying dbCustomer product/pps: $e');
      }
    }

    // Build Product Objects
    final List<Product> loadedProducts = [];

    for (final row in productRows) {
      final uomId = (row['unit_of_measurement'] as num?)?.toInt();
      final desc = (row['description'] ?? '').toString();
      final pname = (row['product_name'] ?? '').toString();

      // Infer UOM Label
      var uom = (uomId != null)
          ? _uomLabelFromMaps(uomId, unitShortcutById, unitNameById)
          : _uomLabelFromDescription(desc, unitShortcutById, unitNameById);

      if (uom.toUpperCase() == 'UOM') {
        uom = _uomFallbackFromText('$pname $desc');
      }

      loadedProducts.add(Product.fromMap(row, uomLabel: uom));
    }

    loadedProducts.sort((a, b) => a.name.compareTo(b.name));

    // Build Supplier Mapping
    final Map<int, Set<int>> supplierMapping = {};
    for (final row in ppsRows) {
      final pid = (row['product_id'] as num?)?.toInt();
      final sid = (row['supplier_id'] as num?)?.toInt();
      if (pid != null && sid != null) {
        supplierMapping.putIfAbsent(sid, () => {}).add(pid);
      }
    }

    if (mounted) {
      setState(() {
        _unitShortcutById = unitShortcutById;
        _unitNameById = unitNameById;
        _allProducts = loadedProducts;
        _productIdsBySupplierId = supplierMapping;
      });
    }
  }

  Future<void> _openCallsheetCapture() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CallsheetCapturePage()),
    );

    if (result != null && mounted) {
      setState(() => _callsheetImagePath = result);
    }
  }

  void _generatePoNumberForSupplier() {
    final supplierName = _selectedSupplier;
    if (supplierName == null) {
      _poNumberCtrl.text = '';
      return;
    }

    final shortcut = _supplierShortcuts[supplierName] ?? 'PO';
    final now = DateTime.now();
    final formatted = DateFormat('yyyyMMddHHmmss').format(now);

    setState(() {
      _poNumberCtrl.text = '$shortcut-$formatted';
    });
  }

  /// Ensures the local sales tables exist before saving.
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

        -- Extra UI columns for offline functionality
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

    // --- MIGRATION LOGIC ---
    // Fixes "no column named customer_name" if table exists from older version.
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

  void _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the cart'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final supplierId = (_selectedSupplier != null)
        ? _supplierIdByName[_selectedSupplier!]
        : null;
    final authState = ref.read(authProvider);
    final salesmanId = authState.salesman?.id ?? authState.user?.userId;
    // Get branchId from Salesman model
    final branchId = authState.salesman?.branchId;

    // Calculate Totals
    double grossTotal = 0.0;
    double discountTotal = 0.0;
    double netTotal = 0.0;

    for (final item in _cartItems) {
      final qty = item.quantity;
      final base = item.originalPrice ?? item.price;
      final net = item.price;
      final discount = item.discountAmount; // Per unit

      grossTotal += base * qty;
      netTotal += net * qty;
      discountTotal += discount * qty;
    }

    // Create order header template
    final orderTemplate = OrderModel(
      orderNo: _poNumberCtrl.text.trim(),
      poNo: _poNumberCtrl.text.trim(),
      customerName: _customerNameCtrl.text.trim(),
      customerCode: _customerCodeCtrl.text.trim(),
      salesmanId: salesmanId,
      supplierId: supplierId,
      branchId: branchId,
      orderDate: now,
      createdAt: now,
      totalAmount: grossTotal, // Gross
      discountAmount: discountTotal, // Discount
      netAmount: netTotal, // Net
      status: 'Pending',
      type: OrderType.manual,
      supplier: _selectedSupplier,
      priceType: _selectedPriceType,
      hasAttachment: _callsheetImagePath != null,
      callsheetImagePath: _callsheetImagePath,
      remarks: _remarksCtrl.text.trim(),
    );

    // Navigate to Checkout Page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          orderTemplate: orderTemplate.copyWith(
            id: widget.initialOrder?.id, // Pass existing ID
            orderId: widget.initialOrder?.orderId,
            // Ensure IsSynced is reset if we are editing?
            // Usually if editing an unsynced order, it stays unsynced.
            // CheckoutPage/Repository should handle saving logic.
            // But we should make sure we know we are EDITING.
          ),
          initialItems: _cartItems,
        ),
      ),
    );

    // If checkout was successful (returns true), pop this page too
    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayPriceType = _selectedPriceType ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create New Order'),
        centerTitle: false,
        elevation: 0,
      ),
      body: _isLoadingMasters
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading data...',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Information
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Customer Information',
                              icon: Icons.person_outline,
                            ),
                            InkWell(
                              onTap: _showCustomerSearchDialog,
                              child: IgnorePointer(
                                child: TextFormField(
                                  controller: _customerNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name',
                                    hintText: 'Tap to search customers',
                                    prefixIcon: const Icon(
                                      Icons.person,
                                      size: 20,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 24,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Customer name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _customerCodeCtrl,
                              decoration: InputDecoration(
                                labelText: 'Customer Code',
                                hintText: 'Enter customer code (optional)',
                                prefixIcon: const Icon(Icons.badge, size: 20),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // PO Number
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Sales Order',
                              icon: Icons.receipt_long,
                            ),
                            TextFormField(
                              controller: _poNumberCtrl,
                              decoration: InputDecoration(
                                labelText: 'SO Number',
                                hintText:
                                    'Auto-generated after supplier selection',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SO number will be generated automatically based on selected supplier',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _remarksCtrl,
                              decoration: InputDecoration(
                                labelText: 'Remarks',
                                hintText: 'Enter notes (optional)',
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 58,
                                  ), // Align icon to top
                                  child: Icon(Icons.notes, size: 20),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Order Details
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Order Details',
                              icon: Icons.shopping_cart_outlined,
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Price Type:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      displayPriceType,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                  ),
                                ],
                              ),
                            ),

                            // Supplier Selection (Text Field)
                            InkWell(
                              onTap: _showSupplierSearchDialog,
                              child: IgnorePointer(
                                child: TextFormField(
                                  controller: _supplierCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Supplier',
                                    hintText: 'Tap to select supplier',
                                    prefixIcon: const Icon(
                                      Icons.storefront,
                                      size: 20,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 24,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Supplier is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Add Products Button
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _showProductPicker,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Add Products'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Cart Items List
                            if (_cartItems.isNotEmpty) ...[
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cartItems.length,
                                itemBuilder: (context, index) {
                                  final item = _cartItems[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.productDisplay,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _cartItems.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Price Display
                                          Row(
                                            children: [
                                              if (item.originalPrice != null &&
                                                  item.originalPrice! >
                                                      item.price) ...[
                                                Text(
                                                  '₱${item.originalPrice!.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                '₱${item.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (item.discountName != null &&
                                                  item
                                                      .discountName!
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.orange[200]!,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.discountName!,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.orange[800],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.grey[300]!,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.selectedUnitDisplay,
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: item.quantity
                                                      .toString(),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: 'Quantity',
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                  ),
                                                  onChanged: (value) {
                                                    final qty =
                                                        int.tryParse(value) ??
                                                        1;
                                                    setState(() {
                                                      _cartItems[index] = item
                                                          .copyWith(
                                                            quantity: qty,
                                                          );
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Total: ₱${item.total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Grand Total:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₱${_grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No products added to cart yet.\nTap "Add Products" to get started.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saveOrder,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text(
                            'Save Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
