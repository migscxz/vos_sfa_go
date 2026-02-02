import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:getwidget/getwidget.dart';

import '../../../core/theme/app_colors.dart';
import 'package:vos_sfa_go/features/orders/presentation/order_form.dart';
import '../../../data/models/order_model.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dap_providers.dart';
import '../../dap_monitor/data/dap_model.dart';

/// --- Styling Constants (clean + presentation-ready) ---
class AppStyle {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  static const double radius = 12.0;
  static const double pad = 16.0;
  static const double gap = 12.0;
}

/// Simple model to represent a customer for My Day
class MyDayCustomer {
  final int id;
  final String code;
  final String name;
  final String? brgy;
  final String? city;
  final String? province;

  MyDayCustomer({
    required this.id,
    required this.code,
    required this.name,
    this.brgy,
    this.city,
    this.province,
  });

  factory MyDayCustomer.fromMap(Map<String, dynamic> map) {
    return MyDayCustomer(
      id: (map['id'] as num).toInt(),
      code: map['customer_code']?.toString() ?? '',
      name: map['customer_name']?.toString() ?? '',
      brgy: map['brgy']?.toString(),
      city: map['city']?.toString(),
      province: map['province']?.toString(),
    );
  }

  String get address {
    final parts = <String>[];
    if (brgy != null && brgy!.trim().isNotEmpty) parts.add(brgy!.trim());
    if (city != null && city!.trim().isNotEmpty) parts.add(city!.trim());
    if (province != null && province!.trim().isNotEmpty) parts.add(province!.trim());
    return parts.isEmpty ? '' : parts.join(', ');
  }
}

/// Customers assigned to a given salesman, from SQLite
final myDayCustomersProvider =
FutureProvider.family<List<MyDayCustomer>, int?>((ref, salesmanId) async {
  if (salesmanId == null) return [];

  final db = await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

  final rows = await db.rawQuery('''
    SELECT DISTINCT
      c.id,
      c.customer_code,
      c.customer_name,
      c.brgy,
      c.city,
      c.province
    FROM customer c
    INNER JOIN customer_salesman cs 
      ON cs.customer_id = c.id
    WHERE cs.salesman_id = ?
    ORDER BY c.customer_name
  ''', [salesmanId]);

  final Map<int, MyDayCustomer> uniqueById = {};
  for (final row in rows) {
    final customer = MyDayCustomer.fromMap(row as Map<String, dynamic>);
    uniqueById[customer.id] = customer;
  }

  final result = uniqueById.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return result;
});

class MyDayPage extends ConsumerWidget {
  const MyDayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayLabel = DateFormat('EEEE, MMM d').format(now);

    final dapAsync = ref.watch(dapByDateProvider(today));
    final authState = ref.watch(authProvider);
    final salesman = authState.salesman;
    final salesmanId = salesman?.id;
    final customersAsync = ref.watch(myDayCustomersProvider(salesmanId));

    return Scaffold(
      backgroundColor: AppStyle.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(todayLabel, salesman),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppStyle.pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats (visual but still clean)
                  _buildOverviewRow(dapAsync, customersAsync),
                  const SizedBox(height: 18),

                  _buildSectionHeader("Today's Plan", Icons.calendar_today_rounded),
                  const SizedBox(height: 10),
                  _buildCompactDapSection(context, dapAsync),
                  const SizedBox(height: 22),

                  _buildSectionHeader("My Customers", Icons.people_outline_rounded),
                  const SizedBox(height: 10),
                  if (salesmanId == null)
                    _buildInfoNotice(
                      icon: Icons.info_outline_rounded,
                      title: 'Salesman profile required',
                      message: 'Customer list is only available for salesmen.',
                      tone: _NoticeTone.warning,
                    )
                  else
                    _buildCustomerList(context, customersAsync, dapAsync),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TOP BAR ----------
  Widget _buildSliverAppBar(String date, dynamic salesman) {
    return SliverAppBar(
      floating: true,
      pinned: false,
      backgroundColor: AppStyle.background,
      elevation: 0,
      expandedHeight: 112,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppStyle.pad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Day",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppStyle.textMain,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16, color: AppStyle.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppStyle.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (salesman != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: AppStyle.border, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.blueBright.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.blueBright.withOpacity(0.24)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 14, color: AppColors.blueBright),
                          const SizedBox(width: 6),
                          Text(
                            salesman.name,
                            style: const TextStyle(
                              color: AppColors.blueBright,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- SECTION HEADER ----------
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppStyle.textMuted),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppStyle.textMuted,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  // ---------- OVERVIEW / STATS ----------
  Widget _buildOverviewRow(
      AsyncValue<List<DapWithDetails>> dapAsync,
      AsyncValue<List<MyDayCustomer>> customersAsync,
      ) {
    final tasks = dapAsync.maybeWhen(data: (d) => d, orElse: () => const <DapWithDetails>[]);
    final totalTasks = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final pending = totalTasks - done;

    final customers = customersAsync.maybeWhen(data: (d) => d, orElse: () => const <MyDayCustomer>[]);
    final totalCustomers = customers.length;

    final progress = totalTasks == 0 ? 0.0 : done / totalTasks;

    return Container(
      decoration: BoxDecoration(
        color: AppStyle.surface,
        borderRadius: BorderRadius.circular(AppStyle.radius),
        border: Border.all(color: AppStyle.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  title: 'Tasks',
                  value: '$totalTasks',
                  subtitle: 'Today',
                  icon: Icons.assignment_rounded,
                  accent: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  title: 'Pending',
                  value: '$pending',
                  subtitle: 'Open items',
                  icon: Icons.timelapse_rounded,
                  accent: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  title: 'Customers',
                  value: '$totalCustomers',
                  subtitle: 'Assigned',
                  icon: Icons.people_rounded,
                  accent: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Completion',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppStyle.textMain),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GFProgressBar(
                  percentage: progress,
                  lineHeight: 8,
                  backgroundColor: AppStyle.border,
                  progressBarColor: const Color(0xFF3B82F6),
                  radius: 999,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                totalTasks == 0 ? '—' : '${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppStyle.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- DAP SECTION ----------
  Widget _buildCompactDapSection(
      BuildContext context,
      AsyncValue<List<DapWithDetails>> dapAsync,
      ) {
    return dapAsync.when(
      loading: () => _buildLoadingBox(),
      error: (e, _) => _buildInfoNotice(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load tasks',
        message: '$e',
        tone: _NoticeTone.error,
      ),
      data: (items) {
        if (items.isEmpty) return _buildEmptyState("No tasks for today");

        final done = items.where((i) => i.isCompleted).length;
        final pending = items.length - done;

        return Container(
          decoration: BoxDecoration(
            color: AppStyle.surface,
            borderRadius: BorderRadius.circular(AppStyle.radius),
            border: Border.all(color: AppStyle.border),
          ),
          child: Column(
            children: [
              // Header strip (adds structure + more visual)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: Color(0xFF3B82F6), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Today’s Schedule',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppStyle.textMain,
                        ),
                      ),
                    ),
                    _TinyPill(
                      text: '$pending pending',
                      color: pending == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      bg: pending == 0
                          ? const Color(0xFF10B981).withOpacity(0.10)
                          : const Color(0xFFF59E0B).withOpacity(0.12),
                    ),
                    const SizedBox(width: 8),
                    _TinyPill(
                      text: '$done done',
                      color: const Color(0xFF10B981),
                      bg: const Color(0xFF10B981).withOpacity(0.10),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppStyle.border),

              // Show top 3
              ...items.take(3).map((item) => _DapItemRow(item: item)),
              if (items.length > 3)
                InkWell(
                  onTap: () => _showDapBottomSheet(context, items),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppStyle.border)),
                    ),
                    child: Center(
                      child: Text(
                        "View ${items.length - 3} more tasks",
                        style: const TextStyle(
                          color: AppColors.blueBright,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- CUSTOMER LIST ----------
  Widget _buildCustomerList(
      BuildContext context,
      AsyncValue<List<MyDayCustomer>> customersAsync,
      AsyncValue<List<DapWithDetails>> dapAsync,
      ) {
    return customersAsync.when(
      loading: () => _buildLoadingBox(),
      error: (e, _) => _buildInfoNotice(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load customers',
        message: '$e',
        tone: _NoticeTone.error,
      ),
      data: (customers) {
        if (customers.isEmpty) return _buildEmptyState("No customers assigned");

        final dapItems = dapAsync.maybeWhen(data: (d) => d, orElse: () => const <DapWithDetails>[]);

        // Build task map once for performance + cleanliness
        final Map<int, List<DapWithDetails>> tasksByCustomer = {};
        for (final d in dapItems) {
          final cid = d.customerId;
          if (cid == null) continue;
          (tasksByCustomer[cid] ??= []).add(d);
        }

        return Container(
          decoration: BoxDecoration(
            color: AppStyle.surface,
            borderRadius: BorderRadius.circular(AppStyle.radius),
            border: Border.all(color: AppStyle.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppStyle.border, indent: 66),
            itemBuilder: (context, index) {
              final customer = customers[index];
              final tasks = tasksByCustomer[customer.id] ?? const <DapWithDetails>[];
              return _CustomerListItem(
                customer: customer,
                tasks: tasks,
                onOpenTasks: () => _showCustomerTasksBottomSheet(context, customer, tasks),
              );
            },
          ),
        );
      },
    );
  }

  // ---------- UI HELPERS ----------
  Widget _buildLoadingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppStyle.surface,
        borderRadius: BorderRadius.circular(AppStyle.radius),
        border: Border.all(color: AppStyle.border),
      ),
      child: const Center(child: GFLoader(type: GFLoaderType.circle)),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppStyle.surface,
        borderRadius: BorderRadius.circular(AppStyle.radius),
        border: Border.all(color: AppStyle.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppStyle.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoNotice({
    required IconData icon,
    required String title,
    required String message,
    required _NoticeTone tone,
  }) {
    final Color accent = switch (tone) {
      _NoticeTone.warning => const Color(0xFFF59E0B),
      _NoticeTone.error => const Color(0xFFEF4444),
      _NoticeTone.info => const Color(0xFF3B82F6),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppStyle.radius),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppStyle.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- BOTTOM SHEETS ----------
  void _showDapBottomSheet(BuildContext context, List<DapWithDetails> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (_, controller) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'All Tasks Today',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                        GFIconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          size: GFSize.SMALL,
                          shape: GFIconButtonShape.circle,
                          color: AppStyle.border.withOpacity(0.35),
                          splashColor: AppStyle.border,
                          type: GFButtonType.solid,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = items[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppStyle.surface,
                              borderRadius: BorderRadius.circular(AppStyle.radius),
                              border: Border.all(color: AppStyle.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    t.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: t.isCompleted ? const Color(0xFF10B981) : AppColors.blueBright,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.accountName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.5,
                                            color: AppStyle.textMain,
                                            decoration:
                                            t.isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t.taskName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppStyle.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (!t.isCompleted)
                                    const Icon(Icons.chevron_right, color: AppStyle.border, size: 18),
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
            },
          ),
        );
      },
    );
  }

  void _showCustomerTasksBottomSheet(
      BuildContext context,
      MyDayCustomer customer,
      List<DapWithDetails> tasks,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (_, controller) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GFIconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          size: GFSize.SMALL,
                          shape: GFIconButtonShape.circle,
                          color: AppStyle.border.withOpacity(0.35),
                          splashColor: AppStyle.border,
                          type: GFButtonType.solid,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.code,
                            style: const TextStyle(
                              color: AppStyle.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GFButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderFormPage(
                                  initialCustomerName: customer.name,
                                  initialCustomerCode: customer.code,
                                  initialType: OrderType.manual,
                                ),
                              ),
                            );
                          },
                          text: 'New Order',
                          icon: const Icon(Icons.add, size: 16),
                          size: GFSize.SMALL,
                          color: AppColors.blueBright,
                          shape: GFButtonShape.pills,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: tasks.isEmpty
                          ? _buildEmptyState("No tasks for this customer today")
                          : ListView.separated(
                        controller: controller,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => Container(
                          decoration: BoxDecoration(
                            color: AppStyle.surface,
                            borderRadius: BorderRadius.circular(AppStyle.radius),
                            border: Border.all(color: AppStyle.border),
                          ),
                          child: _DapItemRow(item: tasks[i], showChevron: false),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum _NoticeTone { info, warning, error }

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppStyle.textMuted,
                    letterSpacing: 0.9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppStyle.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _TinyPill({
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DapItemRow extends StatelessWidget {
  final DapWithDetails item;
  final bool showChevron;

  const _DapItemRow({
    required this.item,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = item.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? const Color(0xFF10B981) : AppColors.blueBright,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.accountName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AppStyle.textMain,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.taskName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyle.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppStyle.border, size: 18),
          ],
        ],
      ),
    );
  }
}

class _CustomerListItem extends StatelessWidget {
  final MyDayCustomer customer;
  final List<DapWithDetails> tasks;
  final VoidCallback onOpenTasks;

  const _CustomerListItem({
    required this.customer,
    required this.tasks,
    required this.onOpenTasks,
  });

  @override
  Widget build(BuildContext context) {
    final hasTasks = tasks.isNotEmpty;

    // NOTE: No shadows here (presentation clean)
    return InkWell(
      onTap: onOpenTasks,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blueBright.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blueBright.withOpacity(0.18)),
              ),
              child: Center(
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.blueBright,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppStyle.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppStyle.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customer.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.address,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppStyle.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasTasks)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.18)),
                    ),
                    child: Text(
                      "${tasks.length} task(s)",
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppStyle.border.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "No tasks",
                      style: TextStyle(
                        color: AppStyle.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _CompactOrderButton(customer: customer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOrderButton extends StatelessWidget {
  final MyDayCustomer customer;
  const _CompactOrderButton({required this.customer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderFormPage(
              initialCustomerName: customer.name,
              initialCustomerCode: customer.code,
              initialType: OrderType.manual,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.blueBright,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          "Order",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
