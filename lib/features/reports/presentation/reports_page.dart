import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/mcp/presentation/mcp_page.dart';
import '../../dap_monitor/presentation/dap_monitor_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade50,
            Colors.white,
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports & Analytics',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Access your sales and performance reports',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionCard(
                  title: 'CSR Reports',
                  subtitle: 'Customer and sales documentation',
                  icon: Icons.description_outlined,
                  iconColor: Colors.blue,
                  children: [
                    _ReportTile(
                      icon: Icons.edit_document,
                      label: 'SO-M-Doc (Manual)',
                      subtitle: 'Manual sales orders',
                      onTap: () => _showComingSoon(context, 'SO-M-Doc (Manual)'),
                    ),
                    _ReportTile(
                      icon: Icons.phone_in_talk,
                      label: 'SO-CS-Doc (Callsheet)',
                      subtitle: 'Callsheet documentation',
                      onTap: () => _showComingSoon(context, 'SO-CS-Doc (Callsheet)'),
                    ),
                    _ReportTile(
                      icon: Icons.receipt_long,
                      label: 'Receivables Report',
                      subtitle: 'Outstanding payments',
                      onTap: () => _showComingSoon(context, 'Receivables Report'),
                    ),
                    _ReportTile(
                      icon: Icons.price_check,
                      label: 'Price List',
                      subtitle: 'Current pricing',
                      onTap: () => _showComingSoon(context, 'Price List'),
                    ),
                    _ReportTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventory Report',
                      subtitle: 'Stock levels',
                      onTap: () => _showComingSoon(context, 'Inventory Report'),
                    ),
                    _ReportTile(
                      icon: Icons.payments_outlined,
                      label: 'Collection Performance',
                      subtitle: 'Payment collection metrics',
                      onTap: () => _showComingSoon(context, 'Collection Performance'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Planning & Tasks',
                  subtitle: 'Monitor your plans and activities',
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.green,
                  children: [
                    _ReportTile(
                      icon: Icons.event_note,
                      label: 'Monthly Coverage Plan Monitor',
                      subtitle: 'Track monthly coverage',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const McpPage(),
                          ),
                        );
                      },
                    ),
                    _ReportTile(
                      icon: Icons.today,
                      label: 'Daily Action Plan Monitor',
                      subtitle: 'Track daily activities',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DapMonitorPage(),
                          ),
                        );
                      },
                    ),
                    _ReportTile(
                      icon: Icons.assessment,
                      label: 'Task Performance Report',
                      subtitle: 'Task completion metrics',
                      onTap: () => _showComingSoon(context, 'Task Performance Report'),
                    ),
                    _ReportTile(
                      icon: Icons.notifications_active_outlined,
                      label: 'Receivables Alert',
                      subtitle: 'Payment reminders',
                      onTap: () => _showComingSoon(context, 'Receivables Alert'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name – coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}