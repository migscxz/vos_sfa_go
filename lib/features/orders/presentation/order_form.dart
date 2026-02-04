// ib/features/orders/presentation/order_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vos_sfa_go/core/api/api_config.dart';
import 'package:vos_sfa_go/core/api/global_remote_api.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';
import 'package:vos_sfa_go/features/orders/presentation/widgets/modals/customer_picker_modal.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../callsheet/presentation/callsheet_capture_page.dart';
import '../data/models/cart_item_model.dart';

class _ProductVariantMeta {
  final int productId; // variant product_id
  final int? baseId; // parent/base product_id (parent_id==null => baseId=productId)
  final int? unitId;
  final double unitCount;

  const _ProductVariantMeta({
    required this.productId,
    required this.baseId,
    required this.unitId,
    required this.unitCount,
  });
}

class SupplierSearchDialog extends StatefulWidget {
  const SupplierSearchDialog({super.key, required this.suppliers});

  final List<String> suppliers;

  @override
  State<SupplierSearchDialog> createState() => _SupplierSearchDialogState();
}

class _SupplierSearchDialogState extends State<SupplierSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _filteredSuppliers = widget.suppliers;
    _searchCtrl.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterSuppliers() {
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredSuppliers = widget.suppliers);
    } else {
      setState(() {
        _filteredSuppliers = widget.suppliers.where((supplier) {
          return supplier.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Supplier'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _filteredSuppliers[index];
                  return ListTile(
                    title: Text(supplier),
                    onTap: () => Navigator.of(context).pop(supplier),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}

class MultiSelectProductDialog extends StatefulWidget {
  const MultiSelectProductDialog({super.key, required this.products});

  final List<String> products;

  @override
  State<MultiSelectProductDialog> createState() => _MultiSelectProductDialogState();
}

class _MultiSelectProductDialogState extends State<MultiSelectProductDialog> {
  final Set<String> _selectedProducts = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Products'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.products.length,
          itemBuilder: (context, index) {
            final product = widget.products[index];
            final isSelected = _selectedProducts.contains(product);
            return CheckboxListTile(
              title: Text(product),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedProducts.add(product);
                  } else {
                    _selectedProducts.remove(product);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedProducts.toList()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class CustomerSearchDialog extends StatefulWidget {
  const CustomerSearchDialog({super.key, required this.customers});

  final List<Customer> customers;

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchCtrl.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredCustomers = widget.customers);
    } else {
      setState(() {
        _filteredCustomers = widget.customers.where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              customer.code.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = _filteredCustomers[index];
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text(customer.code),
                    onTap: () => Navigator.of(context).pop(customer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}

class OrderFormPage extends ConsumerStatefulWidget {
  const OrderFormPage({
    super.key,
    this.initialCustomerName,
    this.initialCustomerCode,
    this.initialType,
  });

  final String? initialCustomerName;
  final String? initialCustomerCode;
  final OrderType? initialType;

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
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _poNumberCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  String? _selectedSupplier;
  String? _selectedProduct; // display string (variant)
  String? _selectedPriceType;
  String? _callsheetImagePath;

  // Cart items for cart-style ordering
  final List<CartItem> _cartItems = [];

  double get _grandTotal => _cartItems.fold(0.0, (sum, item) => sum + item.total);

  // === Supplier data from SQLite ===
  List<String> _suppliers = [];
  Map<String, String> _supplierShortcuts = {};
  Map<String, int> _supplierIdByName = {};
  Map<int, String> _supplierNameById = {};

  // === Units ===
  Map<int, String> _unitShortcutById = {};
  Map<int, String> _unitNameById = {};

  // === Product dropdown source (display strings) ===
  List<String> _allProducts = [];
  Map<String, List<String>> _productsBySupplier = {};

  // display -> product_id (variant)
  Map<String, int> _productIdByDisplay = {};

  // display -> full meta (variant/base/unit info)
  Map<String, _ProductVariantMeta> _productMetaByDisplay = {};

  List<String> get _currentProducts {
    if (_selectedSupplier == null) return _allProducts;
    final list = _productsBySupplier[_selectedSupplier];
    if (list == null || list.isEmpty) return _allProducts;
    return list;
  }

  // This will be overridden by salesman.priceType (A/B/etc.) if available
  List<String> _priceTypes = const ['Retail', 'Wholesale', 'Promo'];

  bool _isLoadingMasters = false;

  @override
  void initState() {
    super.initState();

    _customerNameCtrl.text = widget.initialCustomerName ?? '';
    _customerCodeCtrl.text = widget.initialCustomerCode ?? '';
    _poNumberCtrl.text = '';

    // 🔹 Lock price type to logged-in salesman’s price_type
    final authState = ref.read(authProvider);
    final salesman = authState.salesman;
    final String? salesmanPriceType = salesman?.priceType;

    if (salesmanPriceType != null && salesmanPriceType.isNotEmpty) {
      _priceTypes = [salesmanPriceType];
      _selectedPriceType = salesmanPriceType;
    } else {
      _selectedPriceType = _priceTypes.first;
    }

    _loadMasterData();
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerCodeCtrl.dispose();
    _poNumberCtrl.dispose();
    _remarksCtrl.dispose();
    _quantityCtrl.dispose();
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
      columns: ['id', 'customer_name', 'customer_code', 'isActive'],
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

      customers.add(Customer(id: id, name: name, code: code));
    }

    customers.sort((a, b) => a.name.compareTo(b.name));

    _customers = customers;
  }

  void _showSupplierSearchDialog() async {
    final selectedSupplier = await showDialog<String>(
      context: context,
      builder: (context) => SupplierSearchDialog(suppliers: _suppliers),
    );

    if (selectedSupplier != null) {
      setState(() {
        _selectedSupplier = selectedSupplier;
        _selectedProduct = null;
      });
      _generatePoNumberForSupplier();
    }
  }

  void _showCustomerSearchDialog() async {
    final selectedCustomer = await showDialog<Customer>(
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
            });
          }
        },
      ),
    );
  }

  void _showMultiSelectProductDialog() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a supplier first')));
      return;
    }

    final selectedProducts = await showDialog<List<String>>(
      context: context,
      builder: (context) => MultiSelectProductDialog(products: _currentProducts),
    );

    if (selectedProducts != null && selectedProducts.isNotEmpty) {
      setState(() {
        for (final productDisplay in selectedProducts) {
          final meta = _productMetaByDisplay[productDisplay];
          if (meta != null) {
            // Default to PCS variant if available, otherwise use the selected one
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
                price: 1500.0, // Default price, should be calculated from product data
              ),
            );
          }
        }
      });
    }
  }

  List<String> _getAvailableUnitsForProduct(String productDisplay) {
    // For simplicity, return all variants of the same base product
    final meta = _productMetaByDisplay[productDisplay];
    if (meta == null) return [productDisplay];

    final baseId = meta.baseId ?? meta.productId;
    return _productMetaByDisplay.entries
        .where((e) => (e.value.baseId ?? e.value.productId) == baseId)
        .map((e) => e.key)
        .toList();
  }

  String _getDefaultUnitForProduct(String productDisplay) {
    // Prefer PCS variant if available
    final availableUnits = _getAvailableUnitsForProduct(productDisplay);
    for (final unit in availableUnits) {
      if (unit.contains('(PCS)') || unit.contains('PCS')) {
        return unit;
      }
    }
    return availableUnits.isNotEmpty ? availableUnits.first : productDisplay;
  }

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
      nameById[id] = name;

      final shortcut = (row['supplier_shortcut'] ?? '').toString();
      if (shortcut.isNotEmpty) shortcuts[name] = shortcut;
    }

    names.sort();

    setState(() {
      _suppliers = names;
      _supplierShortcuts = shortcuts;
      _supplierIdByName = idByName;
      _supplierNameById = nameById;
    });
  }

  // -------- UNIT SYNC (LOCAL SEED) --------

  Future<void> _seedUnitsIfEmpty(Database dbSales) async {
    // If already has units, do nothing.
    final existing = await dbSales.query('unit', columns: ['unit_id'], limit: 1);
    if (existing.isNotEmpty) return;

    debugPrint('[OrderForm] unit table is empty → seeding from API ${ApiConfig.units}');

    try {
      final unitList = await _remoteApi.fetchList(ApiConfig.units, query: {'limit': '-1'});
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
      debugPrint('[OrderForm] Seeded unit rows: ${unitList.length}');
    } catch (e) {
      debugPrint('[OrderForm] Failed to seed units: $e');
    }
  }

  // -------- UOM HELPERS --------

  String _uomLabelFromMaps(int? unitId, Map<int, String> shortcutById, Map<int, String> nameById) {
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

    bool hasWord(String w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(s);

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
      final tokens = tokenToShortcut.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

      for (final token in tokens) {
        if (d.endsWith(' $token') || d == token) {
          return tokenToShortcut[token] ?? 'UOM';
        }
      }
    }

    // Otherwise: basic keyword fallback
    return _uomFallbackFromText(description);
  }

  /// Fallback: infer count from strings like "X 24", "x24", or "15's"
  double _inferCountFromText(String text) {
    final s = text.toLowerCase();

    final m1 = RegExp(r'\bx\s*(\d+(\.\d+)?)\b').firstMatch(s);
    if (m1 != null) return double.tryParse(m1.group(1)!) ?? 1.0;

    final m2 = RegExp(r"\b(\d+)\s*'s\b").firstMatch(s);
    if (m2 != null) return double.tryParse(m2.group(1)!) ?? 1.0;

    return 1.0;
  }

  Future<void> _loadProductsFromDb() async {
    final dbSales = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

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

    try {
      productRows = await dbSales.query(
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

      ppsRows = await dbSales.query('product_per_supplier', columns: ['product_id', 'supplier_id']);

      debugPrint(
        '[OrderForm] Loaded from dbSales → products=${productRows.length}, pps=${ppsRows.length}, units=${unitRows.length}',
      );
    } catch (e) {
      debugPrint('[OrderForm] Error querying dbSales product/pps: $e');
    }

    // 4) Fallback to CUSTOMER DB if no products
    if (productRows.isEmpty) {
      final dbCustomer = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

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

    // 5) Build base-name map using parent rows (parent_id == null)
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

    // ✅ productId -> baseId map (so we can include sibling variants)
    final baseIdByProductId = <int, int>{};
    for (final row in productRows) {
      final pid = (row['product_id'] as num?)?.toInt();
      if (pid == null) continue;
      final parentId = (row['parent_id'] as num?)?.toInt();
      baseIdByProductId[pid] = parentId ?? pid;
    }

    // 6) Build display labels per product_id (variants remain distinct)
    final productIdByDisplay = <String, int>{};
    final displayByProductId = <int, String>{};
    final productMetaByDisplay = <String, _ProductVariantMeta>{};
    final allDisplays = <String>[];

    // baseId -> list of all variant displays
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

      // ✅ UOM: prefer unit master; fallback to parsing text
      var uom = (uomId != null)
          ? _uomLabelFromMaps(uomId, unitShortcutById, unitNameById)
          : _uomLabelFromDescription(desc, unitShortcutById, unitNameById);

      // If still generic, try product name too
      if (uom.toUpperCase() == 'UOM') {
        uom = _uomFallbackFromText('$pname $desc');
      }

      // ✅ Count: prefer unit_of_measurement_count; fallback to parse text
      if (count <= 1) {
        final inferred1 = _inferCountFromText(pname);
        if (inferred1 > 1) {
          count = inferred1;
        } else {
          final inferred2 = _inferCountFromText(desc);
          if (inferred2 > 1) count = inferred2;
        }
      }

      // ✅ Salesman-friendly variant label:
      // - If PCS and count>1 => "10 PCS" (not "PCS x10")
      // - Otherwise count>1 => "BOX x10" (unit name is visible)
      // - count<=1 => "PCS" or "BOX"
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

      // Ensure display unique
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

    // 7) Build products per supplier using display labels
    //
    // ✅ FIX:
    // If product_per_supplier maps only the base/PCS product_id, we still include
    // ALL sibling variants (BOX/CASE/etc.) that share the same baseId.
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

    // 8) If no mapping, fallback: allow all products for each supplier
    if (productsBySupplierName.isEmpty && allDisplays.isNotEmpty) {
      debugPrint(
        '[OrderForm] No product_per_supplier mapping found. Fallback: all products for each supplier.',
      );

      for (final supplierName in _supplierNameById.values) {
        productsBySupplierName[supplierName] = List<String>.from(allDisplays);
      }
    }

    // 9) Update state
    setState(() {
      _unitShortcutById = unitShortcutById;
      _unitNameById = unitNameById;

      _productIdByDisplay = productIdByDisplay;
      _productMetaByDisplay = productMetaByDisplay;

      _allProducts = allDisplays;
      _productsBySupplier = productsBySupplierName;
    });

    debugPrint(
      '[OrderForm] _allProducts=${_allProducts.length}, suppliersWithMapping=${_productsBySupplier.length}',
    );
  }

  Future<void> _openCallsheetCapture() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CallsheetCapturePage()));

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
        await db.execute('ALTER TABLE sales_order ADD COLUMN salesman_id INTEGER');
      }
      if (!existingColumns.contains('is_synced')) {
        await db.execute('ALTER TABLE sales_order ADD COLUMN is_synced INTEGER DEFAULT 0');
      }
    } catch (e) {
      debugPrint('Error migrating sales_order table: $e');
    }
  }

  void _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add at least one product to the cart')));
      return;
    }

    final now = DateTime.now();
    final supplierId = (_selectedSupplier != null) ? _supplierIdByName[_selectedSupplier!] : null;
    final authState = ref.read(authProvider);
    final salesmanId = authState.salesman?.id ?? authState.user?.userId;

    // Create order header
    final order = OrderModel(
      orderNo: _poNumberCtrl.text.trim(),
      poNo: _poNumberCtrl.text.trim(), // Using same for now, or add separate field if needed
      customerName: _customerNameCtrl.text.trim(),
      customerCode: _customerCodeCtrl.text.trim(),
      salesmanId: salesmanId,
      supplierId: supplierId,
      orderDate: now,
      createdAt: now,
      totalAmount: _grandTotal,
      netAmount: _grandTotal, // Assuming no global discount for now
      status: 'Pending',
      type: OrderType.manual,
      supplier: _selectedSupplier,
      priceType: _selectedPriceType,
      hasAttachment: _callsheetImagePath != null,
      callsheetImagePath: _callsheetImagePath,
      remarks: _remarksCtrl.text.trim(),
    );

    try {
      final db = await DatabaseManager().getDatabase(DatabaseManager.dbSales);

      // 1. Ensure tables exist
      await _ensureSalesTablesExist(db);

      // 2. Insert Header
      final headerRow = order.toSqlite();
      // Remove ID to let SQLite auto-increment
      headerRow.remove('id');
      // Remove fields not in table
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

      // 3. Insert Details
      final batch = db.batch();
      for (final item in _cartItems) {
        batch.insert('sales_order_details', {
          'order_id': newOrderId,
          'product_id': item.productId,
          'unit_price': item.price,
          'ordered_quantity': item.quantity,
          'gross_amount': item.total,
          'net_amount': item.total, // Assuming no line discount
          'created_date': now.toIso8601String(),
          'remarks': '',
        });
      }
      await batch.commit(noResult: true);

      // 4. Update Provider State (Optional, for UI refresh)
      // We create a copy with the new ID to add to the list
      // ref.read(orderListProvider.notifier).addOrder(order);

      final summary = StringBuffer()
        ..writeln('Order Type: Manual')
        ..writeln('Customer: ${order.customerName} (${order.customerCode})')
        ..writeln('PO No: ${order.orderNo}')
        ..writeln('Supplier: ${order.supplier}')
        ..writeln('Price Type: ${order.priceType}')
        ..writeln('Remarks: ${order.remarks}')
        ..writeln('Items: ${_cartItems.length}')
        ..writeln('Total: ₱${order.totalAmount.toStringAsFixed(2)}')
        ..writeln('Attachment: ${order.hasAttachment ? "Yes" : "No"}')
        ..writeln('')
        ..writeln('Order Details:');

      for (final item in _cartItems) {
        summary.writeln(
          '- ${item.productDisplay}: ${item.quantity} x ₱${item.price.toStringAsFixed(2)} = ₱${item.total.toStringAsFixed(2)}',
        );
      }

      // Clear the form
      setState(() {
        _cartItems.clear();
        _selectedSupplier = null;
        _customerNameCtrl.clear();
        _customerCodeCtrl.clear();
        _poNumberCtrl.clear();
        _remarksCtrl.clear();
        _callsheetImagePath = null;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Order Saved'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(summary.toString(), style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error saving order: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error saving order. Please try again.')));
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
      appBar: AppBar(title: const Text('Create New Order'), centerTitle: false, elevation: 0),
      body: _isLoadingMasters
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading data...', style: TextStyle(color: AppColors.textMuted)),
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
                            _buildSectionHeader('Customer Information', icon: Icons.person_outline),
                            InkWell(
                              onTap: _showCustomerSearchDialog,
                              child: IgnorePointer(
                                child: TextFormField(
                                  controller: _customerNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name',
                                    hintText: 'Tap to search customers',
                                    prefixIcon: const Icon(Icons.person, size: 20),
                                    suffixIcon: const Icon(Icons.search, size: 20),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppColors.border),
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
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
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
                            _buildSectionHeader('Sales Order', icon: Icons.receipt_long),
                            TextFormField(
                              controller: _poNumberCtrl,
                              decoration: InputDecoration(
                                labelText: 'SO Number',
                                hintText: 'Auto-generated after supplier selection',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
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
                                prefixIcon: const Icon(Icons.notes, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                              ),
                              maxLines: 3,
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
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                  ),
                                ],
                              ),
                            ),

                            // Supplier Selection
                            DropdownButtonFormField<String>(
                              initialValue:
                                  (_selectedSupplier != null &&
                                      _suppliers.contains(_selectedSupplier))
                                  ? _selectedSupplier
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Supplier',
                                hintText: 'Select supplier',
                                prefixIcon: const Icon(Icons.storefront, size: 20),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                              ),
                              items: _suppliers
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedSupplier = val;
                                  _selectedProduct = null;
                                });
                                _generatePoNumberForSupplier();
                              },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'Supplier is required';
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Add Products Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _showMultiSelectProductDialog,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Add Products'),
                                style: ElevatedButton.styleFrom(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    _cartItems.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  initialValue: item.selectedUnitDisplay,
                                                  decoration: InputDecoration(
                                                    labelText: 'Unit/Packaging',
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                  ),
                                                  items:
                                                      _getAvailableUnitsForProduct(
                                                            item.productDisplay,
                                                          )
                                                          .map(
                                                            (unit) => DropdownMenuItem(
                                                              value: unit,
                                                              child: Text(unit),
                                                            ),
                                                          )
                                                          .toList(),
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      setState(() {
                                                        _cartItems[index] = item.copyWith(
                                                          selectedUnitDisplay: value,
                                                        );
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: item.quantity.toString(),
                                                  keyboardType: TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: 'Quantity',
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                  ),
                                                  onChanged: (value) {
                                                    final qty = int.tryParse(value) ?? 1;
                                                    setState(() {
                                                      _cartItems[index] = item.copyWith(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Grand Total:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
