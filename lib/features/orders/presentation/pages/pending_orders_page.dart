import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vos_sfa_go/core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/orders/data/repositories/order_repository.dart';
import 'package:vos_sfa_go/features/orders/presentation/order_form.dart';
import 'package:vos_sfa_go/features/orders/presentation/widgets/modals/customer_picker_modal.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';
import 'package:vos_sfa_go/data/models/customer_model.dart';
import 'package:vos_sfa_go/data/models/order_model.dart';

class PendingOrdersPage extends ConsumerStatefulWidget {
  const PendingOrdersPage({super.key});

  @override
  ConsumerState<PendingOrdersPage> createState() => _PendingOrdersPageState();
}

class _PendingOrdersPageState extends ConsumerState<PendingOrdersPage> {
  Customer? _selectedCustomer;
  bool _isLoading = false;
  List<OrderModel> _pendingOrders = [];
  final OrderRepository _orderRepository =
      OrderRepository(); // Direct instantiation for now
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseManager().getDatabase(
        DatabaseManager.dbCustomer,
      );
      final rows = await db.query(
        'customer',
        columns: ['id', 'customer_name', 'customer_code', 'isActive'],
        orderBy: 'customer_name ASC',
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
      _customers = customers;
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingOrders() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);
    try {
      final orders = await _orderRepository.getPendingOrdersByCustomer(
        _selectedCustomer!.code,
      );
      if (mounted) {
        setState(() {
          _pendingOrders = orders;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete order ${order.orderNo}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && order.orderId != null) {
      await _orderRepository.deleteOrder(
        order.orderId!,
      ); // Using orderId (sales_order PK)
      _loadPendingOrders();
    } else if (confirmed == true && order.id != null) {
      // fallback if orderId is null but id is present (local id)
      await _orderRepository.deleteOrder(order.id!);
      _loadPendingOrders();
    }
  }

  void _editOrder(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderFormPage(initialOrder: order),
      ),
    );
    _loadPendingOrders(); // Refresh after return
  }

  void _showCustomerPicker() {
    showDialog(
      context: context,
      builder: (context) => CustomerPickerModal(
        customers: _customers,
        selectedCustomer: _selectedCustomer,
        onCustomerSelected: (customer) {
          if (customer != null) {
            setState(() {
              _selectedCustomer = customer;
            });
            _loadPendingOrders();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Customer Selector Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: _showCustomerPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCustomer?.name ?? 'Select Customer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),

          // Order List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedCustomer == null
                ? const Center(
                    child: Text(
                      'Please select a customer to view pending orders',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _pendingOrders.isEmpty
                ? const Center(child: Text('No pending orders found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingOrders.length,
                    itemBuilder: (context, index) {
                      final order = _pendingOrders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order.orderNo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(order.orderDate),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    NumberFormat.currency(
                                      symbol: '₱',
                                    ).format(order.totalAmount),
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Unsynced',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _deleteOrder(order),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _editOrder(order),
                                    icon: const Icon(Icons.edit, size: 20),
                                    label: const Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
