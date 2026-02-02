import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/mcp_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../dap_monitor/presentation/dap_monitor_page.dart'; // <--- Ensure this path is correct

enum McpStatus { none, completed, unfinished }

class McpPage extends ConsumerWidget {
  const McpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 1. Watch Providers
    final date = ref.watch(mcpDateProvider);
    final authState = ref.watch(authProvider);

    // 2. Handle Unknown Name Logic
    String displayName = 'Unknown';
    if (authState.salesman != null) {
      displayName = authState.salesman!.name;
    } else if (authState.user != null) {
      displayName = "${authState.user!.fname} ${authState.user!.lname}";
    }

    // 3. Watch Async Data
    final statusAsync = ref.watch(mcpStatusProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Monthly Coverage Plan'),
        actions: [
          // Month Navigation
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newDate = DateTime(date.year, date.month - 1);
              ref.read(mcpDateProvider.notifier).state = newDate;
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final newDate = DateTime(date.year, date.month + 1);
              ref.read(mcpDateProvider.notifier).state = newDate;
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _HeaderCard(
                month: date.month,
                year: date.year,
                salesmanName: displayName, // Pass the fixed name
              ),
              const SizedBox(height: 12),
              const _LegendRow(),
              const SizedBox(height: 12),

              // 4. Load Calendar with Data
              statusAsync.when(
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading MCP: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (statusMap) => _McpCalendar(
                  month: date.month,
                  year: date.year,
                  statusMap: statusMap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _HeaderCard extends StatelessWidget {
  final int month;
  final int year;
  final String salesmanName;
  const _HeaderCard({required this.month, required this.year, required this.salesmanName});

  String _monthName(int m) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1), boxShadow: [BoxShadow(color: AppColors.shadowBase.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Coverage Plan', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(children: [_Pill(text: _monthName(month)), const SizedBox(width: 8), _Pill(text: '$year')]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border, width: 1)),
            child: Text('Salesman: $salesmanName', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDark, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border, width: 1)), child: Text(text, style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500)));
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();
  @override
  Widget build(BuildContext context) {
    return Row(children: [const Text('Completed', style: TextStyle(fontSize: 13)), const SizedBox(width: 8), Container(width: 32, height: 16, color: const Color(0xFF22C55E)), const SizedBox(width: 16), const Text('Unfinished', style: TextStyle(fontSize: 13)), const SizedBox(width: 8), Container(width: 32, height: 16, color: const Color(0xFFDC2626))]);
  }
}

class _McpCalendar extends StatelessWidget {
  final int month;
  final int year;
  final Map<int, int> statusMap;

  const _McpCalendar({
    required this.month,
    required this.year,
    required this.statusMap,
  });

  McpStatus _statusForDay(int day) {
    if (!statusMap.containsKey(day)) return McpStatus.none;
    final statusVal = statusMap[day];
    if (statusVal == 1) return McpStatus.completed;
    if (statusVal == 0) return McpStatus.unfinished;
    return McpStatus.none;
  }

  String _monthName(int m) {
    const names = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    return names[m - 1];
  }

  // --- NAVIGATION LOGIC ---
  void _handleDayTap(BuildContext context, int day) {
    final clickedDate = DateTime(year, month, day);

    // Navigate to DAP Monitor for the specific date
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DapMonitorPage(initialDate: clickedDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekdayIndex = firstDay.weekday % 7;
    final prevMonthDate = DateTime(year, month, 0);
    final daysInPrevMonth = prevMonthDate.day;
    int nextMonthDay = 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1), boxShadow: [BoxShadow(color: AppColors.shadowBase.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: Text(_monthName(month), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          _buildHeaderRow(theme),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 4),
          Column(
            children: List.generate(6, (week) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (col) {
                    int? dayNumber;
                    bool isCurrentMonth = false;

                    if (week == 0 && col < firstWeekdayIndex) {
                      final offset = firstWeekdayIndex - col;
                      dayNumber = daysInPrevMonth - offset + 1;
                      isCurrentMonth = false;
                    } else {
                      final index = week * 7 + col - firstWeekdayIndex + 1;
                      if (index < 1 || index > daysInMonth) {
                        dayNumber = nextMonthDay++;
                        isCurrentMonth = false;
                      } else {
                        dayNumber = index;
                        isCurrentMonth = true;
                      }
                    }

                    final status = isCurrentMonth ? _statusForDay(dayNumber!) : McpStatus.none;

                    return Expanded(
                      child: _CalendarCell(
                        day: dayNumber!,
                        isCurrentMonth: isCurrentMonth,
                        status: status,
                        // Only allow clicking days in the current month
                        onTap: isCurrentMonth ? () => _handleDayTap(context, dayNumber!) : null,
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(ThemeData theme) {
    const labels = ['SUN', 'MON', 'TUES', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(children: labels.map((label) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), alignment: Alignment.center, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))))).toList());
  }
}

class _CalendarCell extends StatelessWidget {
  final int day;
  final bool isCurrentMonth;
  final McpStatus status;
  final VoidCallback? onTap;

  const _CalendarCell({
    required this.day,
    required this.isCurrentMonth,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;

    if (!isCurrentMonth) {
      bg = const Color(0xFFF3F4F6);
      textColor = AppColors.textMuted;
    } else {
      switch (status) {
        case McpStatus.completed:
          bg = const Color(0xFF22C55E);
          textColor = Colors.white;
          break;
        case McpStatus.unfinished:
          bg = const Color(0xFFDC2626);
          textColor = Colors.white;
          break;
        case McpStatus.none:
          bg = Colors.white;
          textColor = AppColors.textDark;
          break;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12, width: 0.6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: (status == McpStatus.completed || status == McpStatus.unfinished)
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}