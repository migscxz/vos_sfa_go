import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vos_sfa_go/core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/orders/data/models/cart_item_model.dart';

import '../../../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.orderTemplate,
    required this.initialItems,
  });

  final OrderModel orderTemplate;
  final List<CartItem> initialItems;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late List<CartItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _updateQuantity(int index, int newQty) {
    if (newQty < 1) return;
    setState(() {
      final old = _items[index];
      _items[index] = old.copyWith(quantity: newQty);
    });
  }

  void _itemsDelete(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _processCheckout() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      Navigator.pop(context); // Go back to add items
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Prepare final order model
      final now = DateTime.now();
      final finalOrder = widget.orderTemplate.copyWith(
        status: 'For Approval',
        forApprovalAt: now.toIso8601String(),
        // Recalculate totals based on _items in case quantity changed in checkout
        totalAmount: _calculateGrossTotal(),
        discountAmount: _calculateDiscountTotal(),
        netAmount: _calculateNetTotal(),
        // Logic for single fields if needed, or keep from template
        // quantity: _items.length, // Already in template or calculated?
        // Logic for single qty in header:
        quantity: _items.length,
      );

      final repo = OrderRepository();
      await repo.saveOrder(finalOrder, _items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving order: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Discount Display
                            if (item.originalPrice != null &&
                                item.originalPrice! > item.price) ...[
                              Row(
                                children: [
                                  Text(
                                    '${item.selectedUnitDisplay} • ',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    currency.format(item.originalPrice),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    currency.format(item.price),
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '${item.selectedUnitDisplay} • ${currency.format(item.price)}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Quantity Controls
                            Row(
                              children: [
                                _QuantityButton(
                                  icon: Icons.remove,
                                  onTap: () =>
                                      _updateQuantity(index, item.quantity - 1),
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                  ),
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _QuantityButton(
                                  icon: Icons.add,
                                  onTap: () =>
                                      _updateQuantity(index, item.quantity + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Total & Delete
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(item.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _itemsDelete(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Bottom Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal (Gross)',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        currency.format(_calculateGrossTotal()),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Less: Discount',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                      Text(
                        '-${currency.format(_calculateDiscountTotal())}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        currency.format(_calculateNetTotal()), // Use Net
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _processCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirm Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateGrossTotal() {
    return _items.fold(0.0, (sum, item) {
      double basePrice = item.originalPrice ?? item.price;
      return sum + (basePrice * item.quantity);
    });
  }

  double _calculateDiscountTotal() {
    return _items.fold(0.0, (sum, item) {
      // item.discountAmount is per-unit discount
      return sum + (item.discountAmount * item.quantity);
    });
  }

  double _calculateNetTotal() {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}
