import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulangaman/app.dart';
import 'package:pulangaman/core/strings.dart';
import 'package:pulangaman/features/auth/auth_controller.dart';
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
    _data['token'] = token;
    _data['userId'] = userId;
    _data['role'] = role;
    _data['name'] = name;
  }

  @override
  Future<String?> token() async => _data['token'];

  @override
  Future<String?> userId() async => _data['userId'];

  @override
  Future<String?> role() async => _data['role'];

  @override
  Future<String?> name() async => _data['name'];

  @override
  Future<void> clear() async => _data.clear();
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
    expect(find.text(AppStrings.brand), findsOneWidget);
    expect(find.text(AppStrings.sendOtpAction), findsWidgets);
  });
}
