import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulangaman/app.dart';
import 'package:pulangaman/core/storage/session_store.dart';

class _MemorySessionStore extends SessionStore {
  final Map<String, String> _data = {};

  @override
  Future<void> save({
    required String token,
    required String userId,
    required String role,
    required String name,
  }) async {
    _data['auth_token'] = token;
    _data['user_id'] = userId;
    _data['role'] = role;
    _data['name'] = name;
  }

  @override
  Future<String?> token() async => _data['auth_token'];

  @override
  Future<String?> userId() async => _data['user_id'];

  @override
  Future<String?> role() async => _data['role'];

  @override
  Future<String?> name() async => _data['name'];

  @override
  Future<void> saveLocale(String languageCode) async {
    _data['locale_override'] = languageCode;
  }

  @override
  Future<String?> locale() async => _data['locale_override'];

  @override
  Future<void> saveVisualRefresh(bool enabled) async {
    _data['visual_refresh'] = enabled ? '1' : '0';
  }

  @override
  Future<bool?> visualRefresh() async {
    final raw = _data['visual_refresh'];
    if (raw == null) return null;
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  @override
  Future<void> clearVisualRefresh() async {
    _data.remove('visual_refresh');
  }

  @override
  Future<void> clear() async {
    _data.remove('auth_token');
    _data.remove('user_id');
    _data.remove('role');
    _data.remove('name');
  }
}

void main() {
  testWidgets('login shows PulangAman brand', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_MemorySessionStore()),
        ],
        child: const PulangAmanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pulang Aman'), findsOneWidget);
    expect(find.textContaining('OTP'), findsWidgets);
  });
}
