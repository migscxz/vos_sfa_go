import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/dap_providers.dart';
import '../data/dap_model.dart';

// Order Form
import '../../orders/presentation/order_form.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/customer_model.dart';

class DapMonitorPage extends ConsumerWidget {
  final DateTime? initialDate;

  const DapMonitorPage({super.key, this.initialDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Normalize date (strip time)
    final rawDate = initialDate ?? DateTime.now();
    final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

    // Watch provider with stable date
    final dapAsync = ref.watch(dapByDateProvider(targetDate));

    final dateTitle = DateFormat('MMM d, yyyy').format(targetDate);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text('DAP: $dateTitle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowBase.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan for $dateTitle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const _DapTableHeader(),
                const Divider(color: AppColors.border, height: 1),
                dapAsync.when(
                  data: (dapList) {
                    if (dapList.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            "No plans scheduled for this date.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: dapList
                          .map(
                            (item) => Column(
                              children: [
                                _DapTableRow(item: item),
                                const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, stack) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DapTableHeader extends StatelessWidget {
  const _DapTableHeader();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: const [
          _HeaderCell(label: 'Status', flex: 2),
          _HeaderCell(label: 'Accounts', flex: 3),
          _HeaderCell(label: 'Task', flex: 4),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell({required this.label, required this.flex});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DapTableRow extends StatelessWidget {
  final DapWithDetails item;
  const _DapTableRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isCompleted = item.isCompleted;
    final bool hasCustomer = item.customerId != null;

    final TextStyle baseStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textDark,
          fontSize: 12,
        ) ??
        const TextStyle(fontSize: 12);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          if (isCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This task is already completed.')),
            );
          } else if (hasCustomer) {
            // ✅ Order-taking DAP (customer_id is present) → go to Order Form
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderFormPage(
                  initialCustomer: Customer(
                    id: item.customerId ?? 0,
                    name: item.accountName,
                    code: item.customerCode ?? '',
                  ),
                  initialType: OrderType.manual,
                ),
              ),
            );
          } else {
            // ✅ Photo-only DAP (no customer_id) → go to Photo Task Page
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PhotoTaskPage(dap: item)));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              // Status column
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isCompleted ? Colors.green : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted ? "Done" : (hasCustomer ? "Start" : "Photo"),
                      style: baseStyle.copyWith(
                        fontWeight: isCompleted
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: isCompleted
                            ? Colors.green
                            : (hasCustomer
                                  ? Colors.blue[700]
                                  : Colors.orangeAccent),
                      ),
                    ),
                  ],
                ),
              ),

              // Accounts column (customer name or additional description)
              Expanded(
                flex: 3,
                child: Text(item.accountName, style: baseStyle),
              ),

              // Task column
              Expanded(flex: 4, child: Text(item.taskName, style: baseStyle)),

              if (!isCompleted)
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple Photo Task page where you can later plug in your camera logic
class PhotoTaskPage extends StatelessWidget {
  final DapWithDetails dap;

  const PhotoTaskPage({super.key, required this.dap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Photo Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dap.taskName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Target / Account:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(dap.accountName, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (dap.additionalDescription != null &&
                dap.additionalDescription!.isNotEmpty) ...[
              Text(
                'Details:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dap.additionalDescription!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            Text('Priority: ${dap.priority}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            // TODO: Replace this with real camera / photo capture flow
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Here you can navigate to your actual photo capture screen
                  // or call your photo service.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('TODO: Open camera for this photo task.'),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
