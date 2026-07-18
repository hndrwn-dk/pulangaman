import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/child/child_home_screen.dart';
import 'features/guardian/guardian_home_screen.dart';
import 'features/parent/parent_home_screen.dart';

class PulangAmanApp extends ConsumerWidget {
  const PulangAmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'PulangAman',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
        scaffoldBackgroundColor: AppColors.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
      ),
      home: auth.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !auth.isAuthenticated
              ? const LoginScreen()
              : switch (auth.role!) {
                  AppRole.parent => const ParentShell(),
                  AppRole.child => const ChildHomeScreen(),
                  AppRole.guardian => const GuardianHomeScreen(),
                },
    );
  }
}
