import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pulangaman/core/locale_controller.dart';
import 'package:pulangaman/core/network/api_client.dart';
import 'package:pulangaman/core/storage/session_store.dart';
import 'package:pulangaman/features/auth/auth_controller.dart';
import 'package:pulangaman/features/parent/children_controller.dart';
import 'package:pulangaman/features/parent/parent_home_screen.dart';
import 'package:pulangaman/l10n/app_localizations.dart';

class _MemorySessionStore extends SessionStore {
  final Map<String, String> _data = {};
  @override
  Future<void> save({required String token, required String userId, required String role, required String name}) async {
    _data['auth_token'] = token; _data['user_id'] = userId; _data['role'] = role; _data['name'] = name;
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
  Future<void> clear() async { _data.remove('auth_token'); _data.remove('user_id'); _data.remove('role'); _data.remove('name'); }
  @override
  Future<void> saveLocale(String languageCode) async => _data['locale_override'] = languageCode;
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
    return raw == '1';
  }
  @override
  Future<void> clearVisualRefresh() async {
    _data.remove('visual_refresh');
  }
}

void main() {
  testWidgets('ParentShell bottom nav follows locale', (tester) async {
    final store = _MemorySessionStore();
    final mock = MockClient((request) async {
      return http.Response('{"children":[],"invites":[]}', 200);
    });
    final api = ApiClient(client: mock, baseUrl: 'http://test.local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(api),
          localeControllerProvider.overrideWith(
            (ref) => LocaleController(store: store, deviceLocale: const Locale('id')),
          ),
          authControllerProvider.overrideWith((ref) {
            final c = AuthController(api: api, store: store);
            // skip restore noise
            return c;
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final locale = ref.watch(localeControllerProvider);
            return MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ParentShell(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anak'), findsWidgets);
    expect(find.text('Lainnya'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(ParentShell)));
    await container.read(localeControllerProvider.notifier).setLocale(const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('Children'), findsWidgets);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Anak'), findsNothing);
    expect(find.text('Lainnya'), findsNothing);
  });
}
