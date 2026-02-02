// lib/providers/home_tab_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the selected bottom nav tab.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Title for the app bar, based on selected tab.
final homeTitleProvider = Provider<String>((ref) {
  final index = ref.watch(homeTabIndexProvider);
  switch (index) {
    case 0:
      return 'Dashboard';
    case 1:
      return 'My Day';
    case 2:
      return 'Customers';
    case 3:
      return 'Reports';
    default:
      return 'SFA';
  }
});
