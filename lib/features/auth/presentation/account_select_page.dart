import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/sync_provider.dart';

class AccountSelectPage extends ConsumerStatefulWidget {
  const AccountSelectPage({super.key});

  @override
  ConsumerState<AccountSelectPage> createState() => _AccountSelectPageState();
}

class _AccountSelectPageState extends ConsumerState<AccountSelectPage> {
  int? _selectingSalesmanId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final accounts = auth.salesmen;
    final activeId = auth.salesman?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Account'),
        centerTitle: true,
      ),
      body: accounts.isEmpty
          ? const Center(child: Text('No accounts found.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = accounts[i];
          final isBusy = _selectingSalesmanId == s.id;
          final isActive = activeId == s.id;

          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.grey.shade100,
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.blueGrey,
              child: Text(
                s.id.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.green.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'ID: ${s.id} • Code: ${s.code}'
                  '${s.branchId != null ? ' • Branch: ${s.branchId}' : ''}'
                  '${s.priceType != null ? ' • Price: ${s.priceType}' : ''}',
            ),
            trailing: isBusy
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.chevron_right),
            onTap: isBusy
                ? null
                : () async {
              setState(() => _selectingSalesmanId = s.id);

              try {
                await ref.read(authProvider.notifier).selectSalesman(s);

                // Trigger scoped sync for the active salesman.
                await ref.read(syncProvider.notifier).syncAll();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Active account set to ID ${s.id} (${s.code}).'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );

                // If opened from drawer, we can pop back.
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to switch account: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (mounted) setState(() => _selectingSalesmanId = null);
              }
            },
          );
        },
      ),
    );
  }
}
