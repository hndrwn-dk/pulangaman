import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/locale_controller.dart';
import 'core/notifications/push_service.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/child/child_home_screen.dart';
import 'features/child/reminder_channel.dart';
import 'features/guardian/guardian_home_screen.dart';
import 'features/parent/child_detail_screen.dart';
import 'features/parent/children_controller.dart';
import 'features/parent/parent_home_screen.dart';
import 'features/parent/visual_refresh_flag.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class PulangAmanApp extends ConsumerWidget {
  const PulangAmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    // Instantiates provider so native VR prefs sync on startup.
    ref.watch(visualRefreshEnabledProvider);
    // Keep native fullscreen reminder chrome in sync with Flutter locale.
    unawaited(_syncNativeAppLocale(locale.languageCode));
    ref.listen<Locale>(localeControllerProvider, (prev, next) {
      if (prev?.languageCode == next.languageCode) return;
      unawaited(_syncNativeAppLocale(next.languageCode));
    });
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        final pushService = PushService(ref.read(apiClientProvider));
        unawaited(pushService.registerToken());
        unawaited(
          pushService.init(onTapPayload: (data) => _handlePushTap(ref, data)),
        );
      }
      // Crashlytics: all roles. Analytics: parent/guardian only (Designed for Families).
      unawaited(_syncFirebaseTelemetry(next));
    });
    // Visual Refresh is always on for all roles.
    // Key forces a fresh navigator when auth flips, so logout leaves
    // pushed routes (e.g. Pengaturan Akun) and shows LoginScreen cleanly.
    // Locale is included so chrome (bottom nav / headers) never sticks on a
    // stale Localizations snapshot after a language switch.
    final homeKey = ValueKey<String>(
      auth.restoring
          ? 'restoring'
          : !auth.isAuthenticated
              ? 'login-${locale.languageCode}'
              : 'role-${auth.role!.name}-${locale.languageCode}',
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PulangAman',
      debugShowCheckedModeBanner: false,
      theme: buildVisualRefreshTheme(buildAppTheme()),
      // Keep native time pickers on 24-hour (matches Maghrib / "Home by HH:mm").
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: KeyedSubtree(
        key: homeKey,
        child: auth.restoring
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : !auth.isAuthenticated
                ? const LoginScreen()
                : switch (auth.role!) {
                    AppRole.parent => const ParentShell(),
                    AppRole.child => const ChildHomeScreen(),
                    AppRole.guardian => const GuardianHomeScreen(),
                  },
      ),
    );
  }
}

Future<void> _syncNativeAppLocale(String languageCode) async {
  try {
    await ReminderChannel().setAppLocale(languageCode);
  } catch (_) {
    // Native channel unavailable (tests / non-Android) — ignore.
  }
}

Future<void> _syncFirebaseTelemetry(AuthState auth) async {
  try {
    await FirebaseCrashlytics.instance.setUserIdentifier(
      auth.isAuthenticated ? (auth.userId ?? '') : '',
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      auth.isAuthenticated && auth.role != AppRole.child,
    );
  } catch (_) {
    // Telemetry must never block navigation / logout.
  }
}

Future<void> _handlePushTap(WidgetRef ref, Map<String, dynamic> data) async {
  if (data['route'] != 'child_detail') return;
  final childId = data['childId'] as String?;
  if (childId == null) return;
  final childrenNotifier = ref.read(childrenControllerProvider.notifier);
  var children = ref.read(childrenControllerProvider).items;
  if (children.where((c) => c.id == childId).isEmpty) {
    await childrenNotifier.refresh();
    children = ref.read(childrenControllerProvider).items;
  }
  ChildSummary? match;
  for (final c in children) {
    if (c.id == childId) {
      match = c;
      break;
    }
  }
  if (match == null) return;
  final child = match;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => ChildDetailScreen(child: child)),
  );
}
