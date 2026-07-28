import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Design tokens for Visual Refresh (Approach A — in-place polish).
///
/// Applied when [visualRefreshOf] is true (see [buildVisualRefreshTheme]).
abstract final class VisualRefreshColors {
  static const background = Color(0xFFFAF7F0);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9E2D3);
  static const textPrimary = Color(0xFF182620);
  static const textSecondary = Color(0xFF8C8878);
  static const textTertiary = Color(0xFF948F7E);
  static const anchor = Color(0xFF16362C);
  static const accent = Color(0xFF2E6B4F);
  static const accentTint = Color(0xFFE3EFE5);
  static const danger = Color(0xFFA6432E);

  /// Live emergency only — EMP active card / home banner (not general info).
  static const dangerTint = Color(0xFFFBEDE9);
  static const dangerTintBorder = Color(0xFFE3BBAE);
  static const dangerTintText = Color(0xFF946354);

  static const warmTint = Color(0xFFF5F1E7);
  static const tagMuted = Color(0xFFF0ECE0);
  static const dashedAction = Color(0xFF9FC3AC);
  static const dashedDisplay = Color(0xFFC9BFA3);
  static const weatherTint = Color(0xFFF3E4C6);

  /// In-progress / not-yet-saved zone badge (Zones "ROUTE" tag).
  static const routeTint = weatherTint;
  static const routeText = Color(0xFFB3722E);

  /// Rewards & Points hero / streak / praise accents.
  static const rewardBg = Color(0xFFFBEFDD);
  static const rewardBorder = Color(0xFFF0DDB8);
  static const rewardAccent = Color(0xFFB3722E);
  static const praiseBtn = Color(0xFFD9A441);

  /// Hairline for flat in-flow cards (0.5 logical px).
  static const hairline = BorderSide(color: border, width: 0.5);

  static const popoverShadow = BoxShadow(
    color: Color(0x29141E19),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const dialogShadow = BoxShadow(
    color: Color(0x38141E19),
    blurRadius: 40,
    offset: Offset(0, 16),
  );
}

/// Full-screen reminder / EMP "moment" palette — intentionally separate from
/// routine [VisualRefreshColors] tokens (interrupting child-facing takeover).
abstract final class ReminderMomentColors {
  static const background = Color(0xFF16362C);
  static const illustrationBg = Color(0xFF2C4C41);
  static const title = Color(0xFFFAF7F0);
  static const mutedText = Color(0xFFB9CFC5);
  static const closeIcon = Color(0xFFB9CFC5);

  /// Bedtime — gold.
  static const sleepAccent = Color(0xFFE8B94D);

  /// Study preset — vivid accent green.
  static const studyAccent = Color(0xFF4A9F6C);

  /// Free-typed custom — softer sage.
  static const customAccent = Color(0xFF7C9A8B);

  /// Emergency meeting point — warm terracotta (not bedtime gold).
  static const empAccent = Color(0xFFD6875C);

  /// Dark ink on gold / green / terracotta pills.
  static const onAccent = Color(0xFF16362C);
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

  /// Visual refresh radii.
  static const vrChip = 12.0;
  static const vrCard = 16.0;
  static const vrHero = 22.0;
}

/// Marker that [buildVisualRefreshTheme] is active for this [ThemeData].
@immutable
class VisualRefreshTheme extends ThemeExtension<VisualRefreshTheme> {
  const VisualRefreshTheme();

  @override
  VisualRefreshTheme copyWith() => this;

  @override
  VisualRefreshTheme lerp(ThemeExtension<VisualRefreshTheme>? other, double t) =>
      this;
}

/// True when the parent app is using Visual Refresh tokens.
bool visualRefreshOf(BuildContext context) =>
    Theme.of(context).extension<VisualRefreshTheme>() != null;

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
      scrolledUnderElevation: 0,
      // Prevent M3 surface tint from washing AppBar toward seed/cream.
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      centerTitle: false,
      // Match PaScreenHeader: circular back chip → title gap.
      titleSpacing: 12,
      leadingWidth: 54,
      iconTheme: IconThemeData(color: AppColors.ink),
      actionsIconTheme: IconThemeData(color: AppColors.ink),
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

/// Visual Refresh parent theme: cream canvas, teal accents, Fraunces + Jakarta.
///
/// Visual Refresh theme (sole parent/child UI). Classic
/// [buildAppTheme] remains the default when the flag is off.
ThemeData buildVisualRefreshTheme([ThemeData? base]) {
  final app = base ?? buildAppTheme();
  final jakarta = GoogleFonts.plusJakartaSansTextTheme(app.textTheme);
  final textTheme = jakarta.copyWith(
    displayLarge: GoogleFonts.fraunces(
      textStyle: jakarta.displayLarge,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    ),
    displayMedium: GoogleFonts.fraunces(
      textStyle: jakarta.displayMedium,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    ),
    displaySmall: GoogleFonts.fraunces(
      textStyle: jakarta.displaySmall,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    ),
    headlineLarge: GoogleFonts.fraunces(
      textStyle: jakarta.headlineLarge,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.fraunces(
      textStyle: jakarta.headlineMedium,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.fraunces(
      textStyle: jakarta.headlineSmall,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      color: VisualRefreshColors.textPrimary,
    ),
    titleLarge: GoogleFonts.fraunces(
      textStyle: jakarta.titleLarge,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      color: VisualRefreshColors.textPrimary,
    ),
    titleMedium: GoogleFonts.fraunces(
      textStyle: jakarta.titleMedium,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      color: VisualRefreshColors.textPrimary,
    ),
    bodyLarge: GoogleFonts.plusJakartaSans(
      textStyle: jakarta.bodyLarge,
      color: VisualRefreshColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      textStyle: jakarta.bodyMedium,
      color: VisualRefreshColors.textPrimary,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      textStyle: jakarta.bodySmall,
      color: VisualRefreshColors.textSecondary,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      textStyle: jakarta.labelLarge,
      fontWeight: FontWeight.w600,
    ),
  );

  final scheme = app.colorScheme.copyWith(
    primary: VisualRefreshColors.anchor,
    onPrimary: VisualRefreshColors.background,
    secondary: VisualRefreshColors.accent,
    onSecondary: Colors.white,
    surface: VisualRefreshColors.surface,
    onSurface: VisualRefreshColors.textPrimary,
    error: VisualRefreshColors.danger,
  );

  return app.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: VisualRefreshColors.background,
    textTheme: textTheme,
    primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(app.primaryTextTheme),
    extensions: const <ThemeExtension<dynamic>>[VisualRefreshTheme()],
    appBarTheme: app.appBarTheme.copyWith(
      backgroundColor: VisualRefreshColors.background,
      foregroundColor: VisualRefreshColors.textPrimary,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: VisualRefreshColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: VisualRefreshColors.textPrimary),
      actionsIconTheme:
          const IconThemeData(color: VisualRefreshColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: VisualRefreshColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        side: VisualRefreshColors.hairline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VisualRefreshColors.anchor,
        foregroundColor: VisualRefreshColors.background,
        minimumSize: const Size(48, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: VisualRefreshColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: VisualRefreshColors.textPrimary,
      ),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 1.35,
        color: VisualRefreshColors.textSecondary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VisualRefreshColors.surface,
      indicatorColor: VisualRefreshColors.accentTint,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected
              ? VisualRefreshColors.anchor
              : VisualRefreshColors.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? VisualRefreshColors.anchor
              : VisualRefreshColors.textSecondary,
        );
      }),
    ),
    listTileTheme: app.listTileTheme.copyWith(
      iconColor: VisualRefreshColors.accent,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: VisualRefreshColors.textPrimary,
      ),
      subtitleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: VisualRefreshColors.textSecondary,
      ),
    ),
    dividerColor: VisualRefreshColors.border,
    sliderTheme: SliderThemeData(
      activeTrackColor: VisualRefreshColors.anchor,
      inactiveTrackColor: VisualRefreshColors.tagMuted,
      thumbColor: VisualRefreshColors.anchor,
      overlayColor: VisualRefreshColors.anchor.withValues(alpha: 0.12),
      trackHeight: 3,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: VisualRefreshColors.surface,
      dialHandColor: VisualRefreshColors.accent,
      dialBackgroundColor: VisualRefreshColors.accentTint,
      hourMinuteColor: VisualRefreshColors.accentTint,
      hourMinuteTextColor: VisualRefreshColors.anchor,
      dayPeriodColor: VisualRefreshColors.accentTint,
      dayPeriodTextColor: VisualRefreshColors.anchor,
      entryModeIconColor: VisualRefreshColors.accent,
      helpTextStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: VisualRefreshColors.textPrimary,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: VisualRefreshColors.surface,
      headerBackgroundColor: VisualRefreshColors.accentTint,
      headerForegroundColor: VisualRefreshColors.anchor,
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return VisualRefreshColors.accent;
        }
        return null;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return VisualRefreshColors.background;
        }
        return VisualRefreshColors.textPrimary;
      }),
      todayBorder: const BorderSide(color: VisualRefreshColors.accent),
      todayForegroundColor: WidgetStateProperty.all(VisualRefreshColors.accent),
      rangeSelectionBackgroundColor: VisualRefreshColors.accentTint,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return VisualRefreshColors.anchor;
        }
        return VisualRefreshColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return VisualRefreshColors.border;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return VisualRefreshColors.anchor.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
    ),
  );
}

/// @Deprecated Use [buildVisualRefreshTheme]. Kept as alias for any stray refs.
ThemeData buildPremiumEditorialTheme([ThemeData? base]) =>
    buildVisualRefreshTheme(base);
