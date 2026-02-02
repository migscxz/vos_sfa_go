// lib/providers/sync_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/global_sync_service.dart';
import 'auth_provider.dart';

final syncServiceProvider = Provider((ref) => GlobalSyncService());

// A StateNotifier to handle the UI state of syncing (Loading, Success, Error)
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final GlobalSyncService _service;
  final Ref _ref;

  SyncNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  /// Sync everything.
  /// If the logged-in user has a Salesman profile, we filter sales data by that salesman.
  Future<void> syncAll() async {
    state = const AsyncValue.loading();
    try {
      // Read current auth state
      final authState = _ref.read(authProvider);
      final salesman = authState.salesman;

      final int? salesmanId = salesman?.id; // <-- If your model uses another field, change here

      // Debug
      // ignore: avoid_print
      print('SyncNotifier.syncAll → salesmanId=$salesmanId');

      await _service.syncAllData(salesmanId: salesmanId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final syncProvider =
StateNotifierProvider<SyncNotifier, AsyncValue<void>>((ref) {
  return SyncNotifier(ref.watch(syncServiceProvider), ref);
});
