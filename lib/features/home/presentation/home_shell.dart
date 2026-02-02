// lib/features/home/presentation/home_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../my_day/presentation/my_day_page.dart';
import '../../sales/presentation/sales_history_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../auth/presentation/account_select_page.dart';

// --- Providers for Tab State ---
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

final homeTitleProvider = Provider<String>((ref) {
  final index = ref.watch(homeTabIndexProvider);
  switch (index) {
    case 0:
      return 'Dashboard';
    case 1:
      return 'My Day';
    case 2:
      return 'Sales History';
    case 3:
      return 'Reports';
    default:
      return 'Dashboard';
  }
});

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final title = ref.watch(homeTitleProvider);

    Widget buildBody() {
      switch (currentIndex) {
        case 0:
          return const DashboardPage();
        case 1:
          return const MyDayPage();
        case 2:
          return const SalesHistoryPage();
        case 3:
          return const ReportsPage();
        default:
          return const DashboardPage();
      }
    }

    return Scaffold(
      drawer: const _HomeDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _SfaAppBar(title: title),
      ),
      body: buildBody(),
      bottomNavigationBar: _SfaBottomNav(
        currentIndex: currentIndex,
        onTap: (index) =>
        ref.read(homeTabIndexProvider.notifier).state = index,
      ),
    );
  }
}

// --- Drawer ---

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Auth state
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final salesman = authState.salesman;

    // Sync state
    final syncState = ref.watch(syncProvider);

    String displayName;
    String displaySubtitle;
    final email = user?.email ?? '';

    if (salesman != null) {
      displayName = salesman.name;
      displaySubtitle = "Code: ${salesman.code}";
    } else if (user != null) {
      displayName = "${user.fname} ${user.lname}".trim();
      if (displayName.isEmpty) displayName = "User";
      displaySubtitle = "Admin / User Mode";
    } else {
      displayName = "Guest";
      displaySubtitle = "---";
    }

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            accountName: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text('$displaySubtitle • $email'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                displayName.isNotEmpty ? displayName[0] : 'U',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),

          // --- SYNC BUTTON ---
          ListTile(
            leading: syncState.isLoading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.sync_outlined),
            title: const Text('Sync Data'),
            subtitle: syncState.isLoading
                ? const Text('Downloading data...')
                : const Text('Tap to download latest data'),
            onTap: syncState.isLoading
                ? null
                : () async {
              await ref.read(syncProvider.notifier).syncAll();

              if (!context.mounted) return;

              final latest = ref.read(syncProvider);

              Navigator.pop(context);

              if (latest.hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync Failed: ${latest.error}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data synced successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),

          // --- SWITCH ACCOUNT (only if multiple accounts) ---
          if (authState.salesmen.length > 1) ...[
            ListTile(
              leading: const Icon(Icons.switch_account_outlined),
              title: const Text('Switch Account'),
              subtitle: Text('Active: ${salesman?.code ?? "None"}'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSelectPage(),
                  ),
                );
              },
            ),
          ],

          const Spacer(),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- App Bar ---

class _SfaAppBar extends StatelessWidget {
  final String title;

  const _SfaAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: theme.iconTheme,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// --- Bottom Navigation ---

class _SfaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SfaBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.white,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'My Day',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Sales History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
