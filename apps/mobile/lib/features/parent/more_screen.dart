import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../community/reports_screen.dart';
import '../rewards/rewards_screen.dart';
import 'account_settings_screen.dart';
import 'children_controller.dart';
import 'emergency_meeting_screen.dart';
import 'guardians_screen.dart';
import 'home_by_screen.dart';
import 'reminders_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _reminderCount = 0;
  String? _reminderHint;
  String? _homeByHint;
  int _points = 0;
  int _streak = 0;
  String? _guardianHint;
  String? _reportHint;
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
    final homeByParts = <String>[];
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
          final hb = await api.get('/api/v1/home-by/${child.id}');
          final s = hb['settings'] as Map<String, dynamic>? ?? {};
          final mode = s['mode'] as String? ?? 'off';
          if (mode == 'maghrib') {
            homeByParts.add('${child.name}: Maghrib');
          } else if (mode == 'custom') {
            final h = (s['customHour'] as num?)?.toInt() ?? 18;
            final m = (s['customMinute'] as num?)?.toInt() ?? 0;
            homeByParts.add(
              '${child.name}: '
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
            );
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _reminderCount = reminders;
      _reminderHint = reminders == 0
          ? null
          : '${l10n.reminderActiveCount(reminders)}'
              '${reminderTitles.isEmpty ? '' : ' · ${reminderTitles.take(2).join(' & ')}'}';
      _homeByHint = homeByParts.isEmpty ? null : homeByParts.take(2).join(' · ');
      _points = points;
      _streak = streak;
      _guardianHint = guardians == 0
          ? null
          : '${l10n.guardiansCountLabel(guardians)}'
              '${guardianChild == null ? '' : ' · $guardianChild'}';
      _reportHint = reports == 0
          ? null
          : '${l10n.reportsCountLabel(reports)}'
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
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                l10n.moreScreenTitle,
                style: refresh
                    ? GoogleFonts.fraunces(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.moreScreenSubtitle,
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: _loadingStats ? '—' : '$_reminderCount',
                      label: l10n.activeRemindersStatLabel,
                      color: AppColors.tealDeep,
                      refresh: refresh,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: _loadingStats ? '—' : '$_points',
                      label: l10n.totalPointsStatLabel,
                      color: const Color(0xFFE8913A),
                      refresh: refresh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel(l10n.sectionScheduleActivity, refresh: refresh),
              const SizedBox(height: 8),
              _MenuGroup(
                refresh: refresh,
                children: [
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.alarm_rounded,
                    iconBg: const Color(0xFFE8F6F1),
                    iconColor: const Color(0xFFE85A7A),
                    vrIconBg: const Color(0xFFF8E8EC),
                    vrIconColor: const Color(0xFFC45B6E),
                    title: l10n.remindersTitle,
                    subtitle: _reminderHint ?? l10n.noRemindersYet,
                    onTap: () => _open(const RemindersScreen()),
                  ),
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.nights_stay_rounded,
                    iconBg: const Color(0xFFEAE6FA),
                    iconColor: const Color(0xFF7C3AED),
                    vrIconBg: const Color(0xFFEEE8F8),
                    vrIconColor: const Color(0xFF6B5B95),
                    title: l10n.homeByTitle,
                    subtitle: _homeByHint ?? l10n.homeBySummaryOff,
                    onTap: () => _open(const HomeByScreen()),
                  ),
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.card_giftcard_rounded,
                    iconBg: const Color(0xFFFFF0DC),
                    iconColor: const Color(0xFFE8913A),
                    vrIconBg: const Color(0xFFF8EFE0),
                    vrIconColor: const Color(0xFFC47E3A),
                    title: l10n.rewardsTitle,
                    subtitle: _points == 0 && _streak == 0
                        ? l10n.noPointsNoStreak
                        : _streak > 0
                            ? l10n.pointsStreakLabel(_points, _streak)
                            : l10n.pointsCountLabel(_points),
                    onTap: () => _open(const RewardsScreen()),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(l10n.sectionSafety, refresh: refresh),
              const SizedBox(height: 8),
              _MenuGroup(
                refresh: refresh,
                children: [
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.shield_rounded,
                    iconBg: const Color(0xFFFFE8F0),
                    iconColor: const Color(0xFF3B82F6),
                    vrIconBg: const Color(0xFFF8E8EC),
                    vrIconColor: const Color(0xFF5B7DB8),
                    title: l10n.guardiansTitle,
                    subtitle: _guardianHint ?? l10n.noGuardiansYet,
                    onTap: () => _open(const GuardiansEntryScreen()),
                  ),
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.groups_rounded,
                    iconBg: const Color(0xFFFFE8E6),
                    iconColor: const Color(0xFFDC2626),
                    vrIconBg: const Color(0xFFF8E8E6),
                    vrIconColor: VisualRefreshColors.danger,
                    title: l10n.empTitle,
                    subtitle: l10n.emergencyMeetingMenuSubtitle,
                    onTap: () => _open(const EmergencyMeetingScreen()),
                  ),
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFFFE8E6),
                    iconColor: const Color(0xFFE8913A),
                    vrIconBg: const Color(0xFFF8EFE0),
                    vrIconColor: const Color(0xFFC47E3A),
                    title: l10n.communityReportsTitle,
                    subtitle: _reportHint ?? l10n.noReportsYet,
                    onTap: () => _open(const ReportsScreen()),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(l10n.sectionSettings, refresh: refresh),
              const SizedBox(height: 8),
              _MenuGroup(
                refresh: refresh,
                children: [
                  _MenuRow(
                    refresh: refresh,
                    icon: Icons.settings_rounded,
                    iconBg: const Color(0xFFE8ECF0),
                    iconColor: const Color(0xFF7C3AED),
                    vrIconBg: VisualRefreshColors.tagMuted,
                    vrIconColor: VisualRefreshColors.textSecondary,
                    title: l10n.settingsAccountTitle,
                    subtitle: l10n.accountSettingsMenuSubtitle,
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
  const _SectionLabel(this.text, {this.refresh = false});

  final String text;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: refresh ? 1.1 : 0.8,
        color: refresh ? VisualRefreshColors.textSecondary : AppColors.inkSoft,
        fontFamily:
            refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.refresh = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    if (refresh) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: VisualRefreshColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.vrCard),
          border: Border.all(
            color: VisualRefreshColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                color: VisualRefreshColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                height: 1.05,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: VisualRefreshColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
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
  const _MenuGroup({required this.children, this.refresh = false});

  final List<Widget> children;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 20,
        ),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
        boxShadow: refresh
            ? null
            : [
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
    this.vrIconBg,
    this.vrIconColor,
    this.showDivider = true,
    this.refresh = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color? vrIconBg;
  final Color? vrIconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final tileBg = refresh ? (vrIconBg ?? iconBg) : iconBg;
    final tileFg = refresh ? (vrIconColor ?? iconColor) : iconColor;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tileBg,
                      borderRadius: BorderRadius.circular(
                        refresh ? AppRadius.vrChip : 12,
                      ),
                    ),
                    child: Icon(icon, color: tileFg, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: refresh
                              ? GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: VisualRefreshColors.textPrimary,
                                )
                              : const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: refresh
                        ? VisualRefreshColors.textTertiary
                        : AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 14,
            color: refresh ? VisualRefreshColors.border : null,
          ),
      ],
    );
  }
}
