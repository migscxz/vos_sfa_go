import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/callsheet/presentation/callsheet_data_entry_page.dart';
import 'package:vos_sfa_go/features/callsheet/presentation/callsheet_capture_page.dart';
import 'package:vos_sfa_go/features/orders/presentation/order_form.dart';

class QuickActionsCard extends StatelessWidget {
  final bool isTablet;

  const QuickActionsCard({super.key, required this.isTablet});

  @override
  Widget build(BuildContext context) {
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
              Icon(
                Icons.bolt_rounded,
                color: AppColors.textDark,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
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
                  label: 'New Order',
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
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CallsheetCapturePage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.print_rounded,
                  label: 'Printables',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CallsheetDataEntryPage()),
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