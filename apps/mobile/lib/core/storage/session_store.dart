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
  /// Child acknowledged the background-location disclosure screen.
  static const _bgLocationDisclosureKey = 'bg_location_disclosure_acked';

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

  Future<void> saveBgLocationDisclosureAcked() =>
      _storage.write(key: _bgLocationDisclosureKey, value: '1');

  Future<bool> bgLocationDisclosureAcked() async {
    final raw = await _storage.read(key: _bgLocationDisclosureKey);
    return raw == '1' || raw?.toLowerCase() == 'true';
  }

  /// Clears auth session only — keeps [locale] and disclosure ack.
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
