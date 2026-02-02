import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_models.dart';
import '../features/auth/data/auth_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final User? user;

  // ✅ All accounts for this user
  final List<Salesman> salesmen;

  // ✅ Active selected account (kept as "salesman" to avoid refactors)
  final Salesman? salesman;

  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.salesmen = const [],
    this.salesman,
    this.error,
  });

  bool get needsAccountSelection =>
      isAuthenticated && salesman == null && salesmen.length > 1;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    User? user,
    List<Salesman>? salesmen,
    Salesman? salesman,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      salesmen: salesmen ?? this.salesmen,
      salesman: salesman ?? this.salesman,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  static const _prefActiveSalesmanIdKey = 'active_salesman_id';

  Future<int?> _loadActiveSalesmanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefActiveSalesmanIdKey);
  }

  Future<void> _saveActiveSalesmanId(int? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_prefActiveSalesmanIdKey);
    } else {
      await prefs.setInt(_prefActiveSalesmanIdKey, id);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repo.login(email, password);
      final user = result['user'] as User;
      final salesmen = (result['salesmen'] as List<Salesman>?) ?? <Salesman>[];

      Salesman? active;

      if (salesmen.isEmpty) {
        active = null; // global/admin mode
      } else if (salesmen.length == 1) {
        active = salesmen.first;
        await _saveActiveSalesmanId(active.id);
      } else {
        // multi-account: try last used
        final savedId = await _loadActiveSalesmanId();
        if (savedId != null) {
          for (final s in salesmen) {
            if (s.id == savedId) {
              active = s;
              break;
            }
          }
        }
        // if still null -> AuthGate will route to AccountSelectPage
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: user,
        salesmen: salesmen,
        salesman: active,
        error: null,
      );

      print(
        'AuthNotifier.login → isAuthenticated=${state.isAuthenticated}, '
            'accounts=${state.salesmen.length}, activeSalesmanId=${state.salesman?.id}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
    }
  }

  Future<void> selectSalesman(Salesman s) async {
    state = state.copyWith(salesman: s, error: null);
    await _saveActiveSalesmanId(s.id);

    print('AuthNotifier.selectSalesman → activeSalesmanId=${s.id}, code=${s.code}');
  }

  Future<void> logout() async {
    await _saveActiveSalesmanId(null);
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
