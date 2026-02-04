import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/customer_model.dart';

class CustomerPickerModal extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer?> onCustomerSelected;

  const CustomerPickerModal({
    super.key,
    required this.customers,
    this.selectedCustomer,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerPickerModal> createState() => _CustomerPickerModalState();
}

class _CustomerPickerModalState extends State<CustomerPickerModal> {
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
                  final isSelected = widget.selectedCustomer?.id == customer.id;
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text(customer.code),
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withOpacity(0.1),
                    onTap: () {
                      widget.onCustomerSelected(customer);
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
