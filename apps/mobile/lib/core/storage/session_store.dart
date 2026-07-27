import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'role';
  static const _nameKey = 'name';
  static const _localeKey = 'locale_override';
  /// Runtime override for Visual Refresh (`'1'` / `'0'`). Null = use dart-define.
  static const _visualRefreshKey = 'visual_refresh';

  Future<void> save({
    required String token,
    required String userId,
    required String role,
    required String name,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _nameKey, value: name);
  }

  Future<String?> token() => _storage.read(key: _tokenKey);
  Future<String?> userId() => _storage.read(key: _userIdKey);
  Future<String?> role() => _storage.read(key: _roleKey);
  Future<String?> name() => _storage.read(key: _nameKey);

  Future<void> saveLocale(String languageCode) =>
      _storage.write(key: _localeKey, value: languageCode);

  Future<String?> locale() => _storage.read(key: _localeKey);

  /// Persists runtime Visual Refresh preference. Survives logout (like locale).
  Future<void> saveVisualRefresh(bool enabled) =>
      _storage.write(key: _visualRefreshKey, value: enabled ? '1' : '0');

  /// `null` when unset — callers should fall back to dart-define default.
  Future<bool?> visualRefresh() async {
    final raw = await _storage.read(key: _visualRefreshKey);
    if (raw == null) return null;
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  Future<void> clearVisualRefresh() =>
      _storage.delete(key: _visualRefreshKey);

  /// Clears auth session only — keeps [locale] and visual-refresh preference.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _roleKey),
      _storage.delete(key: _nameKey),
    ]);
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());
