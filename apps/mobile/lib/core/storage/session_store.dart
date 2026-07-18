import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'role';
  static const _nameKey = 'name';

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

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
