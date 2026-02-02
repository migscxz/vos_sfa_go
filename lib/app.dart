// lib/app.dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_shell.dart';

class SfaApp extends StatelessWidget {
  const SfaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOS SFA GO',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
