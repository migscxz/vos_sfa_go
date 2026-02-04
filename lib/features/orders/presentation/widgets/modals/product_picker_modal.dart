import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/product_model.dart';

class ProductPickerModal extends StatefulWidget {
  final List<Product> products;
  final String priceType; // 'Retail', 'Wholesale', etc.
  final ValueChanged<List<ProductSelection>> onProductsSelected;

  const ProductPickerModal({
    super.key,
    required this.products,
    required this.priceType,
    required this.onProductsSelected,
  });

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

/// Helper class to pass back selection
class ProductSelection {
  final Product product;
  final int quantity;
  ProductSelection(this.product, this.quantity);
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Product> _filteredProducts = [];

  // Track quantities: productId -> value
  final Map<int, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchCtrl.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredProducts = widget.products);
    } else {
      setState(() {
        _filteredProducts = widget.products.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.code.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  void _increment(Product p) {
    setState(() {
      final current = _quantities[p.id] ?? 0;
      _quantities[p.id] = current + 1;
    });
  }

  void _decrement(Product p) {
    setState(() {
      final current = _quantities[p.id] ?? 0;
      if (current > 0) {
        _quantities[p.id] = current - 1;
        if (_quantities[p.id] == 0) {
          _quantities.remove(p.id);
        }
      }
    });
  }

  void _onDone() {
    final selections = <ProductSelection>[];
    _quantities.forEach((pid, qty) {
      if (qty > 0) {
        final product = widget.products.firstWhere((p) => p.id == pid);
        selections.add(ProductSelection(product, qty));
      }
    });
    widget.onProductsSelected(selections);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Re-introduce totalItems for footer display
    final totalItems = _quantities.values.fold(0, (sum, q) => sum + q);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Product List
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final qty = _quantities[product.id] ?? 0;

                        final price = product.getPrice(widget.priceType);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: qty > 0
                                ? AppColors.primary.withOpacity(0.05)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: qty > 0
                                  ? AppColors.primary
                                  : Colors.grey[200]!,
                              width: qty > 0 ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: qty > 0
                                            ? AppColors.primary
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildTag(
                                          product.code,
                                          Colors.grey[200]!,
                                          Colors.grey[700]!,
                                        ),
                                        const SizedBox(width: 8),
                                        if (product.uom.isNotEmpty) ...[
                                          _buildTag(
                                            product.uom,
                                            Colors.blue[50]!,
                                            Colors.blue[700]!,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          '₱${price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${widget.priceType.toUpperCase().replaceAll('PRICE', '')})',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Quantity Controls
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: qty > 0
                                          ? () => _decrement(product)
                                          : null,
                                      color: qty > 0 ? Colors.red : Colors.grey,
                                      splashRadius: 20,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                    Container(
                                      width: 32,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () => _increment(product),
                                      color: Colors.green,
                                      splashRadius: 20,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalItems items selected',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          // Optional: Show total value here if needed
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: totalItems > 0 ? _onDone : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add to Order'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
