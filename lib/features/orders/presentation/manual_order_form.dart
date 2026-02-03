import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ManualOrderFormBody extends StatelessWidget {
  const ManualOrderFormBody({
    super.key,
    required this.suppliers,

    /// "products" is the full list of product display strings
    /// for the currently selected supplier (includes variants like BOX/PACK/PCS).
    required this.products,

    required this.priceTypes, // kept for signature compatibility (unused)
    required this.selectedSupplier,

    /// selectedProduct should be the selected VARIANT display string
    /// e.g. "Richeese Wafer ... (PCS)" or "(BOX x10)" or "(10 PCS)".
    required this.selectedProduct,

    required this.selectedPriceType, // kept (unused)
    required this.quantityCtrl,
    required this.onSupplierChanged,
    required this.onProductChanged,
    required this.onPriceTypeChanged, // kept (unused)
    this.onShowSupplierSearch,
  });

  final List<String> suppliers;
  final List<String> products;
  final List<String> priceTypes;

  final String? selectedSupplier;
  final String? selectedProduct;
  final String? selectedPriceType;

  final TextEditingController quantityCtrl;
  final ValueChanged<String?> onSupplierChanged;

  /// Receives the selected VARIANT display string
  final ValueChanged<String?> onProductChanged;

  final ValueChanged<String?> onPriceTypeChanged;

  /// Callback to show supplier search dialog
  final VoidCallback? onShowSupplierSearch;

  // Expected display format examples:
  //   "Base Name (PCS)"
  //   "Base Name (BOX x10)"
  //   "Base Name (10 PCS)"
  String _baseKeyFromDisplay(String display) {
    final idx = display.lastIndexOf(' (');
    if (idx <= 0) return display.trim();
    return display.substring(0, idx).trim();
  }

  String _unitLabelFromDisplay(String display) {
    final start = display.lastIndexOf('(');
    final end = display.lastIndexOf(')');
    if (start == -1 || end == -1 || end <= start) return '';
    return display.substring(start + 1, end).trim(); // e.g. "BOX x10" or "10 PCS"
  }

  bool _isPcsVariantLabel(String unitLabel) {
    // Accept "PCS", "10 PCS", "PCS x10", etc.
    return RegExp(r'\bPCS\b', caseSensitive: false).hasMatch(unitLabel);
  }

  /// Salesman-friendly label for the Unit/Packaging dropdown.
  ///
  /// Input examples (inside parentheses):
  /// - "PCS"            -> "PCS"
  /// - "10 PCS"         -> "10 PCS"
  /// - "BOX"            -> "BOX"
  /// - "BOX x10"        -> "BOX (10 PCS)"
  /// - "CARTON x200"    -> "CARTON (200 PCS)"
  ///
  /// This avoids the confusing "UOM x 10" presentation while still showing
  /// the real unit name and (when available) the pack content in PCS.
  String _prettyPackagingLabel(String display) {
    final raw = _unitLabelFromDisplay(display);
    if (raw.isEmpty) return '';

    final s = raw.trim();

    // "10 PCS" style (already good)
    final numPcs = RegExp(r'^(\d+(\.\d+)?)\s+PCS$', caseSensitive: false).firstMatch(s);
    if (numPcs != null) return s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    // "UNIT x10" style -> "UNIT (10 PCS)"
    final unitXCount = RegExp(
      r'^([A-Za-z]+)\s*x\s*(\d+(\.\d+)?)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (unitXCount != null) {
      final unit = (unitXCount.group(1) ?? '').trim().toUpperCase();
      final count = (unitXCount.group(2) ?? '').trim();
      if (unit.isEmpty || count.isEmpty) return s;
      // Keep unit name visible; show pack content in PCS to reduce salesman confusion.
      return '$unit ($count PCS)';
    }

    // Default: show whatever unit name the product already provides (e.g., "BOX", "CARTON")
    return s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    // Build base -> variants map (DEDUPED)
    final Map<String, Set<String>> variantsByBaseSet = {};

    for (final p in products) {
      final base = _baseKeyFromDisplay(p);
      if (base.isEmpty) continue;
      variantsByBaseSet.putIfAbsent(base, () => <String>{});
      variantsByBaseSet[base]!.add(p);
    }

    final List<String> parentProducts = variantsByBaseSet.keys.toList()..sort();

    // Determine selected base from current selected variant
    String? selectedBase;
    if (selectedProduct != null) {
      final base = _baseKeyFromDisplay(selectedProduct!);
      if (variantsByBaseSet.containsKey(base)) selectedBase = base;
    }

    // Packaging options for selected base
    final List<String> packagingOptions =
        (selectedBase != null
              ? (variantsByBaseSet[selectedBase]?.toList() ?? <String>[])
              : <String>[])
          ..sort();

    // Ensure currently selected variant exists in packaging list
    final String? effectiveSelectedVariant =
        (selectedProduct != null && packagingOptions.contains(selectedProduct))
        ? selectedProduct
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SUPPLIER
        DropdownButtonFormField<String>(
          initialValue: (selectedSupplier != null && suppliers.contains(selectedSupplier))
              ? selectedSupplier
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
          items: suppliers
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onSupplierChanged,
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Supplier is required';
            return null;
          },
        ),

        const SizedBox(height: 16),

        // PARENT PRODUCT
        DropdownButtonFormField<String>(
          initialValue: selectedBase,
          decoration: InputDecoration(
            labelText: 'Product',
            hintText: parentProducts.isEmpty ? 'No products for this supplier' : 'Select product',
            prefixIcon: const Icon(Icons.inventory_2, size: 20),
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
          items: parentProducts
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p,
                  child: Text(p, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: parentProducts.isEmpty
              ? null
              : (base) {
                  if (base == null) {
                    onProductChanged(null);
                    return;
                  }

                  final variants = (variantsByBaseSet[base]?.toList() ?? <String>[])..sort();

                  // Prefer PCS variant if present, else pick first.
                  String? defaultVariant;
                  for (final v in variants) {
                    final unitLabel = _unitLabelFromDisplay(v);
                    if (_isPcsVariantLabel(unitLabel)) {
                      defaultVariant = v;
                      break;
                    }
                  }
                  defaultVariant ??= variants.isNotEmpty ? variants.first : null;

                  onProductChanged(defaultVariant);
                },
          validator: (val) {
            if (parentProducts.isEmpty) return null; // nothing to select
            if (val == null || val.trim().isEmpty) return 'Product is required';
            return null;
          },
        ),

        const SizedBox(height: 16),

        // UNIT / PACKAGING (VARIANT)
        DropdownButtonFormField<String>(
          initialValue: effectiveSelectedVariant,
          decoration: InputDecoration(
            labelText: 'Unit / Packaging',
            hintText: selectedBase == null
                ? 'Select product first'
                : (packagingOptions.isEmpty ? 'No packaging options' : 'Select unit'),
            prefixIcon: const Icon(Icons.widgets_outlined, size: 20),
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
          items: packagingOptions
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(
                    _prettyPackagingLabel(v), // e.g. "PCS", "10 PCS", "BOX (10 PCS)"
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (selectedBase == null || packagingOptions.isEmpty) ? null : onProductChanged,
          validator: (val) {
            if (selectedBase == null) return 'Select a product first';
            if (packagingOptions.isEmpty) return 'No packaging options available';
            if (val == null || val.trim().isEmpty) return 'Unit/Packaging is required';
            return null;
          },
        ),

        const SizedBox(height: 16),

        // QUANTITY
        TextFormField(
          controller: quantityCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: 'Enter quantity',
            prefixIcon: const Icon(Icons.confirmation_number, size: 20),
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
            if (val == null || val.trim().isEmpty) return 'Quantity is required';
            final q = int.tryParse(val);
            if (q == null || q <= 0) return 'Enter a valid quantity';
            return null;
          },
        ),
      ],
    );
  }
}
