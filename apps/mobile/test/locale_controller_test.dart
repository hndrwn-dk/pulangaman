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
import 'package:pulangaman/features/parent/home_by_screen.dart';
import 'package:pulangaman/l10n/app_localizations.dart';

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
    return raw == '1';
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

  Map<String, String> get debugData => Map.unmodifiable(_data);
}

void main() {
  group('LocaleController', () {
    test('saved preference wins over device locale', () async {
      final store = _MemorySessionStore();
      await store.saveLocale('en');
      final controller = LocaleController(
        store: store,
        deviceLocale: const Locale('id'),
      );
      await controller.init();
      expect(controller.state.languageCode, 'en');
    });

    test('falls back to supported device locale when nothing saved', () async {
      final store = _MemorySessionStore();
      final controller = LocaleController(
        store: store,
        deviceLocale: const Locale('en'),
      );
      await controller.init();
      expect(controller.state.languageCode, 'en');
    });

    test('falls back to id when device locale unsupported', () async {
      final store = _MemorySessionStore();
      final controller = LocaleController(
        store: store,
        deviceLocale: const Locale('ja'),
      );
      await controller.init();
      expect(controller.state.languageCode, 'id');
    });

    test('setLocale persists and clear auth keeps locale', () async {
      final store = _MemorySessionStore();
      final controller = LocaleController(
        store: store,
        deviceLocale: const Locale('id'),
      );
      await controller.init();
      await controller.setLocale(const Locale('en'));
      expect(await store.locale(), 'en');

      await store.save(
        token: 't',
        userId: 'u',
        role: 'parent',
        name: 'Test',
      );
      await store.clear();
      expect(await store.token(), isNull);
      expect(await store.locale(), 'en');
    });
  });

  group('locale switches migrated UI', () {
    ApiClient buildFakeApi() {
      final mock = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/today')) {
          return http.Response(
            '{"today":{"status":"pending","targetTime":"2026-07-25T11:03:00.000Z"}}',
            200,
          );
        }
        if (path.endsWith('/skip-dates')) {
          return http.Response('{"skipDates":[]}', 200);
        }
        return http.Response(
          '{"settings":{"mode":"maghrib","customHour":18,"customMinute":30,'
          '"gracePeriodMinutes":30,"weekendMode":"same"}}',
          200,
        );
      });
      return ApiClient(client: mock, baseUrl: 'http://test.local');
    }

    testWidgets('HomeByScreen title follows localeControllerProvider',
        (tester) async {
      final store = _MemorySessionStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(buildFakeApi()),
            localeControllerProvider.overrideWith(
              (ref) => LocaleController(
                store: store,
                deviceLocale: const Locale('id'),
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeControllerProvider);
              return MaterialApp(
                locale: locale,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: HomeByScreen(
                  lockedChild: ChildSummary(id: 'child-1', name: 'Andi'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jam Pulang Aman'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeByScreen)),
      );
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.text('Safe Home Time'), findsOneWidget);
      expect(find.text('Jam Pulang Aman'), findsNothing);
    });
  });
}
