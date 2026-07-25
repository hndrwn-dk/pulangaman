import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pulangaman/core/network/api_client.dart';
import 'package:pulangaman/features/auth/auth_controller.dart';
import 'package:pulangaman/features/parent/children_controller.dart';
import 'package:pulangaman/features/parent/emergency_meeting_screen.dart';
import 'package:pulangaman/l10n/app_localizations.dart';

void main() {
  testWidgets('activate button hidden when no meeting point configured',
      (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'point': null,
            'distanceLabel': null,
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'points': []}), 200);
    });
    final api = ApiClient(client: mock, baseUrl: 'http://test.local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          childrenControllerProvider.overrideWith(
            (ref) => _FakeChildren(ref, [
              ChildSummary(id: 'c1', name: 'Andi'),
              ChildSummary(id: 'c2', name: 'Zahira'),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: const EmergencyMeetingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emp_activate_button')), findsNothing);
    expect(find.text('Andi'), findsNothing);
    expect(find.text('Zahira'), findsNothing);
    expect(find.text('Belum ada titik kumpul'), findsOneWidget);
  });

  testWidgets('activate requires confirmation dialog before POST',
      (tester) async {
    var activateCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.contains('/activate')) {
        activateCalls += 1;
        return http.Response(
          jsonEncode({
            'activationId': 'a1',
            'targets': [],
            'activatedAt': DateTime.now().toIso8601String(),
          }),
          201,
        );
      }
      if (request.url.path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'point': {
              'id': 'p1',
              'name': 'Lapangan',
              'isPrimary': true,
              'lat': -6.2,
              'lng': 106.8,
            },
            'distanceLabel': '120 m',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'points': [
            {
              'id': 'p1',
              'name': 'Lapangan',
              'isPrimary': true,
              'instructions': null,
              'lat': -6.2,
              'lng': 106.8,
            }
          ],
        }),
        200,
      );
    });
    final api = ApiClient(client: mock, baseUrl: 'http://test.local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          childrenControllerProvider.overrideWith(
            (ref) => _FakeChildren(ref, [
              ChildSummary(id: 'c1', name: 'Andi'),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: EmergencyMeetingScreen(
            lockedChild: ChildSummary(id: 'c1', name: 'Andi'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('emp_activate_button')),
      200,
    );
    await tester.tap(find.byKey(const Key('emp_activate_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Semua anak dan wali'), findsOneWidget);
    expect(activateCalls, 0);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(activateCalls, 0);

    await tester.tap(find.byKey(const Key('emp_activate_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan sekarang'));
    await tester.pumpAndSettle();
    expect(activateCalls, 1);
  });

  testWidgets('delete requires confirmation before DELETE', (tester) async {
    var clearAllCalls = 0;
    final mock = MockClient((request) async {
      if (request.method == 'DELETE' &&
          request.url.path.endsWith('/emergency-meeting-points/clear-all')) {
        clearAllCalls += 1;
        return http.Response(jsonEncode({'ok': true, 'deleted': 2}), 200);
      }
      if (request.url.path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'point': clearAllCalls > 0
                ? null
                : {
                    'id': 'p1',
                    'name': 'Lapangan',
                    'isPrimary': true,
                    'lat': -6.2,
                    'lng': 106.8,
                  },
            'distanceLabel': clearAllCalls > 0 ? null : '120 m',
          }),
          200,
        );
      }
      if (clearAllCalls > 0) {
        return http.Response(jsonEncode({'points': []}), 200);
      }
      return http.Response(
        jsonEncode({
          'points': [
            {
              'id': 'p1',
              'name': 'Lapangan',
              'isPrimary': true,
              'instructions': null,
              'lat': -6.2,
              'lng': 106.8,
            }
          ],
        }),
        200,
      );
    });
    final api = ApiClient(client: mock, baseUrl: 'http://test.local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          childrenControllerProvider.overrideWith(
            (ref) => _FakeChildren(ref, [
              ChildSummary(id: 'c1', name: 'Andi'),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: EmergencyMeetingScreen(
            lockedChild: ChildSummary(id: 'c1', name: 'Andi'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('emp_delete_button')));
    await tester.pumpAndSettle();
    expect(find.text('Hapus titik kumpul untuk semua anak?'), findsOneWidget);
    expect(clearAllCalls, 0);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(clearAllCalls, 0);

    await tester.tap(find.byKey(const Key('emp_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(clearAllCalls, 1);
    expect(find.byKey(const Key('emp_activate_button')), findsNothing);
  });
}

class _FakeChildren extends ChildrenController {
  _FakeChildren(super.ref, List<ChildSummary> items) {
    state = ChildrenState(items: items, loading: false);
  }

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> refresh({bool force = false}) async {}
}
