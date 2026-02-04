import 'package:flutter/material.dart';

class SupplierPickerModal extends StatefulWidget {
  final List<String> suppliers;
  final String? selectedSupplier;
  final ValueChanged<String?> onSupplierSelected;

  const SupplierPickerModal({
    super.key,
    required this.suppliers,
    this.selectedSupplier,
    required this.onSupplierSelected,
  });

  @override
  State<SupplierPickerModal> createState() => _SupplierPickerModalState();
}

class _SupplierPickerModalState extends State<SupplierPickerModal> {
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
                  final isSelected = widget.selectedSupplier == supplier;
                  return ListTile(
                    title: Text(supplier),
                    selected: isSelected,
                    selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    onTap: () {
                      widget.onSupplierSelected(supplier);
                      Navigator.of(context).pop();
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
      ],
    );
  }
}
