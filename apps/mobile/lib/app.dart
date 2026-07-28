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
    // Instantiates provider so native VR prefs sync on startup.
    ref.watch(visualRefreshEnabledProvider);
    // Parent/child (and login) always use Visual Refresh. Guardian keeps classic.
    final useVisualRefreshTheme = !auth.isAuthenticated ||
        auth.role == AppRole.parent ||
        auth.role == AppRole.child;

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
