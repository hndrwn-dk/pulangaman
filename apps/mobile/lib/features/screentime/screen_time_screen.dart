import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../child/child_usage_utils.dart';
import '../parent/children_controller.dart';
import '../parent/reminders_screen.dart';
import '../parent/vr_sheet_chrome.dart';

class _ScreenTimeInsight {
  _ScreenTimeInsight({
    required this.trendText,
    this.patternText,
    this.patternDayText,
    required this.streakText,
    this.suggestedReminderTime,
    this.suggestedReminderLabel,
    required this.daysUnderLimit,
    required this.totalDays,
  });

  final String trendText;
  final String? patternText;
  final String? patternDayText;
  final String streakText;
  final String? suggestedReminderTime;
  final String? suggestedReminderLabel;
  final int daysUnderLimit;
  final int totalDays;

  bool get hasSuggestedReminder =>
      suggestedReminderTime != null &&
      suggestedReminderTime!.isNotEmpty &&
      suggestedReminderLabel != null &&
      suggestedReminderLabel!.isNotEmpty;

  factory _ScreenTimeInsight.fromJson(Map<String, dynamic> json) {
    String? optionalText(dynamic value) {
      final s = value as String?;
      if (s == null || s.trim().isEmpty) return null;
      return s.trim();
    }

    return _ScreenTimeInsight(
      trendText: json['trendText'] as String? ?? '',
      patternText: optionalText(json['patternText']),
      patternDayText: optionalText(json['patternDayText']),
      streakText: json['streakText'] as String? ?? '',
      suggestedReminderTime: optionalText(json['suggestedReminderTime']),
      suggestedReminderLabel: optionalText(json['suggestedReminderLabel']),
      daysUnderLimit: (json['daysUnderLimit'] as num?)?.toInt() ?? 0,
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 7,
    );
  }
}

/// Stable per-child presence-dot colors (Screen Time chips).
Color _childPresenceDotColor(String childId) {
  const palette = <Color>[
    Color(0xFF4ADE80),
    Color(0xFF93C5FD),
    Color(0xFFF0ABFC),
    Color(0xFFFCD34D),
    Color(0xFF67E8F9),
    Color(0xFFFDA4AF),
  ];
  return palette[childId.hashCode.abs() % palette.length];
}

BoxDecoration _hubCardDecoration(BuildContext context) {
  final refresh = visualRefreshOf(context);
  if (refresh) {
    return BoxDecoration(
      color: VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      border: Border.all(
        color: VisualRefreshColors.border,
        width: 0.5,
      ),
    );
  }
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

TextStyle _hubSectionTitleStyle(BuildContext context) {
  final refresh = visualRefreshOf(context);
  if (refresh) {
    return GoogleFonts.fraunces(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: VisualRefreshColors.textPrimary,
    );
  }
  return const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );
}

class _UsageAppRow {
  _UsageAppRow({
    required this.packageName,
    required this.label,
    required this.durationSeconds,
    this.priorDurationSeconds,
  });

  final String packageName;
  final String label;
  final int durationSeconds;
  final int? priorDurationSeconds;
}

class _DayUsage {
  _DayUsage({required this.day, required this.totalSeconds});

  final DateTime day;
  final int totalSeconds;
}

class _WeekdayPattern {
  _WeekdayPattern({
    required this.isWeekend,
    required this.dayNames,
    required this.weekCount,
  });

  final bool isWeekend;
  final String dayNames;
  final int weekCount;
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Heatmap cell color from usage as % of that day's limit.
Color _heatmapColorForPct(double pctOfLimit) {
  if (pctOfLimit <= 0) return VisualRefreshColors.tagMuted;
  if (pctOfLimit <= 0.5) return const Color(0xFFE8D9BB);
  if (pctOfLimit <= 0.9) return VisualRefreshColors.praiseBtn;
  if (pctOfLimit <= 1.1) return const Color(0xFFC9634C);
  return VisualRefreshColors.danger;
}

String _weekdayFullName(AppLocalizations l10n, int weekday) {
  return switch (weekday) {
    DateTime.monday => l10n.weekdayMonFull,
    DateTime.tuesday => l10n.weekdayTueFull,
    DateTime.wednesday => l10n.weekdayWedFull,
    DateTime.thursday => l10n.weekdayThuFull,
    DateTime.friday => l10n.weekdayFriFull,
    DateTime.saturday => l10n.weekdaySatFull,
    DateTime.sunday => l10n.weekdaySunFull,
    _ => '',
  };
}

String _joinDayNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} & ${names[1]}';
  return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
}

/// Deterministic weekday pattern (§4): weekday >25% above mean in ≥3 of last weeks.
_WeekdayPattern? _detectWeekdayPattern(
  List<_DayUsage> days,
  AppLocalizations l10n,
) {
  if (days.isEmpty) return null;

  final byWeek = <String, Map<int, int>>{};
  var sum = 0;
  for (final d in days) {
    sum += d.totalSeconds;
    final monday = _dateOnly(d.day).subtract(Duration(days: d.day.weekday - 1));
    final wk = _dayKey(monday);
    final map = byWeek.putIfAbsent(wk, () => <int, int>{});
    map[d.day.weekday] = (map[d.day.weekday] ?? 0) + d.totalSeconds;
  }

  final weeks = byWeek.keys.toList()..sort();
  final weekCount = weeks.length;
  if (weekCount < 3) return null;

  final dailyAvg = sum / days.length;
  final threshold = dailyAvg * 1.25;

  final weekdayHighCounts = <int, int>{
    for (var dow = DateTime.monday; dow <= DateTime.friday; dow++) dow: 0,
  };
  var weekendHighWeeks = 0;

  for (final wk in weeks) {
    final map = byWeek[wk]!;
    for (var dow = DateTime.monday; dow <= DateTime.friday; dow++) {
      final secs = map[dow] ?? 0;
      if (secs > threshold) {
        weekdayHighCounts[dow] = (weekdayHighCounts[dow] ?? 0) + 1;
      }
    }
    final sat = map[DateTime.saturday] ?? 0;
    final sun = map[DateTime.sunday] ?? 0;
    if ((sat + sun) / 2 > threshold) weekendHighWeeks += 1;
  }

  final strong = weekdayHighCounts.entries
      .where((e) => e.value >= 3)
      .toList()
    ..sort((a, b) => b.value != a.value
        ? b.value.compareTo(a.value)
        : a.key.compareTo(b.key));
  final top = strong.take(2).map((e) => e.key).toList();

  if (top.isNotEmpty) {
    return _WeekdayPattern(
      isWeekend: false,
      dayNames: _joinDayNames(
        top.map((d) => _weekdayFullName(l10n, d)).toList(),
      ),
      weekCount: weekCount,
    );
  }
  if (weekendHighWeeks >= 3) {
    return _WeekdayPattern(
      isWeekend: true,
      dayNames: '',
      weekCount: weekCount,
    );
  }
  return null;
}

const _limitPresetMinutes = <int>[30, 60, 90, 120, 180, 300];

/// Hub Waktu Layar (tab parent) — redesign premium sesuai mockup.
/// Push with [lockedChild] + [showBack] from child detail so back returns there.
class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({
    super.key,
    this.lockedChild,
    this.showBack = false,
  });

  final ChildSummary? lockedChild;
  final bool showBack;

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen> {
  String? _selectedChildId;
  bool _loading = true;
  bool _enabled = true;
  bool _schoolDaysOn = true;
  bool _weekendOn = true;
  int _schoolLimitMinutes = 180;
  int _weekendLimitMinutes = 300;
  List<_UsageAppRow> _apps = [];
  List<_DayUsage> _history = [];
  UsagePeriod _period = UsagePeriod.week;
  bool _showAllApps = false;
  _ScreenTimeInsight? _insight;
  bool _insightLoading = false;

  bool get _childLocked => widget.lockedChild != null;

  @override
  void initState() {
    super.initState();
    final locked = widget.lockedChild;
    if (locked != null) {
      _selectedChildId = locked.id;
    }
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _ensureSelectionAndLoad();
    });
  }

  Future<void> _ensureSelectionAndLoad() async {
    final items = ref.read(childrenControllerProvider).items;
    if (items.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final locked = widget.lockedChild;
    final id = locked?.id ?? _selectedChildId ?? items.first.id;
    if (_selectedChildId != id) {
      setState(() => _selectedChildId = id);
    }
    await _loadFor(id);
  }

  void _selectChild(String id) {
    if (_childLocked || _selectedChildId == id) return;
    setState(() {
      _selectedChildId = id;
      _showAllApps = false;
      _period = UsagePeriod.week;
    });
    unawaited(_loadFor(id));
  }

  void _setPeriod(UsagePeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _showAllApps = false;
    });
    final id = _selectedChildId;
    if (id != null) unawaited(_loadAppsForPeriod(id));
  }

  void _applyPolicyToState(Map<String, dynamic>? current) {
    if (current == null) {
      _enabled = true;
      _schoolDaysOn = true;
      _weekendOn = true;
      _schoolLimitMinutes = 180;
      _weekendLimitMinutes = 300;
      return;
    }
    _enabled = current['enabled'] == true;
    final limit = (current['daily_limit_minutes'] as num?)?.toInt() ?? 180;
    final schedules = (current['schedules'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    var schoolOn = false;
    var weekendOn = false;
    int? schoolLimit;
    int? weekendLimit;
    for (final s in schedules) {
      final days = (s['days'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final lim = (s['limitMinutes'] as num?)?.toInt() ??
          (s['limit_minutes'] as num?)?.toInt();
      final isSchool = days.any((d) => d >= 1 && d <= 5);
      final isWeekend = days.any((d) => d == 6 || d == 7);
      if (isSchool) {
        schoolOn = true;
        if (lim != null) schoolLimit = lim;
      }
      if (isWeekend) {
        weekendOn = true;
        if (lim != null) weekendLimit = lim;
      }
    }

    if (schedules.isEmpty) {
      schoolOn = true;
      weekendOn = true;
      schoolLimit = limit <= 180 ? limit : 180;
      weekendLimit = limit > 180 ? limit : 300;
    }

    _schoolDaysOn = schoolOn;
    _weekendOn = weekendOn;
    _schoolLimitMinutes = schoolLimit ?? (limit <= 180 ? limit : 180);
    _weekendLimitMinutes = weekendLimit ?? (limit > 180 ? limit : 300);
  }

  Future<void> _loadFor(String childId) async {
    setState(() {
      _loading = true;
      _insightLoading = true;
      _insight = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final policy = await api.get('/api/v1/policies/$childId');
      final current = policy['policy'] as Map<String, dynamic>?;

      List<_DayUsage> history = [];
      try {
        final weekly = await api.get(
          '/api/v1/telemetry/$childId/weekly',
          query: {'days': '35'},
        );
        history = _parseDayUsage(weekly);
      } catch (_) {
        history = [];
      }

      final apps = await _fetchPeriodApps(childId, _period);

      if (!mounted) return;
      setState(() {
        _applyPolicyToState(current);
        _apps = apps;
        _history = history;
        _loading = false;
      });

      unawaited(_loadInsight(childId, history: history, apps: apps));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apps = [];
        _history = [];
        _loading = false;
        _insightLoading = false;
        _insight = null;
      });
    }
  }

  Future<void> _loadAppsForPeriod(String childId) async {
    try {
      final apps = await _fetchPeriodApps(childId, _period);
      if (!mounted) return;
      setState(() => _apps = apps);
    } catch (_) {
      if (!mounted) return;
      setState(() => _apps = []);
    }
  }

  List<_DayUsage> _parseDayUsage(Map<String, dynamic> weekly) {
    return (weekly['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((d) {
          final dayRaw = d['day'] as String? ?? '';
          final parsed = DateTime.tryParse(dayRaw);
          return _DayUsage(
            day: parsed ?? DateTime.now(),
            totalSeconds: (d['totalSeconds'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
  }

  Future<List<_UsageAppRow>> _fetchPeriodApps(
    String childId,
    UsagePeriod period,
  ) async {
    final api = ref.read(apiClientProvider);
    try {
      final summary = await api.get(
        '/api/v1/telemetry/$childId/summary',
        query: {'period': period.apiValue},
      );
      final priorByPkg = <String, int>{};
      for (final item in (summary['priorApps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()) {
        final pkg = item['package_name'] as String? ?? '';
        if (pkg.isEmpty) continue;
        priorByPkg[pkg] = (item['duration_seconds'] as num?)?.toInt() ?? 0;
      }
      return (summary['apps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final pkg = item['package_name'] as String? ?? '';
            final label = item['app_label'] as String?;
            return _UsageAppRow(
              packageName: pkg,
              label: friendlyAppName(pkg, appLabel: label),
              durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
              priorDurationSeconds:
                  period == UsagePeriod.today ? null : (priorByPkg[pkg] ?? 0),
            );
          })
          .where((a) => a.packageName.isNotEmpty)
          .toList();
    } catch (_) {
      // Older API without period support — fall back to today-only summary.
      if (period != UsagePeriod.today) return [];
      final summary = await api.get('/api/v1/telemetry/$childId/summary');
      return (summary['apps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final pkg = item['package_name'] as String? ?? '';
            final label = item['app_label'] as String?;
            return _UsageAppRow(
              packageName: pkg,
              label: friendlyAppName(pkg, appLabel: label),
              durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
            );
          })
          .where((a) => a.packageName.isNotEmpty)
          .toList();
    }
  }

  Future<void> _loadInsight(
    String childId, {
    required List<_DayUsage> history,
    required List<_UsageAppRow> apps,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final lang = Localizations.localeOf(context).languageCode;
      final raw = await api.get(
        '/api/v1/screentime/$childId/insights',
        query: {'lang': lang},
      );
      if (!mounted) return;
      setState(() {
        _insight = _ScreenTimeInsight.fromJson(raw);
        _insightLoading = false;
      });
    } catch (_) {
      // API may not be deployed yet — local deterministic fallback so the card
      // still appears from weekly totals already on screen.
      if (!mounted) return;
      setState(() {
        _insight = _localFallbackInsight(history: history, apps: apps);
        _insightLoading = false;
      });
    }
  }

  _ScreenTimeInsight _localFallbackInsight({
    required List<_DayUsage> history,
    required List<_UsageAppRow> apps,
  }) {
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final limitMin = _activeLimitMinutes;
    final limitSec = limitMin * 60;
    final days = history.isEmpty
        ? <_DayUsage>[
            _DayUsage(
              day: DateTime.now(),
              totalSeconds:
                  apps.fold<int>(0, (s, a) => s + a.durationSeconds),
            ),
          ]
        : history;
    var under = 0;
    var sum = 0;
    for (final d in days) {
      sum += d.totalSeconds;
      if (limitSec <= 0 || d.totalSeconds <= limitSec) under += 1;
    }
    final totalDays = days.isEmpty ? 1 : days.length;
    final avgMin = (sum / totalDays / 60).round();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedHours = ((avgMin * daysInMonth) / 60).round();
    final period = isEn ? 'this month' : 'bulan ini';
    final projected = isEn ? '$projectedHours hours' : '$projectedHours jam';
    final streak = l10n.insightDaysUnderLimit(under, totalDays);
    final pattern = _detectWeekdayPattern(history, l10n);
    String? patternDayText;
    if (pattern != null) {
      patternDayText = pattern.isWeekend
          ? l10n.weekendPatternInsight(pattern.weekCount)
          : l10n.weekdayPatternInsight(pattern.dayNames, pattern.weekCount);
    }
    return _ScreenTimeInsight(
      trendText: isEn
          ? 'Usage is holding steady, projected $period: $projected.'
          : 'Pemakaian relatif stabil, proyeksi $period: $projected.',
      patternText: null,
      patternDayText: patternDayText,
      streakText: streak,
      suggestedReminderTime: null,
      suggestedReminderLabel: null,
      daysUnderLimit: under,
      totalDays: totalDays,
    );
  }

  void _openSuggestedReminder(ChildSummary child, _ScreenTimeInsight insight) {
    final time = insight.suggestedReminderTime;
    final label = insight.suggestedReminderLabel;
    if (time == null || label == null) return;
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 20;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 45;
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemindersScreen(
          initialChildId: child.id,
          lockChild: true,
          openCustomOnLoad: true,
          prefillTitle: label,
          prefillBody: l10n.insightReminderBodyDefault,
          prefillHour: hour,
          prefillMinute: minute,
        ),
      ),
    );
  }

  void _openSettings(ChildSummary child) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ScreenTimeRulesScreen(child: child),
      ),
    )
        .then((_) {
      final id = _selectedChildId;
      if (id != null) unawaited(_loadFor(id));
    });
  }

  int get _usedSeconds {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    for (final d in _history) {
      if (_dayKey(d.day) == todayKey) return d.totalSeconds;
    }
    if (_period == UsagePeriod.today) {
      return _apps.fold<int>(0, (sum, a) => sum + a.durationSeconds);
    }
    return 0;
  }

  int get _periodTotalSeconds =>
      _apps.fold<int>(0, (sum, a) => sum + a.durationSeconds);

  String _periodPhrase(AppLocalizations l10n) {
    return switch (_period) {
      UsagePeriod.today => l10n.periodLabelToday,
      UsagePeriod.week => l10n.periodLabelThisWeek,
      UsagePeriod.month => l10n.periodLabelThisMonth,
    };
  }

  int get _activeLimitMinutes {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    if (isWeekend) {
      return _weekendOn ? _weekendLimitMinutes : _schoolLimitMinutes;
    }
    return _schoolDaysOn ? _schoolLimitMinutes : _weekendLimitMinutes;
  }

  String _scheduleSummary(AppLocalizations l10n) {
    if (!_enabled) return l10n.limitOffLabel;
    final parts = <String>[];
    if (_schoolDaysOn) {
      parts.add(
        '${l10n.schoolDaysRangeLabel} ${_fmtLimitHours(l10n, _schoolLimitMinutes)}',
      );
    }
    if (_weekendOn) {
      parts.add(
        '${l10n.weekendDaysRangeLabel} ${_fmtLimitHours(l10n, _weekendLimitMinutes)}',
      );
    }
    if (parts.isEmpty) return l10n.noActiveScheduleLabel;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final children = ref.watch(childrenControllerProvider);
    final items = children.items;

    if (items.isNotEmpty) {
      final ids = items.map((c) => c.id).toSet();
      if (_selectedChildId == null || !ids.contains(_selectedChildId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_ensureSelectionAndLoad());
        });
      }
    }

    final selected = widget.lockedChild ??
        (items.isEmpty
            ? null
            : items.firstWhere(
                (c) => c.id == _selectedChildId,
                orElse: () => items.first,
              ));

    final limitSec = _activeLimitMinutes * 60;
    final used = _usedSeconds;
    final progress = limitSec <= 0 ? 0.0 : (used / limitSec).clamp(0.0, 1.0);
    final remaining = (limitSec - used).clamp(0, limitSec);
    final periodTotal = _periodTotalSeconds;
    final visibleApps = _showAllApps ? _apps : _apps.take(4).toList();
    final cardDecoration = _hubCardDecoration(context);
    final sectionTitle = _hubSectionTitleStyle(context);
    final chartTitle = switch (_period) {
      UsagePeriod.month => l10n.thisMonthTitle,
      UsagePeriod.week => l10n.thisWeekTitle,
      UsagePeriod.today => l10n.thisWeekTitle,
    };
    final heatmapPattern = _period == UsagePeriod.month
        ? (_insight?.patternDayText ??
            () {
              final p = _detectWeekdayPattern(_history, l10n);
              if (p == null) return null;
              return p.isWeekend
                  ? l10n.weekendPatternInsight(p.weekCount)
                  : l10n.weekdayPatternInsight(p.dayNames, p.weekCount);
            }())
        : null;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          onRefresh: () async {
            final id = _selectedChildId;
            if (id != null) await _loadFor(id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (widget.showBack)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PaScreenHeader(
                    title: l10n.featureScreenTime,
                    subtitle: selected == null
                        ? l10n.screenTimeMonitorSubtitle
                        : selected.name,
                    padding: EdgeInsets.zero,
                    titleStyle: refresh
                        ? GoogleFonts.fraunces(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: VisualRefreshColors.textPrimary,
                          )
                        : null,
                    subtitleStyle: refresh
                        ? GoogleFonts.plusJakartaSans(
                            color: VisualRefreshColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          )
                        : null,
                    trailing: _SettingsCircleButton(
                      enabled: selected != null,
                      onTap: selected == null
                          ? null
                          : () => _openSettings(selected),
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.featureScreenTime,
                            style: refresh
                                ? GoogleFonts.fraunces(
                                    fontSize: 24,
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
                            l10n.screenTimeMonitorSubtitle,
                            style: refresh
                                ? GoogleFonts.plusJakartaSans(
                                    color: VisualRefreshColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  )
                                : const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    _SettingsCircleButton(
                      enabled: selected != null,
                      onTap: selected == null
                          ? null
                          : () => _openSettings(selected),
                    ),
                  ],
                ),
              if (items.isEmpty) ...[
                const SizedBox(height: 40),
                PaEmptyState(
                  icon: Icons.child_care,
                  title: l10n.noChildrenTitle,
                  message: l10n.addChildFirstMessage,
                ),
              ] else ...[
                if (!_childLocked) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = items[i];
                        final on = c.id == selected?.id;
                        return _ChildChip(
                          name: c.name,
                          selected: on,
                          dotColor: _childPresenceDotColor(c.id),
                          onTap: () => _selectChild(c.id),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _TodayHeroCard(
                    usedSeconds: used,
                    limitMinutes: _activeLimitMinutes,
                    progress: progress,
                    remainingSeconds: remaining,
                    enabled: _enabled,
                  ),
                  if (_insightLoading && _insight == null) ...[
                    const SizedBox(height: 16),
                    const _InsightSkeleton(),
                  ] else if (_insight != null) ...[
                    const SizedBox(height: 16),
                    _InsightWeekCard(
                      insight: _insight!,
                      onAddReminder: selected != null &&
                              _insight!.hasSuggestedReminder
                          ? () => _openSuggestedReminder(selected, _insight!)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _DaysUnderLimitRow(
                      daysUnderLimit: _insight!.daysUnderLimit,
                      totalDays: _insight!.totalDays,
                    ),
                  ],
                  const SizedBox(height: 22),
                  _PeriodToggle(
                    period: _period,
                    onChanged: _setPeriod,
                  ),
                  const SizedBox(height: 18),
                  if (_period != UsagePeriod.today) ...[
                    Text(
                      chartTitle,
                      style: sectionTitle,
                    ),
                    const SizedBox(height: 10),
                    if (_period == UsagePeriod.week)
                      _WeekChart(
                        days: _history,
                        schoolLimitMinutes: _schoolDaysOn
                            ? _schoolLimitMinutes
                            : _weekendLimitMinutes,
                        weekendLimitMinutes: _weekendOn
                            ? _weekendLimitMinutes
                            : _schoolLimitMinutes,
                        todaySeconds: used,
                      )
                    else
                      _MonthHeatmap(
                        days: _history,
                        schoolLimitMinutes: _schoolDaysOn
                            ? _schoolLimitMinutes
                            : _weekendLimitMinutes,
                        weekendLimitMinutes: _weekendOn
                            ? _weekendLimitMinutes
                            : _schoolLimitMinutes,
                        patternText: heatmapPattern,
                      ),
                    const SizedBox(height: 22),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.appUsageTitle,
                          style: sectionTitle,
                        ),
                      ),
                      if (_apps.length > 4)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showAllApps = !_showAllApps),
                          style: TextButton.styleFrom(
                            foregroundColor: refresh
                                ? VisualRefreshColors.accent
                                : AppColors.teal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _showAllApps ? l10n.closeAction : l10n.viewAllAction,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_apps.isNotEmpty) ...[
                    _TopAppCallout(
                      app: _apps.first,
                      periodLabel: _periodPhrase(l10n),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_apps.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: cardDecoration,
                      child: Text(
                        _period == UsagePeriod.today
                            ? l10n.noAppDataToday
                            : l10n.noAppDataForPeriod,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: refresh
                              ? VisualRefreshColors.textSecondary
                              : AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: cardDecoration,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Column(
                        children: [
                          for (var i = 0; i < visibleApps.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: refresh
                                    ? VisualRefreshColors.border
                                    : const Color(0xFFE8ECF0),
                              ),
                            _AppUsageRow(
                              app: visibleApps[i],
                              totalSeconds: periodTotal <= 0 ? 1 : periodTotal,
                              showTrend: _period != UsagePeriod.today,
                              periodLabel: _periodPhrase(l10n),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.limitScheduleTitle,
                    style: sectionTitle,
                  ),
                  const SizedBox(height: 10),
                  if (selected != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openSettings(selected),
                        borderRadius: BorderRadius.circular(
                          refresh ? AppRadius.vrCard : 20,
                        ),
                        child: Ink(
                          decoration: cardDecoration,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: refresh
                                        ? VisualRefreshColors.accentTint
                                        : const Color(0xFFE8F6F1),
                                    borderRadius: BorderRadius.circular(
                                      refresh ? AppRadius.vrChip : 12,
                                    ),
                                  ),
                                  child: Icon(
                                    refresh
                                        ? Icons.calendar_month_rounded
                                        : Icons.tune_rounded,
                                    color: refresh
                                        ? VisualRefreshColors.accent
                                        : AppColors.tealDeep,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _scheduleSummary(l10n),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          color: refresh
                                              ? VisualRefreshColors.textPrimary
                                              : null,
                                          fontFamily: refresh
                                              ? GoogleFonts.plusJakartaSans()
                                                  .fontFamily
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.editInRulesHint,
                                        style: TextStyle(
                                          color: refresh
                                              ? VisualRefreshColors.accent
                                              : AppColors.teal,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          fontFamily: refresh
                                              ? GoogleFonts.plusJakartaSans()
                                                  .fontFamily
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : AppColors.inkSoft,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtLimitHours(AppLocalizations l10n, int minutes) {
  if (minutes % 60 == 0) return l10n.durationHoursLabel(minutes ~/ 60);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l10n.durationMinutesLabel(m);
  return l10n.durationHoursMinutesLabel(h, m);
}

class _SettingsCircleButton extends StatelessWidget {
  const _SettingsCircleButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final l10n = AppLocalizations.of(context);
    if (refresh) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: PaRoundIconButton(
          icon: Icons.settings_rounded,
          semanticLabel: l10n.screenTimeSettingsTooltip,
          onTap: onTap ?? () {},
          elevation: 0,
        ),
      );
    }
    return Semantics(
      button: true,
      label: l10n.screenTimeSettingsTooltip,
      enabled: enabled && onTap != null,
      child: Material(
        color: const Color(0xFFE8ECF0),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.settings_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.dotColor,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final selectedFill =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;
    final selectedFg =
        refresh ? VisualRefreshColors.background : Colors.white;
    final unselectedFg =
        refresh ? VisualRefreshColors.anchor : AppColors.ink;
    return Material(
      color: selected
          ? selectedFill
          : (refresh ? VisualRefreshColors.surface : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: refresh
                        ? VisualRefreshColors.border
                        : const Color(0xFFE2E6EA),
                    width: refresh ? 0.5 : 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: refresh
                      ? dotColor
                      : (selected
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF93C5FD)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? selectedFg : unselectedFg,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        color: VisualRefreshColors.routeTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(color: VisualRefreshColors.rewardBorder, width: 0.5),
      ),
    );
  }
}

class _InsightWeekCard extends StatelessWidget {
  const _InsightWeekCard({
    required this.insight,
    required this.onAddReminder,
  });

  final _ScreenTimeInsight insight;
  final VoidCallback? onAddReminder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final pattern = insight.patternText;
    final patternDay = insight.patternDayText;
    final streak = insight.streakText.trim();
    final showReminder = onAddReminder != null && insight.hasSuggestedReminder;
    final reminderTime = insight.suggestedReminderTime ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.routeTint
            : const Color(0xFFF3E4C6),
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 20,
        ),
        border: refresh
            ? Border.all(color: VisualRefreshColors.rewardBorder, width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.insightThisWeekTitle.toUpperCase(),
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: VisualRefreshColors.routeText,
                  )
                : const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFB3722E),
                  ),
          ),
          const SizedBox(height: 12),
          _InsightBulletRow(
            icon: Icons.trending_up_rounded,
            text: insight.trendText,
          ),
          if (pattern != null) ...[
            const SizedBox(height: 10),
            _InsightBulletRow(
              icon: Icons.schedule_rounded,
              text: pattern,
            ),
          ],
          if (patternDay != null) ...[
            const SizedBox(height: 10),
            _InsightBulletRow(
              icon: Icons.calendar_view_week_rounded,
              text: patternDay,
            ),
          ],
          if (streak.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InsightBulletRow(
              icon: Icons.workspace_premium_outlined,
              text: streak,
            ),
          ],
          if (showReminder) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  refresh ? AppRadius.vrChip : 14,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.insightAddReminderPrompt(reminderTime),
                      style: refresh
                          ? GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: VisualRefreshColors.textPrimary,
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      onPressed: onAddReminder,
                      style: FilledButton.styleFrom(
                        backgroundColor: refresh
                            ? VisualRefreshColors.anchor
                            : AppColors.tealDeep,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        l10n.reminderAddShort,
                        style: refresh
                            ? GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              )
                            : const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightBulletRow extends StatelessWidget {
  const _InsightBulletRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: refresh
              ? VisualRefreshColors.routeText
              : const Color(0xFFB3722E),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: VisualRefreshColors.textPrimary,
                  )
                : const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DaysUnderLimitRow extends StatelessWidget {
  const _DaysUnderLimitRow({
    required this.daysUnderLimit,
    required this.totalDays,
  });

  final int daysUnderLimit;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 16,
        ),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 22,
            color: refresh
                ? VisualRefreshColors.rewardAccent
                : const Color(0xFFB3722E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.insightDaysUnderLimit(daysUnderLimit, totalDays),
                  style: refresh
                      ? GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: VisualRefreshColors.textPrimary,
                        )
                      : const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.insightRewardsAutoHint,
                  style: refresh
                      ? GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: VisualRefreshColors.textSecondary,
                        )
                      : const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.usedSeconds,
    required this.limitMinutes,
    required this.progress,
    required this.remainingSeconds,
    required this.enabled,
  });

  final int usedSeconds;
  final int limitMinutes;
  final double progress;
  final int remainingSeconds;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final pct = (progress * 100).round().clamp(0, 999);
    final overLimit = enabled && progress >= 1.0;
    final meterColor = refresh
        ? (overLimit ? VisualRefreshColors.danger : VisualRefreshColors.accent)
        : Colors.white;
    final fill = refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrHero : 24,
        ),
        boxShadow: refresh
            ? null
            : [
                BoxShadow(
                  color: AppColors.tealDeep.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabled ? l10n.todayLabel : l10n.limitOffLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDurationCompact(usedSeconds),
                      style: refresh
                          ? GoogleFonts.fraunces(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                              height: 1.05,
                            )
                          : const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1.05,
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.outOfLimitLabel(_fmtLimitHours(l10n, limitMinutes)),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        color: meterColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: meterColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l10n.durationHoursLabel(0),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.remainingTimeLabel(formatDurationCompact(remainingSeconds)),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
              ),
              Text(
                l10n.durationHoursLabel(limitMinutes ~/ 60),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  final UsagePeriod period;
  final ValueChanged<UsagePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.tagMuted : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: refresh ? null : Border.all(color: const Color(0x14075A4F)),
      ),
      child: Row(
        children: UsagePeriod.values.map((p) {
          final selected = p == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? (refresh
                          ? VisualRefreshColors.anchor
                          : AppColors.teal)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  p.shortLabel(l10n),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected
                        ? (refresh
                            ? VisualRefreshColors.background
                            : Colors.white)
                        : (refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft),
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopAppCallout extends StatelessWidget {
  const _TopAppCallout({
    required this.app,
    required this.periodLabel,
  });

  final _UsageAppRow app;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: VisualRefreshColors.routeTint,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 16,
        ),
        border: Border.all(color: VisualRefreshColors.rewardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                refresh ? AppRadius.vrChip : 12,
              ),
            ),
            child: Icon(
              appIconForPackage(app.packageName),
              color: VisualRefreshColors.routeText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.topAppCallout(
                periodLabel,
                app.label,
                formatDurationCompact(app.durationSeconds),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.35,
                color: VisualRefreshColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.app,
    required this.totalSeconds,
    required this.showTrend,
    required this.periodLabel,
  });

  final _UsageAppRow app;
  final int totalSeconds;
  final bool showTrend;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final classicAccent = appAccentForPackage(app.packageName);
    final iconBg =
        refresh ? VisualRefreshColors.accentTint : classicAccent.withValues(alpha: 0.14);
    final iconColor =
        refresh ? VisualRefreshColors.accent : classicAccent;
    final barColor =
        refresh ? VisualRefreshColors.anchor : classicAccent;
    final share = (app.durationSeconds / totalSeconds).clamp(0.0, 1.0);
    final pct = (share * 100).round();

    Widget? trend;
    if (showTrend) {
      final prior = app.priorDurationSeconds;
      if (prior == null || prior <= 0) {
        trend = Text(
          l10n.appTrendNew(periodLabel),
          style: TextStyle(
            color: refresh
                ? VisualRefreshColors.textSecondary
                : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            fontFamily: refresh
                ? GoogleFonts.plusJakartaSans().fontFamily
                : null,
          ),
        );
      } else {
        final delta =
            ((app.durationSeconds - prior) / prior * 100).round();
        final up = delta > 0;
        final flat = delta == 0;
        final color = flat
            ? (refresh
                ? VisualRefreshColors.textSecondary
                : AppColors.inkSoft)
            : (up
                ? VisualRefreshColors.danger
                : VisualRefreshColors.accent);
        trend = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              flat
                  ? Icons.remove_rounded
                  : (up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              flat ? '0%' : '${delta.abs()}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                fontFamily: refresh
                    ? GoogleFonts.plusJakartaSans().fontFamily
                    : null,
              ),
            ),
          ],
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                refresh ? AppRadius.vrChip : 12,
              ),
            ),
            child: Icon(
              appIconForPackage(app.packageName),
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: refresh ? VisualRefreshColors.textPrimary : null,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    backgroundColor: refresh
                        ? VisualRefreshColors.tagMuted
                        : const Color(0xFFE8ECF0),
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDurationCompact(app.durationSeconds),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: refresh ? VisualRefreshColors.textPrimary : null,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(height: 2),
                trend,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.days,
    required this.schoolLimitMinutes,
    required this.weekendLimitMinutes,
    required this.todaySeconds,
  });

  final List<_DayUsage> days;
  final int schoolLimitMinutes;
  final int weekendLimitMinutes;
  final int todaySeconds;

  int _limitFor(DateTime day) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    return isWeekend ? weekendLimitMinutes : schoolLimitMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final labels = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final byKey = <String, int>{
      for (final d in days) _dayKey(d.day): d.totalSeconds,
    };

    final values = List<int>.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = _dayKey(day);
      if (byKey.containsKey(key)) return byKey[key]!;
      if (days.isEmpty &&
          day.year == now.year &&
          day.month == now.month &&
          day.day == now.day) {
        return todaySeconds;
      }
      return 0;
    });

    final dayLimits = List<int>.generate(
      7,
      (i) => _limitFor(monday.add(Duration(days: i))) * 60,
    );
    final maxVal = [
      ...values,
      ...dayLimits,
      1,
    ].reduce((a, b) => a > b ? a : b);

    final overColor =
        refresh ? VisualRefreshColors.danger : AppColors.coral;
    final safeColor = refresh
        ? VisualRefreshColors.accent.withValues(alpha: 0.45)
        : AppColors.teal;
    final legendLimit = schoolLimitMinutes;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: _hubCardDecoration(context),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _WeekBar(
                      label: labels[i],
                      seconds: values[i],
                      maxSeconds: maxVal,
                      overLimit: values[i] > dayLimits[i] && dayLimits[i] > 0,
                      overColor: overColor,
                      safeColor: safeColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                color: overColor,
                label:
                    l10n.overLimitLegend(_fmtLimitHours(l10n, legendLimit)),
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: refresh ? VisualRefreshColors.accent : safeColor,
                label: l10n.safeLegendLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.label,
    required this.seconds,
    required this.maxSeconds,
    required this.overLimit,
    required this.overColor,
    required this.safeColor,
  });

  final String label;
  final int seconds;
  final int maxSeconds;
  final bool overLimit;
  final Color overColor;
  final Color safeColor;

  static const _barMax = 110.0;
  /// Floor ~8% of chart height so safe days stay visible.
  static const _minVisible = _barMax * 0.08;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    var h = maxSeconds <= 0 ? 0.0 : (seconds / maxSeconds) * _barMax;
    if (seconds > 0 && !overLimit && h < _minVisible) {
      h = _minVisible;
    } else if (seconds > 0 && h < 4) {
      h = 4;
    }
    final color = overLimit ? overColor : safeColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (seconds > 0)
          Text(
            formatDurationCompact(seconds),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: overLimit
                  ? overColor
                  : (refresh ? VisualRefreshColors.accent : color),
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        const SizedBox(height: 4),
        Container(
          height: h.clamp(0.0, _barMax),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: refresh
                ? VisualRefreshColors.textSecondary
                : AppColors.inkSoft,
            fontFamily: refresh
                ? GoogleFonts.plusJakartaSans().fontFamily
                : null,
          ),
        ),
      ],
    );
  }
}

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.days,
    required this.schoolLimitMinutes,
    required this.weekendLimitMinutes,
    this.patternText,
  });

  final List<_DayUsage> days;
  final int schoolLimitMinutes;
  final int weekendLimitMinutes;
  final String? patternText;

  int _limitFor(DateTime day) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    return isWeekend ? weekendLimitMinutes : schoolLimitMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final lastCell =
        monthEnd.add(Duration(days: DateTime.sunday - monthEnd.weekday));
    final weekCount =
        (lastCell.difference(gridStart).inDays ~/ 7) + 1;

    final byKey = <String, int>{
      for (final d in days) _dayKey(d.day): d.totalSeconds,
    };

    final headers = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];

    final legendColors = [
      VisualRefreshColors.tagMuted,
      const Color(0xFFE8D9BB),
      VisualRefreshColors.praiseBtn,
      const Color(0xFFC9634C),
      VisualRefreshColors.danger,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _hubCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final h in headers)
                Expanded(
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: VisualRefreshColors.textSecondary,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var w = 0; w < weekCount; w++) ...[
            if (w > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (var d = 0; d < 7; d++) ...[
                  if (d > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Builder(
                        builder: (context) {
                          final day =
                              gridStart.add(Duration(days: w * 7 + d));
                          final inMonth = day.month == now.month;
                          if (!inMonth) {
                            return const SizedBox.shrink();
                          }
                          final secs = byKey[_dayKey(day)] ?? 0;
                          final limitSec = _limitFor(day) * 60;
                          final pct =
                              limitSec <= 0 ? 0.0 : secs / limitSec;
                          return Container(
                            decoration: BoxDecoration(
                              color: _heatmapColorForPct(pct),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                l10n.heatmapLegendLow,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: VisualRefreshColors.textSecondary,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              for (final c in legendColors) ...[
                Container(
                  width: 14,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                l10n.heatmapLegendOver,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: VisualRefreshColors.textSecondary,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ],
          ),
          if (patternText != null && patternText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: VisualRefreshColors.routeTint,
                borderRadius: BorderRadius.circular(
                  refresh ? AppRadius.vrChip : 12,
                ),
                border: Border.all(
                  color: VisualRefreshColors.rewardBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                patternText!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: VisualRefreshColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: refresh
                ? VisualRefreshColors.textSecondary
                : AppColors.inkSoft,
            fontFamily: refresh
                ? GoogleFonts.plusJakartaSans().fontFamily
                : null,
          ),
        ),
      ],
    );
  }
}

/// Detail/aturan — dibuka dari ikon gear. Satu tempat edit + Simpan.
class ScreenTimeRulesScreen extends ConsumerStatefulWidget {
  const ScreenTimeRulesScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<ScreenTimeRulesScreen> createState() =>
      _ScreenTimeRulesScreenState();
}

class _ScreenTimeRulesScreenState extends ConsumerState<ScreenTimeRulesScreen> {
  bool _enabled = true;
  bool _schoolDaysOn = true;
  bool _weekendOn = true;
  int _schoolLimitMinutes = 180;
  int _weekendLimitMinutes = 300;
  bool _saving = false;
  bool _loading = false;
  final Set<String> _blocked = {};
  List<_UsageAppRow> _apps = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(widget.child.id));
  }

  void _applyPolicy(Map<String, dynamic>? current) {
    if (current == null) return;
    _enabled = current['enabled'] == true;
    final limit = (current['daily_limit_minutes'] as num?)?.toInt() ?? 180;
    final schedules = (current['schedules'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    var schoolOn = false;
    var weekendOn = false;
    int? schoolLimit;
    int? weekendLimit;
    for (final s in schedules) {
      final days = (s['days'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final lim = (s['limitMinutes'] as num?)?.toInt() ??
          (s['limit_minutes'] as num?)?.toInt();
      final isSchool = days.any((d) => d >= 1 && d <= 5);
      final isWeekend = days.any((d) => d == 6 || d == 7);
      if (isSchool) {
        schoolOn = true;
        if (lim != null) schoolLimit = lim;
      }
      if (isWeekend) {
        weekendOn = true;
        if (lim != null) weekendLimit = lim;
      }
    }

    if (schedules.isEmpty) {
      schoolOn = true;
      weekendOn = true;
      schoolLimit = limit <= 180 ? limit : 180;
      weekendLimit = limit > 180 ? limit : 300;
    }

    _schoolDaysOn = schoolOn;
    _weekendOn = weekendOn;
    _schoolLimitMinutes = schoolLimit ?? (limit <= 180 ? limit : 180);
    _weekendLimitMinutes = weekendLimit ?? (limit > 180 ? limit : 300);
  }

  Future<void> _load(String childId) async {
    setState(() => _loading = true);
    try {
      final policy =
          await ref.read(apiClientProvider).get('/api/v1/policies/$childId');
      final current = policy['policy'] as Map<String, dynamic>?;
      final summary = await ref
          .read(apiClientProvider)
          .get('/api/v1/telemetry/$childId/summary');

      final blocked = (current?['blocked_packages'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toSet();

      final apps = (summary['apps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final pkg = item['package_name'] as String? ?? '';
            final label = item['app_label'] as String?;
            return _UsageAppRow(
              packageName: pkg,
              label: friendlyAppName(pkg, appLabel: label),
              durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
            );
          })
          .where((a) => a.packageName.isNotEmpty)
          .toList();

      for (final pkg in blocked) {
        if (apps.every((a) => a.packageName != pkg)) {
          apps.add(
            _UsageAppRow(
              packageName: pkg,
              label: friendlyAppName(pkg),
              durationSeconds: 0,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _applyPolicy(current);
        _blocked
          ..clear()
          ..addAll(blocked);
        _apps = apps;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _apps = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _activeLimitMinutes {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    if (isWeekend) {
      return _weekendOn ? _weekendLimitMinutes : _schoolLimitMinutes;
    }
    return _schoolDaysOn ? _schoolLimitMinutes : _weekendLimitMinutes;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final scheduleEnabled = _schoolDaysOn || _weekendOn;
      await ref.read(apiClientProvider).put(
        '/api/v1/policies/${widget.child.id}',
        body: {
          'enabled': _enabled && scheduleEnabled,
          'dailyLimitMinutes': _activeLimitMinutes.clamp(15, 1440),
          'blockedPackages': _blocked.toList()..sort(),
          'schedules': [
            if (_schoolDaysOn)
              {
                'days': [1, 2, 3, 4, 5],
                'start': '00:00',
                'end': '23:59',
                'limitMinutes': _schoolLimitMinutes,
              },
            if (_weekendOn)
              {
                'days': [6, 7],
                'start': '00:00',
                'end': '23:59',
                'limitMinutes': _weekendLimitMinutes,
              },
          ],
          'emergencyAllowlist': const <String>[],
        },
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled && scheduleEnabled
                ? l10n.rulesSavedMessage(widget.child.name)
                : l10n.limitsDisabledMessage(widget.child.name),
          ),
        ),
      );
      await _load(widget.child.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailedWithDetail('$e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleBlock(String packageName, bool value) {
    setState(() {
      if (value) {
        _blocked.add(packageName);
      } else {
        _blocked.remove(packageName);
      }
    });
  }

  Future<void> _pickLimit({
    required String title,
    required int current,
    required ValueChanged<int> onPicked,
  }) async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final int? picked;
    if (refresh) {
      picked = await showVrModalBottomSheet<int>(
        context: context,
        builder: (ctx) {
          final bottomInset = MediaQuery.paddingOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: const BoxDecoration(
                color: VisualRefreshColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [VisualRefreshColors.dialogShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  const VrSheetDragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        height: 1.25,
                        color: VisualRefreshColors.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0;
                            i < _limitPresetMinutes.length;
                            i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 12,
                              endIndent: 12,
                              color: VisualRefreshColors.tagMuted,
                            ),
                          _VrLimitOptionRow(
                            label: _fmtLimitHours(
                              l10n,
                              _limitPresetMinutes[i],
                            ),
                            selected:
                                _limitPresetMinutes[i] == current,
                            onTap: () => Navigator.pop(
                              ctx,
                              _limitPresetMinutes[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      picked = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                for (final minutes in _limitPresetMinutes)
                  ListTile(
                    title: Text(
                      _fmtLimitHours(l10n, minutes),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: minutes == current
                            ? AppColors.tealDeep
                            : AppColors.ink,
                      ),
                    ),
                    trailing: minutes == current
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.teal,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, minutes),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    }
    if (picked != null) onPicked(picked);
  }

  static const _rulesBg = Color(0xFFF0F2F5);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final canEditLimits = _enabled;
    final bg = refresh ? VisualRefreshColors.background : _rulesBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor:
            refresh ? VisualRefreshColors.textPrimary : AppColors.ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        centerTitle: refresh,
        title: Text(
          l10n.screenTimeRulesTitle(widget.child.name),
          style: refresh
              ? GoogleFonts.fraunces(
                  color: VisualRefreshColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )
              : const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
        ),
        iconTheme: IconThemeData(
          color: refresh ? VisualRefreshColors.textPrimary : AppColors.ink,
        ),
        actionsIconTheme: IconThemeData(
          color: refresh ? VisualRefreshColors.textPrimary : AppColors.ink,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: refresh
                ? PaRoundIconButton(
                    icon: Icons.refresh_rounded,
                    semanticLabel: l10n.reloadTooltip,
                    onTap: () => _load(widget.child.id),
                    size: 40,
                    iconSize: 20,
                    elevation: 0,
                  )
                : IconButton(
                    tooltip: l10n.reloadTooltip,
                    onPressed: () => _load(widget.child.id),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _PremiumCard(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              title: Text(
                _enabled ? l10n.limitScreenUsageLabel : l10n.noLimitLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: refresh
                      ? VisualRefreshColors.textPrimary
                      : AppColors.ink,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              value: _enabled,
              activeTrackColor: refresh ? null : AppColors.teal,
              activeThumbColor: refresh ? null : Colors.white,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          const SizedBox(height: 22),
          _SectionLabel(l10n.limitScheduleTitle),
          _PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ScheduleRow(
                  icon: Icons.calendar_month_rounded,
                  iconBg: refresh
                      ? VisualRefreshColors.accentTint
                      : const Color(0xFFDCEBFF),
                  iconColor: refresh
                      ? VisualRefreshColors.accent
                      : const Color(0xFF2563EB),
                  title: l10n.schoolDaysTitle,
                  subtitle: l10n.schoolDaysRangeLabel,
                  enabled: _schoolDaysOn,
                  limitLabel: _fmtLimitHours(l10n, _schoolLimitMinutes),
                  canEdit: canEditLimits,
                  onToggle: canEditLimits
                      ? (v) => setState(() => _schoolDaysOn = v)
                      : null,
                  onPickLimit: canEditLimits && _schoolDaysOn
                      ? () => _pickLimit(
                            title: l10n.schoolLimitPickerTitle,
                            current: _schoolLimitMinutes,
                            onPicked: (m) =>
                                setState(() => _schoolLimitMinutes = m),
                          )
                      : null,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  endIndent: 16,
                  color: refresh
                      ? VisualRefreshColors.border
                      : const Color(0xFFE8ECF0),
                ),
                _ScheduleRow(
                  icon: refresh
                      ? Icons.bed_rounded
                      : Icons.weekend_rounded,
                  iconBg: refresh
                      ? const Color(0xFFF3E4D8)
                      : const Color(0xFFFFF0DC),
                  iconColor: refresh
                      ? VisualRefreshColors.danger
                      : const Color(0xFFD97706),
                  title: l10n.weekendDaysTitle,
                  subtitle: l10n.weekendDaysRangeLabel,
                  enabled: _weekendOn,
                  limitLabel: _fmtLimitHours(l10n, _weekendLimitMinutes),
                  canEdit: canEditLimits,
                  onToggle: canEditLimits
                      ? (v) => setState(() => _weekendOn = v)
                      : null,
                  onPickLimit: canEditLimits && _weekendOn
                      ? () => _pickLimit(
                            title: l10n.weekendLimitPickerTitle,
                            current: _weekendLimitMinutes,
                            onPicked: (m) =>
                                setState(() => _weekendLimitMinutes = m),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionLabel(l10n.blockedAppsTitle),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_apps.isEmpty)
            _PremiumCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Text(
                l10n.noAppListYet,
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            _PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < _apps.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 70,
                        endIndent: 16,
                        color: refresh
                            ? VisualRefreshColors.border
                            : const Color(0xFFE8ECF0),
                      ),
                    _AppBlockRow(
                      app: _apps[i],
                      blocked: _blocked.contains(_apps[i].packageName),
                      l10n: l10n,
                      onChanged: (v) =>
                          _toggleBlock(_apps[i].packageName, v),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: refresh
                    ? VisualRefreshColors.anchor
                    : AppColors.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: (refresh
                        ? VisualRefreshColors.anchor
                        : AppColors.teal)
                    .withValues(alpha: 0.45),
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                _saving ? l10n.savingLabel : l10n.save,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.2,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Padding(
      padding: EdgeInsets.only(left: refresh ? 2 : 4, bottom: 8),
      child: Text(
        label,
        style: refresh
            ? GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: VisualRefreshColors.textPrimary,
              )
            : const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDeep,
                letterSpacing: 0.2,
              ),
      ),
    );
  }
}

class _AppBlockRow extends StatelessWidget {
  const _AppBlockRow({
    required this.app,
    required this.blocked,
    required this.l10n,
    required this.onChanged,
  });
  final _UsageAppRow app;
  final bool blocked;
  final AppLocalizations l10n;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final classicAccent = appAccentForPackage(app.packageName);
    final iconBg =
        refresh ? VisualRefreshColors.accentTint : classicAccent.withValues(alpha: 0.14);
    final iconColor =
        refresh ? VisualRefreshColors.accent : classicAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                refresh ? AppRadius.vrChip : 12,
              ),
            ),
            child: Icon(
              appIconForPackage(app.packageName),
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: refresh ? VisualRefreshColors.textPrimary : null,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  app.durationSeconds <= 0
                      ? l10n.notUsedTodayLabel
                      : l10n.usedDurationLabel(
                          formatDuration(l10n, app.durationSeconds),
                        ),
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: blocked,
            activeThumbColor: refresh ? null : Colors.white,
            activeTrackColor: refresh ? null : AppColors.coral,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.limitLabel,
    required this.canEdit,
    required this.onToggle,
    required this.onPickLimit,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final String limitLabel;
  final bool canEdit;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onPickLimit;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final chipColor = refresh
        ? (canEdit && onPickLimit != null
            ? VisualRefreshColors.accentTint
            : VisualRefreshColors.tagMuted)
        : (canEdit && onPickLimit != null
            ? const Color(0xFFE6F5F1)
            : const Color(0xFFF3F5F7));
    final chipInk = refresh
        ? (canEdit && onPickLimit != null
            ? VisualRefreshColors.accent
            : VisualRefreshColors.textSecondary)
        : (canEdit && onPickLimit != null
            ? AppColors.tealDeep
            : AppColors.inkSoft);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: refresh ? 40 : 42,
            height: refresh ? 40 : 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                refresh ? AppRadius.vrChip : 12,
              ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : AppColors.ink,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
                if (enabled) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onPickLimit,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .maxLimitLabel(limitLabel),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: chipInk,
                                fontFamily: refresh
                                    ? GoogleFonts.plusJakartaSans().fontFamily
                                    : null,
                              ),
                            ),
                            if (onPickLimit != null) ...[
                              const SizedBox(width: 2),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: chipInk,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: enabled,
            activeThumbColor: refresh ? null : Colors.white,
            activeTrackColor: refresh ? null : AppColors.teal,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _VrLimitOptionRow extends StatelessWidget {
  const _VrLimitOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VisualRefreshColors.accentTint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? VisualRefreshColors.accent
                        : VisualRefreshColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: VisualRefreshColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
