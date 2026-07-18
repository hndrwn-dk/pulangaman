import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';

class PulangAmanApp extends StatelessWidget {
  const PulangAmanApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      ),
      home: const HomeScreen(),
    );
  }
}
