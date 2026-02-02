import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:getwidget/getwidget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/dap_providers.dart';
import 'widgets/summary_grid.dart';
import 'widgets/quick_actions_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = _normalizeDate(now);

    final dapAsync = ref.watch(dapByDateProvider(today));
    final ordersList = ref.watch(orderListProvider);

    final todaysOrders = ordersList.where((o) =>
        _normalizeDate(o.createdAt).isAtSameMomentAs(today)
    ).toList();

    final int totalOrdersCount = todaysOrders.length;
    final double totalSales = todaysOrders.fold(0.0, (sum, item) => sum + item.totalAmount);
    final currencyFmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 800;
            final horizontalPadding = isTablet ? 40.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 32),

                  dapAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: GFLoader(type: GFLoaderType.circle),
                      ),
                    ),
                    error: (e, _) => GFAlert(
                      type: GFAlertType.rounded,
                      backgroundColor: Colors.red.shade50,
                      content: Text(
                        "Error loading dashboard: $e",
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    data: (dapItems) {
                      final totalVisits = dapItems.length;
                      final completedVisits = dapItems.where((i) => i.isCompleted).length;
                      final pendingTasks = totalVisits - completedVisits;

                      return Column(
                        children: [
                          SummaryGrid(
                            isTablet: isTablet,
                            visitsCompleted: completedVisits,
                            visitsTotal: totalVisits,
                            pendingTasks: pendingTasks,
                            totalOrders: totalOrdersCount,
                            totalSales: currencyFmt.format(totalSales),
                          ),
                          const SizedBox(height: 32),
                          QuickActionsCard(isTablet: isTablet),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(DateTime.now()),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}