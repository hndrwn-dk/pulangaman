import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    this.restoring = false,
    this.awaitingOtp = false,
    this.error,
  });

  final String? token;
  final String? userId;
  final AppRole? role;
  final String? name;
  final bool loading;
  /// True only while reading/refreshing persisted session at app start.
  final bool restoring;
  final bool awaitingOtp;
  final String? error;

  bool get isAuthenticated => token != null && userId != null && role != null;

  AuthState copyWith({
    String? token,
    String? userId,
    AppRole? role,
    String? name,
    bool? loading,
    bool? restoring,
    bool? awaitingOtp,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
      awaitingOtp: awaitingOtp ?? this.awaitingOtp,
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
      : super(const AuthState(restoring: true)) {
    restore();
  }

  final ApiClient api;
  final SessionStore store;

  String? _verificationId;
  int? _resendToken;
  String? _pendingName;
  String? _pendingPhone;
  AppRole? _pendingRole;

  Future<void> restore() async {
    state = state.copyWith(restoring: true, clearError: true);
    try {
      var token = await store.token();
      final userId = await store.userId();
      final roleRaw = await store.role();
      final name = await store.name();
      if (token == null || userId == null || roleRaw == null) {
        state = const AuthState();
        return;
      }

      if (!AppConfig.useDevAuth && Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await store.clear();
          state = const AuthState();
          return;
        }
        token = await user.getIdToken(true);
        if (token == null) {
          await store.clear();
          state = const AuthState();
          return;
        }
        await store.save(
          token: token,
          userId: userId,
          role: roleRaw,
          name: name ?? '',
        );
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

  /// Wake Render free-tier before session calls (OTP / invite).
  void _warmApiInBackground() {
    unawaited(() async {
      try {
        await api.get('/health', timeout: const Duration(seconds: 60));
      } catch (_) {}
    }());
  }

  Future<void> login({
    required String name,
    required String phone,
    required AppRole role,
  }) async {
    state = state.copyWith(loading: true, awaitingOtp: false, clearError: true);
    try {
      if (AppConfig.useDevAuth) {
        await _completeDevLogin(name: name, phone: phone, role: role);
        return;
      }
      _warmApiInBackground();
      await _startPhoneOtp(
        name: name.trim(),
        phone: normalizePhoneE164(phone),
        role: role,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        awaitingOtp: false,
        error: _friendlyAuthError(e),
      );
    }
  }

  Future<void> confirmOtp(String smsCode) async {
    final verificationId = _verificationId;
    final name = _pendingName;
    final phone = _pendingPhone;
    final role = _pendingRole;
    if (verificationId == null ||
        name == null ||
        phone == null ||
        role == null) {
      state = state.copyWith(error: 'Sesi OTP tidak valid. Minta kode ulang.');
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await _signInAndCreateSession(
        credential: credential,
        name: name,
        phone: phone,
        role: role,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyAuthError(e));
    }
  }

  Future<void> resendOtp() async {
    final name = _pendingName;
    final phone = _pendingPhone;
    final role = _pendingRole;
    if (name == null || phone == null || role == null) {
      state = state.copyWith(error: 'Sesi OTP tidak valid. Isi formulir lagi.');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _startPhoneOtp(name: name, phone: phone, role: role, resend: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyAuthError(e));
    }
  }

  void cancelOtp() {
    _verificationId = null;
    _resendToken = null;
    _pendingName = null;
    _pendingPhone = null;
    _pendingRole = null;
    state = state.copyWith(awaitingOtp: false, loading: false, clearError: true);
  }

  /// Child joins via parent invite code (no phone match needed).
  Future<void> joinWithInvite({
    required String name,
    required String inviteCode,
  }) async {
    state = state.copyWith(loading: true, awaitingOtp: false, clearError: true);
    try {
      _warmApiInBackground();
      final joined = await api.post('/api/v1/child-invites/join', body: {
        'name': name.trim(),
        'code': inviteCode.trim().toUpperCase(),
      });

      final firebaseUid = joined['firebaseUid'] as String;
      final userId = joined['userId'] as String;
      final displayName = (joined['name'] as String?)?.trim().isNotEmpty == true
          ? joined['name'] as String
          : name.trim();

      late final String token;
      if (AppConfig.useDevAuth) {
        token = joined['tokenHint'] as String? ?? 'dev:$firebaseUid';
      } else {
        final customToken = joined['customToken'] as String?;
        if (customToken == null || customToken.isEmpty) {
          throw StateError(
            'Server tidak mengembalikan customToken. Deploy API terbaru dulu.',
          );
        }
        final cred =
            await FirebaseAuth.instance.signInWithCustomToken(customToken);
        final idToken = await cred.user?.getIdToken();
        if (idToken == null) {
          throw StateError('Gagal mengambil ID token Firebase.');
        }
        token = idToken;
      }

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
      state = state.copyWith(loading: false, error: _friendlyAuthError(e));
    }
  }

  Future<void> logout() async {
    if (!AppConfig.useDevAuth && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    await store.clear();
    api.setToken(null);
    cancelOtp();
    state = const AuthState();
  }

  Future<void> _completeDevLogin({
    required String name,
    required String phone,
    required AppRole role,
  }) async {
    final firebaseUid = _devUid(role, phone);
    final token = 'dev:$firebaseUid';
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
  }

  Future<void> _startPhoneOtp({
    required String name,
    required String phone,
    required AppRole role,
    bool resend = false,
  }) async {
    _pendingName = name;
    _pendingPhone = phone;
    _pendingRole = role;

    final completer = Completer<void>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _signInAndCreateSession(
            credential: credential,
            name: name,
            phone: phone,
            role: role,
          );
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        // Instant verification may already have signed in; do not reopen OTP UI.
        if (state.isAuthenticated) return;
        _verificationId = verificationId;
        _resendToken = resendToken;
        state = state.copyWith(
          loading: false,
          awaitingOtp: true,
          clearError: true,
        );
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );

    await completer.future;
  }

  Future<void> _signInAndCreateSession({
    required AuthCredential credential,
    required String name,
    required String phone,
    required AppRole role,
  }) async {
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await cred.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Gagal mengambil ID token Firebase.');
    }

    api.setToken(idToken);
    final session = await api.post('/api/v1/auth/session', body: {
      'name': name.trim(),
      'phone': phone,
      'role': role.name,
    });

    final userId = session['userId'] as String;
    await store.save(
      token: idToken,
      userId: userId,
      role: role.name,
      name: name.trim(),
    );

    _verificationId = null;
    _resendToken = null;
    _pendingName = null;
    _pendingPhone = null;
    _pendingRole = null;

    state = AuthState(
      token: idToken,
      userId: userId,
      role: role,
      name: name.trim(),
    );
  }

  /// Move children from a legacy parent phone onto the current Firebase parent.
  Future<int> recoverChildrenFromPhone(String previousPhone) async {
    if (state.role != AppRole.parent || state.token == null) {
      throw StateError('Hanya orang tua yang sedang masuk yang bisa memulihkan.');
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      var token = state.token!;
      if (!AppConfig.useDevAuth && Firebase.apps.isNotEmpty) {
        final refreshed =
            await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (refreshed != null) {
          token = refreshed;
          api.setToken(token);
        }
      }

      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
          _pendingPhone ??
          '';
      if (phone.isEmpty) {
        throw StateError(
          'Nomor Firebase tidak ditemukan. Keluar lalu masuk OTP lagi.',
        );
      }

      final session = await api.post('/api/v1/auth/session', body: {
        'name': state.name ?? 'Orang tua',
        'phone': phone,
        'role': AppRole.parent.name,
        'recoverFromPhone': normalizePhoneE164(previousPhone),
      });

      final userId = session['userId'] as String;
      final recovered = (session['recoveredChildren'] as num?)?.toInt() ?? 0;
      await store.save(
        token: token,
        userId: userId,
        role: AppRole.parent.name,
        name: state.name ?? 'Orang tua',
      );
      state = AuthState(
        token: token,
        userId: userId,
        role: AppRole.parent,
        name: state.name,
      );
      return recovered;
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyAuthError(e));
      rethrow;
    }
  }

  String _devUid(AppRole role, String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return '${role.name}_$normalized';
  }
}

String normalizePhoneE164(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
  if (trimmed.startsWith('+')) {
    return '+${trimmed.substring(1).replaceAll(RegExp(r'\D'), '')}';
  }
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    return '+62${digits.substring(1)}';
  }
  if (digits.startsWith('62')) {
    return '+$digits';
  }
  return '+$digits';
}

String _friendlyAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Nomor telepon tidak valid. Gunakan format +62...';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'invalid-verification-code':
        return 'Kode OTP salah.';
      case 'session-expired':
        return 'Kode OTP kedaluwarsa. Kirim ulang.';
      case 'missing-client-identifier':
        return 'Konfigurasi Firebase Android belum lengkap (SHA / google-services).';
      default:
        return e.message ?? e.code;
    }
  }
  return e.toString();
}
