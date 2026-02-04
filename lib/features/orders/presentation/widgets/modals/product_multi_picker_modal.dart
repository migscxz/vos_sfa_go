import 'package:flutter/material.dart';

class ProductMultiPickerModal extends StatefulWidget {
  final List<String> products;
  final List<String> selectedProducts;
  final ValueChanged<List<String>> onProductsSelected;

  const ProductMultiPickerModal({
    super.key,
    required this.products,
    required this.selectedProducts,
    required this.onProductsSelected,
  });

  @override
  State<ProductMultiPickerModal> createState() => _ProductMultiPickerModalState();
}

class _ProductMultiPickerModalState extends State<ProductMultiPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  late Set<String> _selectedProducts;

  @override
  void initState() {
    super.initState();
    _selectedProducts = Set<String>.from(widget.selectedProducts);
    _searchCtrl.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterProducts() {
    // Filtering is handled in the build method
    setState(() {});
  }

  List<String> get _filteredProducts {
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) return widget.products;
    return widget.products.where((product) {
      return product.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Products'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            widget.onProductsSelected(_selectedProducts.toList());
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
