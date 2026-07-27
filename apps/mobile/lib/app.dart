import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/locale_controller.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/child/child_home_screen.dart';
import 'features/guardian/guardian_home_screen.dart';
import 'features/parent/parent_home_screen.dart';
import 'features/parent/visual_refresh_flag.dart';

class PulangAmanApp extends ConsumerWidget {
  const PulangAmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final visualRefresh = ref.watch(visualRefreshEnabledProvider);
    // Parent Account toggle / dart-define; child uses the same provider
    // (compile-time VISUAL_REFRESH or SessionStore if set on that device).
    // Also apply VR theme on the unauthenticated login route so Masuk matches
    // the rest of the refresh before SessionStore preference finishes loading
    // (provider already starts from AppConfig.visualRefresh).
    final useVisualRefreshTheme = visualRefresh &&
        (!auth.isAuthenticated ||
            auth.role == AppRole.parent ||
            auth.role == AppRole.child);

    // Key forces a fresh navigator when auth flips, so logout leaves
    // pushed routes (e.g. Pengaturan Akun) and shows LoginScreen cleanly.
    // Locale is included so chrome (bottom nav / headers) never sticks on a
    // stale Localizations snapshot after a language switch.
    // Visual-refresh flag included so classic <-> refresh swaps rebuild cleanly.
    final homeKey = ValueKey<String>(
      auth.restoring
          ? 'restoring'
          : !auth.isAuthenticated
              ? 'login-${locale.languageCode}'
                  '-${visualRefresh ? 'vr' : 'classic'}'
              : 'role-${auth.role!.name}-${locale.languageCode}'
                  '-${visualRefresh ? 'vr' : 'classic'}',
    );

    return MaterialApp(
      title: 'PulangAman',
      debugShowCheckedModeBanner: false,
      theme: useVisualRefreshTheme
          ? buildVisualRefreshTheme(buildAppTheme())
          : buildAppTheme(),
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
