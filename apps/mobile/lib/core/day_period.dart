import 'package:flutter/material.dart';

import 'theme.dart';

/// Local-time bands used for greetings and top-bar icons.
enum DayPeriod { morning, midday, afternoon, night }

DayPeriod dayPeriodFor([DateTime? when]) {
  final h = (when ?? DateTime.now()).hour;
  if (h < 11) return DayPeriod.morning;
  if (h < 15) return DayPeriod.midday;
  if (h < 18) return DayPeriod.afternoon;
  return DayPeriod.night;
}

extension DayPeriodUi on DayPeriod {
  String get greetingId {
    switch (this) {
      case DayPeriod.morning:
        return 'Selamat pagi';
      case DayPeriod.midday:
        return 'Selamat siang';
      case DayPeriod.afternoon:
        return 'Selamat sore';
      case DayPeriod.night:
        return 'Selamat malam';
    }
  }

  String get shortId {
    switch (this) {
      case DayPeriod.morning:
        return 'Pagi';
      case DayPeriod.midday:
        return 'Siang';
      case DayPeriod.afternoon:
        return 'Sore';
      case DayPeriod.night:
        return 'Malam';
    }
  }

  IconData get icon {
    switch (this) {
      case DayPeriod.morning:
        return Icons.wb_twilight_rounded;
      case DayPeriod.midday:
        return Icons.wb_sunny_rounded;
      case DayPeriod.afternoon:
        return Icons.brightness_5_rounded;
      case DayPeriod.night:
        return Icons.nights_stay_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case DayPeriod.morning:
        return const Color(0xFFFFB020);
      case DayPeriod.midday:
        return AppColors.amber;
      case DayPeriod.afternoon:
        return AppColors.coral;
      case DayPeriod.night:
        return const Color(0xFF5B6CDB);
    }
  }
}
