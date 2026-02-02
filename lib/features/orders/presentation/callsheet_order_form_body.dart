import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CallsheetOrderFormBody extends StatelessWidget {
  const CallsheetOrderFormBody({
    super.key,
    required this.suppliers,
    required this.products,
    required this.priceTypes, // kept for signature compatibility (unused)
    required this.selectedSupplier,
    required this.selectedProduct,
    required this.selectedPriceType, // kept (unused)
    required this.quantityCtrl,
    required this.callsheetImagePath,
    required this.onSupplierChanged,
    required this.onProductChanged,
    required this.onPriceTypeChanged, // kept (unused)
    required this.onCaptureCallsheet,
  });

  final List<String> suppliers;

  /// VARIANT display strings:
  ///  "Base Name (PCS)"
  ///  "Base Name (BOX x10)"
  ///  "Base Name (PACK x24)"
  ///  "Base Name (10 PCS)"
  final List<String> products;

  final List<String> priceTypes;
  final String? selectedSupplier;
  final String? selectedProduct;
  final String? selectedPriceType;

  final TextEditingController quantityCtrl;
  final String? callsheetImagePath;

  final ValueChanged<String?> onSupplierChanged;
  final ValueChanged<String?> onProductChanged;
  final ValueChanged<String?> onPriceTypeChanged;

  final VoidCallback onCaptureCallsheet;

  // -------- Helpers (display parsing) --------
  String _baseKeyFromDisplay(String display) {
    final idx = display.lastIndexOf(' (');
    if (idx <= 0) return display.trim();
    return display.substring(0, idx).trim();
  }

  String _unitLabelFromDisplay(String display) {
    final start = display.lastIndexOf('(');
    final end = display.lastIndexOf(')');
    if (start == -1 || end == -1 || end <= start) return '';
    return display.substring(start + 1, end).trim(); // e.g. "BOX x10"
  }

  bool _isPcsVariantLabel(String unitLabel) {
    return RegExp(r'\bPCS\b', caseSensitive: false).hasMatch(unitLabel);
  }

  /// Salesman-friendly label for Unit/Packaging dropdown.
  /// - "PCS"         -> "PCS"
  /// - "10 PCS"      -> "10 PCS"
  /// - "BOX x10"     -> "BOX (10 PCS)"
  /// - "CARTON x200" -> "CARTON (200 PCS)"
  /// - "BOX"         -> "BOX"
  String _prettyPackagingLabel(String display) {
    final raw = _unitLabelFromDisplay(display);
    if (raw.isEmpty) return '';

    final s = raw.trim();

    // already "10 PCS"
    final numPcs =
    RegExp(r'^(\d+(\.\d+)?)\s+PCS$', caseSensitive: false).firstMatch(s);
    if (numPcs != null) {
      return s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }

    // "UNIT x10" -> "UNIT (10 PCS)"
    final unitXCount =
    RegExp(r'^([A-Za-z]+)\s*x\s*(\d+(\.\d+)?)$', caseSensitive: false)
        .firstMatch(s);
    if (unitXCount != null) {
      final unit = (unitXCount.group(1) ?? '').trim().toUpperCase();
      final count = (unitXCount.group(2) ?? '').trim();
      if (unit.isEmpty || count.isEmpty) return s;
      return '$unit ($count PCS)';
    }

    return s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    // 1) Group variants by base (DEDUPED)
    final Map<String, Set<String>> variantsByBaseSet = {};
    for (final p in products) {
      final base = _baseKeyFromDisplay(p);
      if (base.isEmpty) continue;
      variantsByBaseSet.putIfAbsent(base, () => <String>{});
      variantsByBaseSet[base]!.add(p);
    }

    final List<String> parentProducts = variantsByBaseSet.keys.toList()..sort();

    // 2) Determine selected base (based on selected variant)
    String? selectedBase;
    if (selectedProduct != null) {
      final base = _baseKeyFromDisplay(selectedProduct!);
      if (variantsByBaseSet.containsKey(base)) selectedBase = base;
    }

    // 3) Packaging options for selected parent
    final List<String> packagingOptions =
    (selectedBase != null
        ? (variantsByBaseSet[selectedBase]?.toList() ?? <String>[])
        : <String>[])
      ..sort();

    // 4) Ensure selected variant is valid for current packaging list
    final String? effectiveSelectedVariant =
    (selectedProduct != null && packagingOptions.contains(selectedProduct))
        ? selectedProduct
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SUPPLIER
        DropdownButtonFormField<String>(
          value: (selectedSupplier != null && suppliers.contains(selectedSupplier))
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
              .map((s) => DropdownMenuItem<String>(
            value: s,
            child: Text(s, overflow: TextOverflow.ellipsis),
          ))
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
          value: selectedBase,
          decoration: InputDecoration(
            labelText: 'Product',
            hintText:
            parentProducts.isEmpty ? 'No products for this supplier' : 'Select product',
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
              .map((p) => DropdownMenuItem<String>(
            value: p,
            child: Text(p, overflow: TextOverflow.ellipsis),
          ))
              .toList(),
          onChanged: parentProducts.isEmpty
              ? null
              : (base) {
            if (base == null) {
              onProductChanged(null);
              return;
            }

            final variants = (variantsByBaseSet[base]?.toList() ?? <String>[])..sort();

            // Prefer PCS as default
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
            if (parentProducts.isEmpty) return null;
            if (val == null || val.trim().isEmpty) return 'Product is required';
            return null;
          },
        ),

        const SizedBox(height: 16),

        // UNIT / PACKAGING
        DropdownButtonFormField<String>(
          value: effectiveSelectedVariant,
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
              .map((v) => DropdownMenuItem<String>(
            value: v,
            child: Text(
              _prettyPackagingLabel(v), // "PCS", "10 PCS", "BOX (10 PCS)"
              overflow: TextOverflow.ellipsis,
            ),
          ))
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

        const SizedBox(height: 24),

        // CALLSHEET PHOTO
        Text(
          'Callsheet Photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            ElevatedButton.icon(
              onPressed: onCaptureCallsheet,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Capture / Attach'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: (callsheetImagePath != null && callsheetImagePath!.isNotEmpty)
                  ? Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Photo attached',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
                  : Text(
                'No photo attached yet',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (callsheetImagePath != null && callsheetImagePath!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              height: 160,
              width: double.infinity,
              child: Image.file(
                File(callsheetImagePath!),
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}
