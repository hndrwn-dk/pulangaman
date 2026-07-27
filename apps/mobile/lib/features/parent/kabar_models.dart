import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

class ChildKabarMessage {
  ChildKabarMessage({
    required this.id,
    required this.childId,
    required this.childName,
    required this.text,
    this.preset,
    required this.sentAt,
  });

  final String id;
  final String childId;
  final String childName;
  final String text;
  final String? preset;
  final DateTime sentAt;

  factory ChildKabarMessage.fromJson(Map<String, dynamic> json) {
    return ChildKabarMessage(
      id: json['id'] as String? ??
          '${json['childId']}-${json['sentAt']}-${json['text']}',
      childId: json['childId'] as String? ?? '',
      childName: json['childName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      preset: json['preset'] as String?,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isUrgent =>
      preset == 'need_help' || preset == 'panic';
}

IconData kabarPresetIcon(String? preset) {
  switch (preset) {
    case 'at_school':
      return Icons.school_rounded;
    case 'at_home':
      return Icons.home_rounded;
    case 'need_help':
      return Icons.support_agent_rounded;
    case 'panic':
      return Icons.warning_amber_rounded;
    case 'panic_acked':
      return Icons.mark_chat_read_rounded;
    case 'panic_resolved':
      return Icons.check_circle_rounded;
    case 'trip_started':
      return Icons.directions_walk_rounded;
    case 'trip_arrived':
      return Icons.flag_rounded;
    default:
      return Icons.chat_bubble_rounded;
  }
}

Color kabarPresetColor(String? preset) {
  switch (preset) {
    case 'at_school':
      return AppColors.teal;
    case 'at_home':
      return AppColors.success;
    case 'need_help':
      return AppColors.coral;
    case 'panic':
      return AppColors.danger;
    case 'panic_acked':
      return AppColors.amber;
    case 'panic_resolved':
      return AppColors.success;
    case 'trip_started':
      return AppColors.sky;
    case 'trip_arrived':
      return AppColors.success;
    default:
      return AppColors.sky;
  }
}

String kabarRelativeTime(AppLocalizations l10n, DateTime at) {
  final age = DateTime.now().difference(at.toLocal());
  if (age.inSeconds < 60) return l10n.justNowRelative;
  if (age.inMinutes < 60) return l10n.minutesAgoRelative(age.inMinutes);
  if (age.inHours < 24) return l10n.hoursAgoRelative(age.inHours);
  if (age.inDays < 7) return l10n.daysAgoRelative(age.inDays);
  final local = at.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String formatLastSeen(AppLocalizations l10n, String? raw) {
  if (raw == null || raw.isEmpty) return l10n.noLocationYet;
  final at = DateTime.tryParse(raw);
  if (at == null) return l10n.lastSeenLabel(raw);
  return l10n.lastSeenLabel(kabarRelativeTime(l10n, at));
}

/// One newest message per child, urgent first, then by time.
List<ChildKabarMessage> latestKabarPerChild(List<ChildKabarMessage> all) {
  final newest = <String, ChildKabarMessage>{};
  for (final msg in all) {
    final existing = newest[msg.childId];
    if (existing == null || msg.sentAt.isAfter(existing.sentAt)) {
      newest[msg.childId] = msg;
    }
  }
  final list = newest.values.toList()
    ..sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.sentAt.compareTo(a.sentAt);
    });
  return list;
}

String dayLabel(AppLocalizations l10n, DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.todayLabel;
  if (diff == 1) return l10n.yesterdayLabel;
  return '${local.day}/${local.month}/${local.year}';
}
