import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import 'auth_gate.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  String _status = "Checking data...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure the UI builds before checking
    Future.microtask(() => _checkAndSync());
  }

  Future<void> _checkAndSync() async {
    // We access the repository directly to check/sync before the AuthProvider is even used
    final repo = ref.read(authRepositoryProvider);

    try {
      // 1. Check if we have users in SQLite
      final hasData = await repo.hasUsers();

      if (hasData) {
        // Data exists, go to Login
        if (mounted) setState(() => _status = "Data verified.");
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToGate();
      } else {
        // 2. No data? We must be newly installed. Sync now.
        if (mounted) {
          setState(() => _status = "First run detected.\nDownloading users & salesmen...");
        }

        await repo.syncAuthData();

        if (mounted) setState(() => _status = "Setup complete!");
        await Future.delayed(const Duration(seconds: 1));
        _navigateToGate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Setup Failed: $e\n\nPlease check internet connection.";
          _hasError = true;
        });
      }
    }
  }

  void _navigateToGate() {
    if (!mounted) return;
    // Replace Splash with the AuthGate (which shows Login)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Icon(Icons.cloud_sync, size: 64, color: Colors.blue[800]),
              const SizedBox(height: 24),

              if (_hasError)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                )
              else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_status, textAlign: TextAlign.center),
              ],

              if (_hasError)
                Padding(
                  // FIXED: Correct syntax for EdgeInsets.only
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _status = "Retrying...";
                      });
                      _checkAndSync();
                    },
                    child: const Text("Retry"),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}