import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return MaterialApp(
      title: 'PulangAman',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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
