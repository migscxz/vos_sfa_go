// lib/features/orders/presentation/order_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../callsheet/presentation/callsheet_capture_page.dart';

import 'package:vos_sfa_go/core/database/database_manager.dart';
import 'package:vos_sfa_go/core/api/global_remote_api.dart';
import 'package:vos_sfa_go/core/api/api_config.dart';

import 'package:vos_sfa_go/features/orders/presentation/manual_order_form.dart';
import 'callsheet_order_form_body.dart';

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

  OrderType _orderType = OrderType.manual;

  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerCodeCtrl = TextEditingController();
  final TextEditingController _poNumberCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  String? _selectedSupplier;
  String? _selectedProduct; // display string (variant)
  String? _selectedPriceType;
  String? _callsheetImagePath;

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
    _orderType = widget.initialType ?? OrderType.manual;
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
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoadingMasters = true);

    try {
      await _loadSuppliersFromDb();
      await _loadProductsFromDb();
    } catch (e) {
      debugPrint('Error loading master data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMasters = false);
    }
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
        final sortOrder = (sortOrderRaw is num) ? sortOrderRaw.toInt() : int.tryParse('$sortOrderRaw');

        final row = <String, Object?>{
          'unit_id': unitId,
          'unit_name': (m['unit_name'] ?? '').toString(),
          'unit_shortcut': (m['unit_shortcut'] ?? '').toString(),
          'sort_order': sortOrder,
        };

        batch.insert(
          'unit',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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

      final baseName = baseNameByBaseId[baseId] ??
          (row['product_name'] ?? '').toString().trim();
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
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CallsheetCapturePage(),
      ),
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

  void _saveOrder() {
    if (!_formKey.currentState!.validate()) return;

    if (_orderType == OrderType.callsheet && _callsheetImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture or attach a photo for callsheet order.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final int quantity = int.tryParse(_quantityCtrl.text) ?? 1;
    final double estimatedTotal = quantity * 1500.00;

    final selectedDisplay = _selectedProduct;
    final meta = (selectedDisplay != null)
        ? _productMetaByDisplay[selectedDisplay]
        : null;

    final supplierId =
    (_selectedSupplier != null) ? _supplierIdByName[_selectedSupplier!] : null;

    final order = OrderModel(
      orderNo: _poNumberCtrl.text.trim(),
      customerName: _customerNameCtrl.text.trim(),
      customerCode: _customerCodeCtrl.text.trim(),
      createdAt: now,
      totalAmount: estimatedTotal,
      status: 'Pending',
      type: _orderType,

      supplier: _selectedSupplier,
      supplierId: supplierId,

      product: selectedDisplay,
      productId: meta?.productId,
      productBaseId: meta?.baseId,
      unitId: meta?.unitId,
      unitCount: meta?.unitCount,

      priceType: _selectedPriceType,
      quantity: quantity,

      hasAttachment: _callsheetImagePath != null,
      callsheetImagePath: _callsheetImagePath,
    );

    ref.read(orderListProvider.notifier).addOrder(order);

    final summary = StringBuffer()
      ..writeln('Order Type: ${_orderType == OrderType.manual ? "Manual" : "Callsheet"}')
      ..writeln('Customer: ${order.customerName} (${order.customerCode})')
      ..writeln('PO No: ${order.orderNo}')
      ..writeln('Supplier: ${order.supplier}')
      ..writeln('Product: ${order.product}')
      ..writeln('Price Type: ${order.priceType}')
      ..writeln('Quantity: ${order.quantity}')
      ..writeln('Total: ₱${order.totalAmount.toStringAsFixed(2)}')
      ..writeln('Attachment: ${order.hasAttachment ? "Yes" : "No"}');

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
        content: Text(
          summary.toString(),
          style: const TextStyle(fontSize: 14, height: 1.5),
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

  Widget _buildOrderTypeSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildOrderTypeChip(
              label: 'Manual Order',
              icon: Icons.edit_note,
              isSelected: _orderType == OrderType.manual,
              onTap: () => setState(() => _orderType = OrderType.manual),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildOrderTypeChip(
              label: 'Callsheet Order',
              icon: Icons.camera_alt,
              isSelected: _orderType == OrderType.callsheet,
              onTap: () => setState(() => _orderType = OrderType.callsheet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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
                // Order Type
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
                      _buildSectionHeader('Order Type', icon: Icons.list_alt),
                      _buildOrderTypeSelector(theme),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

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
                      TextFormField(
                        controller: _customerNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          hintText: 'Enter customer name',
                          prefixIcon: const Icon(Icons.person, size: 20),
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
                            Icon(Icons.local_offer_outlined,
                                size: 18, color: AppColors.textMuted),
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

                      if (_orderType == OrderType.manual)
                        ManualOrderFormBody(
                          suppliers: _suppliers,
                          products: _currentProducts,
                          priceTypes: _priceTypes,
                          selectedSupplier: _selectedSupplier,
                          selectedProduct: _selectedProduct,
                          selectedPriceType: _selectedPriceType,
                          quantityCtrl: _quantityCtrl,
                          onSupplierChanged: (val) {
                            setState(() {
                              _selectedSupplier = val;
                              _selectedProduct = null;
                            });
                            _generatePoNumberForSupplier();
                          },
                          onProductChanged: (val) {
                            setState(() => _selectedProduct = val);
                          },
                          onPriceTypeChanged: (val) {},
                        )
                      else
                        CallsheetOrderFormBody(
                          suppliers: _suppliers,
                          products: _currentProducts,
                          priceTypes: _priceTypes,
                          selectedSupplier: _selectedSupplier,
                          selectedProduct: _selectedProduct,
                          selectedPriceType: _selectedPriceType,
                          quantityCtrl: _quantityCtrl,
                          callsheetImagePath: _callsheetImagePath,
                          onSupplierChanged: (val) {
                            setState(() {
                              _selectedSupplier = val;
                              _selectedProduct = null;
                            });
                            _generatePoNumberForSupplier();
                          },
                          onProductChanged: (val) {
                            setState(() => _selectedProduct = val);
                          },
                          onPriceTypeChanged: (val) {},
                          onCaptureCallsheet: _openCallsheetCapture,
                        ),
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
