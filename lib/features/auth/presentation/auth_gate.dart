import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../home/presentation/home_shell.dart';
import 'login_page.dart';
import 'account_select_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (!auth.isAuthenticated) return const LoginPage();
    if (auth.needsAccountSelection) return const AccountSelectPage();

    return const HomeShell();
  }
}
