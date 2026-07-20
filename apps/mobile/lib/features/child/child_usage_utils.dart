import 'package:flutter/material.dart';

class UsageAppEntry {
  UsageAppEntry({
    required this.packageName,
    required this.durationSeconds,
    this.appLabel,
  });

  final String packageName;
  final int durationSeconds;
  final String? appLabel;

  factory UsageAppEntry.fromJson(Map<String, dynamic> json) {
    return UsageAppEntry(
      packageName: json['packageName'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      appLabel: json['appLabel'] as String?,
    );
  }
}

enum UsagePeriod { today, week, month }

extension UsagePeriodX on UsagePeriod {
  String get apiValue {
    switch (this) {
      case UsagePeriod.today:
        return 'today';
      case UsagePeriod.week:
        return 'week';
      case UsagePeriod.month:
        return 'month';
    }
  }

  String get label {
    switch (this) {
      case UsagePeriod.today:
        return 'Hari ini';
      case UsagePeriod.week:
        return 'Minggu ini';
      case UsagePeriod.month:
        return 'Bulan ini';
    }
  }

  String get shortLabel {
    switch (this) {
      case UsagePeriod.today:
        return 'Hari';
      case UsagePeriod.week:
        return 'Minggu';
      case UsagePeriod.month:
        return 'Bulan';
    }
  }
}

String formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 mnt';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '$hours jam $minutes mnt';
  return '$minutes mnt';
}

/// Compact form for tight spaces (inside rings).
String formatDurationCompact(int totalSeconds) {
  if (totalSeconds <= 0) return '0m';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}j ${minutes}m';
  return '${minutes}m';
}

String friendlyAppName(String packageName, {String? appLabel}) {
  final trimmed = appLabel?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  const known = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok',
    'com.whatsapp': 'WhatsApp',
    'com.google.android.apps.messaging': 'Pesan',
    'com.android.chrome': 'Chrome',
    'com.android.vending': 'Play Store',
    'com.google.android.gm': 'Gmail',
    'com.spotify.music': 'Spotify',
    'com.tursinalabs.pulangaman': 'PulangAman',
    'com.google.android.apps.maps': 'Maps',
    'com.google.android.dialer': 'Telepon',
    'com.android.settings': 'Pengaturan',
  };
  if (known.containsKey(packageName)) return known[packageName]!;
  final parts = packageName.split('.');
  if (parts.isEmpty) return packageName;
  final last = parts.last;
  if (last.length <= 2) return packageName;
  return last[0].toUpperCase() + last.substring(1);
}

Color appAccentForPackage(String packageName) {
  if (packageName.contains('youtube')) return const Color(0xFFE53935);
  if (packageName.contains('instagram')) return const Color(0xFFE1306C);
  if (packageName.contains('tiktok') || packageName.contains('trill')) {
    return const Color(0xFF1A1A1A);
  }
  if (packageName.contains('whatsapp')) return const Color(0xFF25D366);
  if (packageName.contains('chrome')) return const Color(0xFF4285F4);
  if (packageName.contains('gmail') || packageName.endsWith('.gm')) {
    return const Color(0xFFEA4335);
  }
  if (packageName.contains('pulangaman')) return const Color(0xFF087F6D);
  if (packageName.contains('spotify') || packageName.contains('music')) {
    return const Color(0xFF1DB954);
  }
  if (packageName.contains('maps')) return const Color(0xFF34A853);
  final hash = packageName.hashCode;
  const palette = [
    Color(0xFF087F6D),
    Color(0xFFFF746C),
    Color(0xFF74C9F5),
    Color(0xFFB7A7F8),
    Color(0xFFFFC857),
    Color(0xFF249B72),
  ];
  return palette[hash.abs() % palette.length];
}

IconData appIconForPackage(String packageName) {
  if (packageName.contains('youtube')) return Icons.play_circle_rounded;
  if (packageName.contains('instagram')) return Icons.camera_alt_rounded;
  if (packageName.contains('tiktok') || packageName.contains('trill')) {
    return Icons.music_note_rounded;
  }
  if (packageName.contains('whatsapp') || packageName.contains('messaging')) {
    return Icons.chat_bubble_rounded;
  }
  if (packageName.contains('chrome')) return Icons.language_rounded;
  if (packageName.contains('pulangaman')) return Icons.shield_rounded;
  if (packageName.contains('maps')) return Icons.map_rounded;
  if (packageName.contains('spotify') || packageName.contains('music')) {
    return Icons.headphones_rounded;
  }
  if (packageName.contains('gmail') || packageName.endsWith('.gm')) {
    return Icons.mail_rounded;
  }
  if (packageName.contains('vending')) return Icons.shop_rounded;
  return Icons.apps_rounded;
}
