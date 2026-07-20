import 'package:flutter/material.dart';

abstract final class AppColors {
  static const teal = Color(0xFF087F6D);
  static const tealDeep = Color(0xFF07584E);
  static const mint = Color(0xFFBDEEDB);
  static const coral = Color(0xFFFF746C);
  static const amber = Color(0xFFFFC857);
  static const sky = Color(0xFF74C9F5);
  static const lavender = Color(0xFFB7A7F8);
  static const sand = Color(0xFFFFF1D6);
  static const canvas = Color(0xFFFFFBF3);
  static const surface = Colors.white;
  static const ink = Color(0xFF18332D);
  static const inkSoft = Color(0xFF60736E);
  static const danger = Color(0xFFD63C32);
  static const success = Color(0xFF249B72);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    secondary: AppColors.coral,
    tertiary: AppColors.amber,
    surface: AppColors.surface,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  // Larger type for parents who wear glasses / are less technical.
  final textTheme = base.textTheme
      .apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: 'sans-serif',
      )
      .copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.4),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.35),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 15),
      );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        fontFamily: 'sans-serif',
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: Color(0x14075A4F)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      iconColor: AppColors.tealDeep,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0x1F075A4F)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.mint,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: selected ? 30 : 28,
          color: selected ? AppColors.tealDeep : AppColors.inkSoft,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? AppColors.tealDeep : AppColors.inkSoft,
        );
      }),
    ),
  );
}
