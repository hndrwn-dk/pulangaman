import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../community/reports_screen.dart';
import '../rewards/rewards_screen.dart';
import 'account_settings_screen.dart';
import 'children_controller.dart';
import 'guardians_screen.dart';
import 'reminders_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _reminderCount = 0;
  String _reminderHint = 'Belum ada pengingat';
  int _points = 0;
  int _streak = 0;
  String _guardianHint = 'Belum ada wali';
  String _reportHint = 'Belum ada laporan';
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final children = ref.read(childrenControllerProvider).items;
    final api = ref.read(apiClientProvider);
    var reminders = 0;
    final reminderTitles = <String>[];
    var points = 0;
    var streak = 0;
    var guardians = 0;
    String? guardianChild;
    var reports = 0;
    String? reportNote;

    try {
      for (final child in children) {
        try {
          final rem = await api.get('/api/v1/reminders/${child.id}');
          final list = (rem['reminders'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .where((r) => r['enabled'] != false)
              .toList();
          reminders += list.length;
          for (final r in list.take(2)) {
            final t = (r['title'] as String?)?.trim();
            if (t != null && t.isNotEmpty) reminderTitles.add(t);
          }
        } catch (_) {}

        try {
          final reward = await api.get('/api/v1/rewards/${child.id}');
          final balance = reward['balance'] as Map<String, dynamic>? ?? {};
          points += (balance['points'] as num?)?.toInt() ?? 0;
          final s = (balance['current_streak'] as num?)?.toInt() ?? 0;
          if (s > streak) streak = s;
        } catch (_) {}

        try {
          final g = await api.get(
            '/api/v1/guardians',
            query: {'childId': child.id},
          );
          final list = (g['guardians'] as List<dynamic>? ?? []);
          if (list.isNotEmpty) {
            guardians += list.length;
            guardianChild ??= child.name;
          }
        } catch (_) {}
      }

      try {
        final rep = await api.get('/api/v1/reports');
        final list = (rep['reports'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        reports = list.length;
        if (list.isNotEmpty) {
          reportNote = list.first['note'] as String? ??
              list.first['category'] as String? ??
              'Laporan komunitas';
        }
      } catch (_) {}
    } catch (_) {
      // Keep defaults if aggregate fetch fails.
    }
    if (!mounted) return;
    setState(() {
      _reminderCount = reminders;
      _reminderHint = reminders == 0
          ? 'Belum ada pengingat'
          : '$reminders pengingat aktif'
              '${reminderTitles.isEmpty ? '' : ' · ${reminderTitles.take(2).join(' & ')}'}';
      _points = points;
      _streak = streak;
      _guardianHint = guardians == 0
          ? 'Belum ada wali'
          : '$guardians wali'
              '${guardianChild == null ? '' : ' · $guardianChild'}';
      _reportHint = reports == 0
          ? 'Belum ada laporan'
          : '$reports laporan'
              '${reportNote == null ? '' : ' · $reportNote'}';
      _loadingStats = false;
    });
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Text(
                'Fitur Lainnya',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Kelola pengaturan & tambahan',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: _loadingStats ? '—' : '$_reminderCount',
                      label: 'Pengingat Aktif',
                      color: AppColors.tealDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: _loadingStats ? '—' : '$_points',
                      label: 'Total Poin',
                      color: const Color(0xFFE8913A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('JADWAL & AKTIVITAS'),
              const SizedBox(height: 8),
              _MenuGroup(
                children: [
                  _MenuRow(
                    icon: Icons.alarm_rounded,
                    iconBg: const Color(0xFFE8F6F1),
                    iconColor: const Color(0xFFE85A7A),
                    title: 'Pengingat Jadwal',
                    subtitle: _reminderHint,
                    onTap: () => _open(const RemindersScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.card_giftcard_rounded,
                    iconBg: const Color(0xFFFFF0DC),
                    iconColor: const Color(0xFFE8913A),
                    title: 'Hadiah & Poin',
                    subtitle: _points == 0 && _streak == 0
                        ? '0 poin · Belum ada streak'
                        : '$_points poin'
                            '${_streak > 0 ? ' · Streak $_streak hari' : ''}',
                    onTap: () => _open(const RewardsScreen()),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel('KEAMANAN'),
              const SizedBox(height: 8),
              _MenuGroup(
                children: [
                  _MenuRow(
                    icon: Icons.shield_rounded,
                    iconBg: const Color(0xFFFFE8F0),
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Wali Terpercaya',
                    subtitle: _guardianHint,
                    onTap: () => _open(const GuardiansEntryScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFFFE8E6),
                    iconColor: const Color(0xFFE8913A),
                    title: 'Laporan Komunitas',
                    subtitle: _reportHint,
                    onTap: () => _open(const ReportsScreen()),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel('PENGATURAN'),
              const SizedBox(height: 8),
              _MenuGroup(
                children: [
                  _MenuRow(
                    icon: Icons.settings_rounded,
                    iconBg: const Color(0xFFE8ECF0),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Pengaturan Akun',
                    subtitle: 'Notifikasi, privasi, keluar',
                    onTap: () => _open(const AccountSettingsScreen()),
                    showDivider: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.inkSoft,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 70, endIndent: 14),
      ],
    );
  }
}
