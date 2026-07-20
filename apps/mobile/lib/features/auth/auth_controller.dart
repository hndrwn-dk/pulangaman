import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';

enum AppRole { parent, child, guardian }

class AuthState {
  const AuthState({
    this.token,
    this.userId,
    this.role,
    this.name,
    this.loading = false,
    this.error,
  });

  final String? token;
  final String? userId;
  final AppRole? role;
  final String? name;
  final bool loading;
  final String? error;

  bool get isAuthenticated => token != null && userId != null && role != null;

  AuthState copyWith({
    String? token,
    String? userId,
    AppRole? role,
    String? name,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    api: ref.watch(apiClientProvider),
    store: ref.watch(sessionStoreProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.api, required this.store})
      : super(const AuthState()) {
    restore();
  }

  final ApiClient api;
  final SessionStore store;

  Future<void> restore() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final token = await store.token();
      final userId = await store.userId();
      final roleRaw = await store.role();
      final name = await store.name();
      if (token == null || userId == null || roleRaw == null) {
        state = const AuthState();
        return;
      }
      api.setToken(token);
      state = AuthState(
        token: token,
        userId: userId,
        role: AppRole.values.byName(roleRaw),
        name: name,
      );
    } catch (_) {
      // Secure storage unavailable (e.g. widget tests) — start logged out.
      state = const AuthState();
    }
  }

  Future<void> login({
    required String name,
    required String phone,
    required AppRole role,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final firebaseUid = _devUid(role, phone);
      final token = AppConfig.useDevAuth ? 'dev:$firebaseUid' : firebaseUid;
      api.setToken(token);

      final session = await api.post('/api/v1/auth/session', body: {
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role.name,
      });

      final userId = session['userId'] as String;
      await store.save(
        token: token,
        userId: userId,
        role: role.name,
        name: name.trim(),
      );

      state = AuthState(
        token: token,
        userId: userId,
        role: role,
        name: name.trim(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Child joins via parent invite code (no phone match needed).
  Future<void> joinWithInvite({
    required String name,
    required String inviteCode,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final joined = await api.post('/api/v1/child-invites/join', body: {
        'name': name.trim(),
        'code': inviteCode.trim().toUpperCase(),
      });

      final firebaseUid = joined['firebaseUid'] as String;
      final token = AppConfig.useDevAuth
          ? (joined['tokenHint'] as String? ?? 'dev:$firebaseUid')
          : firebaseUid;
      final userId = joined['userId'] as String;
      final displayName = (joined['name'] as String?)?.trim().isNotEmpty == true
          ? joined['name'] as String
          : name.trim();

      api.setToken(token);
      await store.save(
        token: token,
        userId: userId,
        role: AppRole.child.name,
        name: displayName,
      );

      state = AuthState(
        token: token,
        userId: userId,
        role: AppRole.child,
        name: displayName,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await store.clear();
    api.setToken(null);
    state = const AuthState();
  }

  String _devUid(AppRole role, String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return '${role.name}_$normalized';
  }
}
