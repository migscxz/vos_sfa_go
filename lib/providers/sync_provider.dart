// lib/providers/sync_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:vos_sfa_go/core/services/file_api_service.dart';
import 'package:vos_sfa_go/features/orders/data/repositories/order_repository.dart';
import '../core/api/global_sync_service.dart';
import 'auth_provider.dart';
import 'customer_provider.dart';
import 'dap_providers.dart';

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

      final int? salesmanId =
          salesman?.id; // <-- If your model uses another field, change here

      // Debug
      // ignore: avoid_print
      print('SyncNotifier.syncAll → salesmanId=$salesmanId');

      await _service.syncAllData(salesmanId: salesmanId);

      // --- Custom Sync: Callsheet Attachments ---
      try {
        final orderRepo = OrderRepository();
        final fileService = FileApiService();
        final unsynced = await orderRepo.getUnsyncedAttachments();
        final docDir = await getApplicationDocumentsDirectory();

        if (unsynced.isNotEmpty) {
          print('Found ${unsynced.length} unsynced attachments');
        }

        for (final record in unsynced) {
          try {
            final filename = record['attachment_name'] as String;
            final file = File('${docDir.path}/$filename');

            if (!await file.exists()) {
              print('Attachment file not found: $filename');
              // Maybe mark as synced to stop retrying? Or keep trying?
              // Keeping it unsynced for now.
              continue;
            }

            // 1. Upload File
            final uploadedFileId = await fileService.uploadFile(file);

            if (uploadedFileId == null) {
              print('Failed to upload file for ${record['id']}');
              continue;
            }

            // 2. Upload Metadata
            // Prepare Payload
            final metaPayload = Map<String, dynamic>.from(record);
            metaPayload.remove('id');
            metaPayload.remove('file_id'); // Remove local null/empty if exists

            // Set the Server File ID to the new column
            metaPayload['file_id'] = uploadedFileId;
            // Note: attachment_name remains as the original filename (SO-...pdf)

            final metaSuccess = await fileService.uploadAttachmentMetadata(
              metaPayload,
            );

            // 3. Mark Synced
            if (metaSuccess) {
              final localId = record['id'] as int;
              await orderRepo.markAttachmentAsSynced(
                localId,
                fileId: uploadedFileId,
              );
              print(
                'Synced attachment: $filename (Server ID: $uploadedFileId)',
              );
            }
          } catch (e) {
            print('Failed to sync attachment ${record['id']}: $e');
          }
        }
      } catch (e) {
        print('Error syncing attachments wrapper: $e');
      }

      // Invalidate providers to force refresh of data from DB
      _ref.invalidate(customersWithHistoryProvider);
      _ref.invalidate(customerListProvider);
      _ref.invalidate(dapByDateProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, AsyncValue<void>>((
  ref,
) {
  return SyncNotifier(ref.watch(syncServiceProvider), ref);
});
