import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
// Import the SplashPage (which handles the sync logic)
import 'features/auth/presentation/splash_page.dart';

void main() {
  // Ensure bindings are initialized before any async calls or native channel usage
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: VosSfaGoApp()));
}

class VosSfaGoApp extends StatelessWidget {
  const VosSfaGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOS SFA Go',
      debugShowCheckedModeBanner: false,
      // 🔆 AppTheme is now purely LIGHT inside buildAppTheme()
      theme: buildAppTheme(),
      // We start with SplashPage to check/sync data before showing AuthGate/Login
      home: const SplashPage(),
    );
  }
}
