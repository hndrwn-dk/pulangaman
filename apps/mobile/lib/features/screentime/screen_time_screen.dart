import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../child/child_usage_utils.dart';
import '../parent/children_controller.dart';

class _UsageAppRow {
  _UsageAppRow({
    required this.packageName,
    required this.label,
    required this.durationSeconds,
  });

  final String packageName;
  final String label;
  final int durationSeconds;
}

class _DayUsage {
  _DayUsage({required this.day, required this.totalSeconds});

  final DateTime day;
  final int totalSeconds;
}

const _limitPresets = <({int minutes, String label})>[
  (minutes: 30, label: '30 menit'),
  (minutes: 60, label: '1 jam'),
  (minutes: 90, label: '1,5 jam'),
  (minutes: 120, label: '2 jam'),
  (minutes: 180, label: '3 jam'),
  (minutes: 300, label: '5 jam'),
];

/// Hub Waktu Layar (tab parent) — redesign premium sesuai mockup.
class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

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
  List<_DayUsage> _week = [];
  bool _showAllApps = false;

  @override
  void initState() {
    super.initState();
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
    final id = _selectedChildId ?? items.first.id;
    if (_selectedChildId != id) {
      setState(() => _selectedChildId = id);
    }
    await _loadFor(id);
  }

  void _selectChild(String id) {
    if (_selectedChildId == id) return;
    setState(() {
      _selectedChildId = id;
      _showAllApps = false;
    });
    unawaited(_loadFor(id));
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
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final policy = await api.get('/api/v1/policies/$childId');
      final current = policy['policy'] as Map<String, dynamic>?;
      final summary = await api.get('/api/v1/telemetry/$childId/summary');

      List<_DayUsage> week = [];
      try {
        final weekly = await api.get('/api/v1/telemetry/$childId/weekly');
        week = (weekly['days'] as List<dynamic>? ?? [])
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
      } catch (_) {
        week = [];
      }

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

      if (!mounted) return;
      setState(() {
        _applyPolicyToState(current);
        _apps = apps;
        _week = week;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apps = [];
        _week = [];
        _loading = false;
      });
    }
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

  int get _usedSeconds =>
      _apps.fold<int>(0, (sum, a) => sum + a.durationSeconds);

  int get _activeLimitMinutes {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    if (isWeekend) {
      return _weekendOn ? _weekendLimitMinutes : _schoolLimitMinutes;
    }
    return _schoolDaysOn ? _schoolLimitMinutes : _weekendLimitMinutes;
  }

  String get _scheduleSummary {
    if (!_enabled) return 'Batasan dimatikan';
    final parts = <String>[];
    if (_schoolDaysOn) {
      parts.add('Sen–Jum ${_fmtLimitHours(_schoolLimitMinutes)}');
    }
    if (_weekendOn) {
      parts.add('Sab–Min ${_fmtLimitHours(_weekendLimitMinutes)}');
    }
    if (parts.isEmpty) return 'Tidak ada jadwal aktif';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
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

    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (c) => c.id == _selectedChildId,
            orElse: () => items.first,
          );

    final limitSec = _activeLimitMinutes * 60;
    final used = _usedSeconds;
    final progress = limitSec <= 0 ? 0.0 : (used / limitSec).clamp(0.0, 1.0);
    final remaining = (limitSec - used).clamp(0, limitSec);
    final visibleApps = _showAllApps ? _apps : _apps.take(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: () async {
            final id = _selectedChildId;
            if (id != null) await _loadFor(id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu Layar',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pantau penggunaan harian',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFE8ECF0),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: selected == null
                          ? null
                          : () => _openSettings(selected),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.settings_rounded, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 40),
                const PaEmptyState(
                  icon: Icons.child_care,
                  title: 'Belum ada anak',
                  message: 'Tambah anak dulu di tab Anak.',
                ),
              ] else ...[
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
                        onTap: () => _selectChild(c.id),
                      );
                    },
                  ),
                ),
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
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Penggunaan Aplikasi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_apps.length > 4)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showAllApps = !_showAllApps),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.teal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _showAllApps ? 'Tutup' : 'Lihat semua ›',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_apps.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration,
                      child: const Text(
                        'Belum ada data app hari ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: _cardDecoration,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Column(
                        children: [
                          for (var i = 0; i < visibleApps.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: Color(0xFFE8ECF0)),
                            _AppUsageRow(
                              app: visibleApps[i],
                              totalSeconds: used <= 0 ? 1 : used,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'Minggu Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _WeekChart(
                    days: _week,
                    limitMinutes: _activeLimitMinutes,
                    todaySeconds: used,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Jadwal Batasan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selected != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openSettings(selected),
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          decoration: _cardDecoration,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F6F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.tealDeep,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _scheduleSummary,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Ubah di Aturan',
                                        style: TextStyle(
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
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

String _fmtLimitHours(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60} jam';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m menit';
  return '${h}j ${m}m';
}

final BoxDecoration _cardDecoration = BoxDecoration(
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

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealDeep : Colors.white,
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
                : Border.all(color: const Color(0xFFE2E6EA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF93C5FD),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
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
    final pct = (progress * 100).round().clamp(0, 999);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.tealDeep,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
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
                      enabled ? 'Hari ini' : 'Batas dimatikan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDurationCompact(usedSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'dari batas ${_fmtLimitHours(limitMinutes)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
                        color: Colors.white,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '0j',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  'Sisa ${formatDurationCompact(remainingSeconds)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${limitMinutes ~/ 60}j',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({required this.app, required this.totalSeconds});

  final _UsageAppRow app;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final accent = appAccentForPackage(app.packageName);
    final share = (app.durationSeconds / totalSeconds).clamp(0.0, 1.0);
    final pct = (share * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              appIconForPackage(app.packageName),
              color: accent,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE8ECF0),
                    color: accent,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
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
    required this.limitMinutes,
    required this.todaySeconds,
  });

  final List<_DayUsage> days;
  final int limitMinutes;
  final int todaySeconds;

  static const _labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    // Build Mon→Sun of current week, fill from API days when available.
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final byKey = <String, int>{
      for (final d in days)
        '${d.day.year}-${d.day.month.toString().padLeft(2, '0')}-${d.day.day.toString().padLeft(2, '0')}':
            d.totalSeconds,
    };

    final values = List<int>.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (byKey.containsKey(key)) return byKey[key]!;
      // Fallback: put today's usage on today's column if weekly API empty.
      if (days.isEmpty &&
          day.year == now.year &&
          day.month == now.month &&
          day.day == now.day) {
        return todaySeconds;
      }
      return 0;
    });

    final limitSec = limitMinutes * 60;
    final maxVal = [
      ...values,
      limitSec,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: _cardDecoration,
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
                      label: _labels[i],
                      seconds: values[i],
                      maxSeconds: maxVal,
                      overLimit: values[i] > limitSec && limitSec > 0,
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
                color: AppColors.coral,
                label: 'Melebihi batas (${_fmtLimitHours(limitMinutes)})',
              ),
              const SizedBox(width: 16),
              const _LegendDot(color: AppColors.teal, label: 'Aman'),
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
  });

  final String label;
  final int seconds;
  final int maxSeconds;
  final bool overLimit;

  @override
  Widget build(BuildContext context) {
    final h = maxSeconds <= 0 ? 0.0 : (seconds / maxSeconds) * 110;
    final color = overLimit ? AppColors.coral : AppColors.teal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (seconds > 0)
          Text(
            formatDurationCompact(seconds),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        const SizedBox(height: 4),
        Container(
          height: h.clamp(4.0, 110.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled && scheduleEnabled
                ? 'Aturan tersimpan untuk ${widget.child.name}. '
                    'Buka PulangAman di HP anak supaya aktif.'
                : 'Batas waktu dimatikan untuk ${widget.child.name}.',
          ),
        ),
      );
      await _load(widget.child.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
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
    final picked = await showModalBottomSheet<int>(
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
              for (final preset in _limitPresets)
                ListTile(
                  title: Text(
                    preset.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: preset.minutes == current
                          ? AppColors.tealDeep
                          : AppColors.ink,
                    ),
                  ),
                  trailing: preset.minutes == current
                      ? const Icon(Icons.check_rounded, color: AppColors.teal)
                      : null,
                  onTap: () => Navigator.pop(ctx, preset.minutes),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final canEditLimits = _enabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Aturan · ${widget.child.name}'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => _load(widget.child.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PaSectionCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _enabled ? 'Batasi main HP' : 'Tanpa batas',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Jadwal Batasan',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDecoration,
            child: Column(
              children: [
                _ScheduleRow(
                  icon: Icons.calendar_month_rounded,
                  iconBg: const Color(0xFFDCEBFF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Hari Sekolah',
                  subtitle: 'Sen–Jum',
                  enabled: _schoolDaysOn,
                  limitLabel: _fmtLimitHours(_schoolLimitMinutes),
                  canEdit: canEditLimits,
                  onToggle: canEditLimits
                      ? (v) => setState(() => _schoolDaysOn = v)
                      : null,
                  onPickLimit: canEditLimits && _schoolDaysOn
                      ? () => _pickLimit(
                            title: 'Batas hari sekolah',
                            current: _schoolLimitMinutes,
                            onPicked: (m) =>
                                setState(() => _schoolLimitMinutes = m),
                          )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ScheduleRow(
                  icon: Icons.weekend_rounded,
                  iconBg: const Color(0xFFFFF0DC),
                  iconColor: const Color(0xFFD97706),
                  title: 'Akhir Pekan',
                  subtitle: 'Sab–Min',
                  enabled: _weekendOn,
                  limitLabel: _fmtLimitHours(_weekendLimitMinutes),
                  canEdit: canEditLimits,
                  onToggle: canEditLimits
                      ? (v) => setState(() => _weekendOn = v)
                      : null,
                  onPickLimit: canEditLimits && _weekendOn
                      ? () => _pickLimit(
                            title: 'Batas akhir pekan',
                            current: _weekendLimitMinutes,
                            onPicked: (m) =>
                                setState(() => _weekendLimitMinutes = m),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'App yang ditahan',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_apps.isEmpty)
            const PaSectionCard(
              child: Text(
                'Belum ada daftar app.',
                style: TextStyle(color: AppColors.inkSoft),
              ),
            )
          else
            ..._apps.map((app) {
              final blocked = _blocked.contains(app.packageName);
              final accent = appAccentForPackage(app.packageName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          appIconForPackage(app.packageName),
                          color: accent,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              app.durationSeconds <= 0
                                  ? 'Belum dipakai hari ini'
                                  : 'Dipakai ${formatDuration(app.durationSeconds)}',
                              style: const TextStyle(
                                color: AppColors.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: blocked,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.coral,
                        onChanged: (value) =>
                            _toggleBlock(app.packageName, value),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.teal,
            ),
            child: Text(
              _saving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onPickLimit,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Maks $limitLabel',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: canEdit
                                    ? AppColors.tealDeep
                                    : AppColors.inkSoft,
                              ),
                            ),
                            if (onPickLimit != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: canEdit
                                    ? AppColors.tealDeep
                                    : AppColors.inkSoft,
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
          Switch(
            value: enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.teal,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
