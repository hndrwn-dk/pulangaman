import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
      childName: json['childName'] as String? ?? 'Anak',
      text: json['text'] as String? ?? '',
      preset: json['preset'] as String?,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isUrgent => preset == 'need_help';
}

IconData kabarPresetIcon(String? preset) {
  switch (preset) {
    case 'at_school':
      return Icons.school_rounded;
    case 'at_home':
      return Icons.home_rounded;
    case 'need_help':
      return Icons.support_agent_rounded;
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
    default:
      return AppColors.sky;
  }
}

String kabarRelativeTime(DateTime at) {
  final age = DateTime.now().difference(at.toLocal());
  if (age.inSeconds < 60) return 'baru saja';
  if (age.inMinutes < 60) return '${age.inMinutes} mnt lalu';
  if (age.inHours < 24) return '${age.inHours} jam lalu';
  if (age.inDays < 7) return '${age.inDays} hari lalu';
  final local = at.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String formatLastSeen(String? raw) {
  if (raw == null || raw.isEmpty) return 'Belum ada lokasi';
  final at = DateTime.tryParse(raw);
  if (at == null) return 'Terakhir terlihat: $raw';
  return 'Terakhir terlihat: ${kabarRelativeTime(at)}';
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

String dayLabel(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return '${local.day}/${local.month}/${local.year}';
}
