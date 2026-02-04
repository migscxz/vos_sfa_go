import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getwidget/getwidget.dart';
import 'package:vos_sfa_go/features/callsheet/presentation/callsheet_data_entry_page.dart';
import 'package:vos_sfa_go/features/monitoring/presentation/monitoring_order_list_page.dart';
import 'package:vos_sfa_go/features/orders/presentation/order_form.dart';
import 'package:vos_sfa_go/features/orders/presentation/pages/pending_orders_page.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/customer_provider.dart';
import '../../../orders/presentation/widgets/modals/customer_picker_modal.dart';
import '../../../../data/models/customer_model.dart';

class QuickActionsCard extends ConsumerWidget {
  final bool isTablet;

  const QuickActionsCard({super.key, required this.isTablet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersWithHistoryProvider);

    return GFCard(
      elevation: 0,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.3)),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.textDark, size: 24),
              const SizedBox(width: 12),
              Text(
                'Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Encoding',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderFormPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PendingOrdersPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.assignment_turned_in_rounded,
                  label: 'Monitor',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    customersAsync.when(
                      data: (customers) async {
                        if (customers.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No customers with order history found.',
                              ),
                            ),
                          );
                          return;
                        }

                        Customer? selectedCustomer;

                        await showDialog(
                          context: context,
                          builder: (context) => CustomerPickerModal(
                            customers: customers,
                            selectedCustomer: null,
                            onCustomerSelected: (customer) {
                              selectedCustomer = customer;
                            },
                          ),
                        );

                        if (selectedCustomer != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MonitoringOrderListPage(
                                customer: selectedCustomer!,
                              ),
                            ),
                          );
                        }
                      },
                      error: (err, stack) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $err')));
                      },
                      loading: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loading customers...')),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.list_alt_rounded,
                  label: 'Callsheet',
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    customersAsync.when(
                      data: (customers) async {
                        if (customers.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No customers with order history found.',
                              ),
                            ),
                          );
                          return;
                        }

                        Customer? selectedCustomer;

                        await showDialog(
                          context: context,
                          builder: (context) => CustomerPickerModal(
                            customers: customers,
                            selectedCustomer: null,
                            onCustomerSelected: (customer) {
                              selectedCustomer = customer;
                            },
                          ),
                        );

                        if (selectedCustomer != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CallsheetDataEntryPage(
                                customer: selectedCustomer!,
                              ),
                            ),
                          );
                        }
                      },
                      error: (err, stack) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $err')));
                      },
                      loading: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loading customers...')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
