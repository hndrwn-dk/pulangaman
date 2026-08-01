import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pulangaman/core/network/api_client.dart';
import 'package:pulangaman/features/auth/auth_controller.dart';
import 'package:pulangaman/features/child/child_beranda_tab.dart';
import 'package:pulangaman/features/parent/children_controller.dart';
import 'package:pulangaman/features/parent/home_by_screen.dart';
import 'package:pulangaman/l10n/app_localizations.dart';

void main() {
  group('HomeByScreen', () {
    late List<http.Request> putRequests;

    ApiClient buildFakeApi({String mode = 'maghrib'}) {
      putRequests = [];
      final mock = MockClient((request) async {
        if (request.method == 'PUT') {
          putRequests.add(request);
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        final path = request.url.path;
        if (path.endsWith('/today')) {
          return http.Response(
            jsonEncode({
              'today': {
                'status': 'pending',
                'targetTime': '2026-07-25T11:03:00.000Z',
              },
            }),
            200,
          );
        }
        if (path.endsWith('/skip-dates')) {
          return http.Response(jsonEncode({'skipDates': []}), 200);
        }
        return http.Response(
          jsonEncode({
            'settings': {
              'mode': mode,
              'customHour': 18,
              'customMinute': 30,
              'gracePeriodMinutes': 30,
              'weekendMode': 'same',
            },
          }),
          200,
        );
      });
      return ApiClient(client: mock, baseUrl: 'http://test.local');
    }

    Widget buildScreen(ApiClient api) {
      return ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: HomeByScreen(
            lockedChild: ChildSummary(id: 'child-1', name: 'Andi'),
          ),
        ),
      );
    }

    testWidgets('shows loaded settings for maghrib mode', (tester) async {
      await tester.pumpWidget(buildScreen(buildFakeApi()));
      await tester.pumpAndSettle();

      expect(find.text('Jam Pulang Aman'), findsOneWidget);
      expect(find.text('Andi'), findsOneWidget);
      expect(find.text('Ikuti waktu Maghrib'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Menunggu jam pulang'), 200);
      expect(find.text('Menunggu jam pulang'), findsOneWidget);
    });

    testWidgets('switching to fixed time reveals picker and saves mode',
        (tester) async {
      await tester.pumpWidget(buildScreen(buildFakeApi()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jam tetap'));
      await tester.pumpAndSettle();
      expect(find.text('18:30'), findsWidgets);

      await tester.scrollUntilVisible(find.text('Simpan'), 200);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(putRequests, hasLength(1));
      final body = jsonDecode(putRequests.single.body) as Map<String, dynamic>;
      expect(body['mode'], 'custom');
      expect(body['customHour'], 18);
      expect(body['customMinute'], 30);
    });
  });

  group('ChildBerandaTab home-by ack card', () {
    Widget buildTab({
      required bool ackVisible,
      required bool ackSent,
      VoidCallback? onAck,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(
          body: ChildBerandaTab(
            childName: 'Andi',
            tracking: true,
            points: 0,
            streak: 0,
            usageAccess: false,
            accessibility: false,
            todayUsageSeconds: 0,
            status: null,
            panicInFlight: false,
            panicOnCooldown: false,
            reminderCount: 0,
            exactAlarmOk: true,
            onPanicTap: () {},
            onOpenUsageSettings: () {},
            onOpenAccessibilitySettings: () {},
            onOpenReminderPermissions: () {},
            onOpenScreenTab: () {},
            onOpenRewards: () {},
            onOpenRemindersSheet: () {},
            onOpenScreenPermissionSetup: () {},
            homeByAckVisible: ackVisible,
            homeByAckSent: ackSent,
            onHomeByAck: onAck,
          ),
        ),
      );
    }

    testWidgets('hidden when there is no active home-by window',
        (tester) async {
      await tester.pumpWidget(buildTab(ackVisible: false, ackSent: false));
      expect(find.text('Aku otw pulang'), findsNothing);
      expect(find.text('Beri kabar ke orang tua'), findsNothing);
    });

    testWidgets('shows button and fires callback when window is active',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTab(
          ackVisible: true,
          ackSent: false,
          onAck: () => tapped = true,
        ),
      );
      expect(find.text('Aku otw pulang'), findsOneWidget);

      await tester.tap(find.text('Beri kabar ke orang tua'));
      expect(tapped, isTrue);
    });

    testWidgets('shows sent state without the button', (tester) async {
      await tester.pumpWidget(buildTab(ackVisible: false, ackSent: true));
      expect(find.text('Sudah dikirim ke orang tua'), findsOneWidget);
      expect(find.text('Beri kabar ke orang tua'), findsNothing);
    });
  });
}
