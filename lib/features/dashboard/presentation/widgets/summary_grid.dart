import 'package:flutter/material.dart';
import 'metric_card.dart';

class SummaryGrid extends StatelessWidget {
  final bool isTablet;
  final int visitsCompleted;
  final int visitsTotal;
  final int pendingTasks;
  final int totalOrders;
  final String totalSales;

  const SummaryGrid({
    super.key,
    required this.isTablet,
    required this.visitsCompleted,
    required this.visitsTotal,
    required this.pendingTasks,
    required this.totalOrders,
    required this.totalSales,
  });

  @override
  Widget build(BuildContext context) {
    final cardVisits = MetricCard(
      title: "Visits Made",
      value: "$visitsCompleted / $visitsTotal",
      subtitle: "Target: $visitsTotal",
      icon: Icons.location_on_rounded,
      colorTheme: const Color(0xFF3B82F6),
      progress: visitsTotal > 0 ? visitsCompleted / visitsTotal : 0,
    );

    final cardTasks = MetricCard(
      title: "Pending Tasks",
      value: "$pendingTasks",
      subtitle: "Action required",
      icon: Icons.assignment_late_rounded,
      colorTheme: const Color(0xFFF59E0B),
    );

    final cardOrders = MetricCard(
      title: "Orders Taken",
      value: "$totalOrders",
      subtitle: "Today",
      icon: Icons.shopping_bag_rounded,
      colorTheme: const Color(0xFF8B5CF6),
    );

    final cardSales = MetricCard(
      title: "Total Sales",
      value: totalSales,
      subtitle: "Gross Amount",
      icon: Icons.payments_rounded,
      colorTheme: const Color(0xFF10B981),
      isMoney: true,
    );

    if (isTablet) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: cardVisits,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: cardTasks,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: cardOrders,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: cardSales,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cardVisits),
            const SizedBox(width: 16),
            Expanded(child: cardTasks),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: cardOrders),
            const SizedBox(width: 16),
            Expanded(child: cardSales),
          ],
        ),
      ],
    );
  }
}