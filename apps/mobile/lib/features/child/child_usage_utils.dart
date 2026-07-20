import 'package:flutter/material.dart';

class UsageAppEntry {
  UsageAppEntry({
    required this.packageName,
    required this.durationSeconds,
  });

  final String packageName;
  final int durationSeconds;

  factory UsageAppEntry.fromJson(Map<String, dynamic> json) {
    return UsageAppEntry(
      packageName: json['packageName'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
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
}

String formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 mnt';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '$hours jam $minutes mnt';
  return '$minutes mnt';
}

String friendlyAppName(String packageName) {
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

IconData appIconForPackage(String packageName) {
  if (packageName.contains('youtube')) return Icons.play_circle;
  if (packageName.contains('instagram')) return Icons.camera_alt;
  if (packageName.contains('tiktok') || packageName.contains('trill')) {
    return Icons.music_note;
  }
  if (packageName.contains('whatsapp') || packageName.contains('messaging')) {
    return Icons.chat_bubble;
  }
  if (packageName.contains('chrome')) return Icons.language;
  if (packageName.contains('pulangaman')) return Icons.home;
  if (packageName.contains('maps')) return Icons.map;
  if (packageName.contains('spotify') || packageName.contains('music')) {
    return Icons.headphones;
  }
  return Icons.apps;
}
