import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/mcp/data/mcp_repository.dart';
import 'auth_provider.dart';

final mcpRepositoryProvider = Provider((ref) => McpRepository());

// Provide the Month/Year we want to view (Default to current)
final mcpDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// The Data Provider
final mcpStatusProvider = FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final repo = ref.watch(mcpRepositoryProvider);
  final date = ref.watch(mcpDateProvider);
  final authState = ref.watch(authProvider);

  if (authState.user == null) return {};

  return repo.getMcpStatus(date.year, date.month, authState.user!.userId);
});