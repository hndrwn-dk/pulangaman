import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class _HomeBySnapshot {
  const _HomeBySnapshot({
    required this.mode,
    required this.customHour,
    required this.customMinute,
    required this.graceMinutes,
    required this.weekendMode,
    required this.weekendHour,
    required this.weekendMinute,
    required this.today,
    required this.skipDates,
  });

  final String mode;
  final int customHour;
  final int customMinute;
  final int graceMinutes;
  final String weekendMode;
  final int weekendHour;
  final int weekendMinute;
  final Map<String, dynamic>? today;
  final List<Map<String, dynamic>> skipDates;
}

class HomeByScreen extends ConsumerStatefulWidget {
  const HomeByScreen({super.key, this.lockedChild, this.readOnly = false});

  /// When set (from child detail), the child picker is hidden.
  final ChildSummary? lockedChild;

  /// When true, settings are displayed but not editable.
  final bool readOnly;

  @override
  ConsumerState<HomeByScreen> createState() => _HomeByScreenState();
}

class _HomeByScreenState extends ConsumerState<HomeByScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _childId;
  String _mode = 'off';
  int _customHour = 18;
  int _customMinute = 0;
  int _graceMinutes = 30;
  String _weekendMode = 'off';
  int _weekendHour = 20;
  int _weekendMinute = 0;
  Map<String, dynamic>? _today;
  List<Map<String, dynamic>> _skipDates = [];
  Future<void>? _inFlight;
  int _loadGen = 0;
  /// Per-child cache — chip switches stay instant; spinner only on cold miss.
  final Map<String, _HomeBySnapshot> _cache = {};
  static const _timeout = Duration(seconds: 12);

  bool get _childLocked => widget.lockedChild != null;

  /// View-tier guardians never edit home-by, even if [readOnly] was omitted.
  bool get _effectiveReadOnly {
    if (widget.readOnly) return true;
    final locked = widget.lockedChild;
    if (locked != null) return locked.isViewOnlyAccess;
    final id = _childId;
    if (id == null) return false;
    for (final c in ref.read(childrenControllerProvider).items) {
      if (c.id == id) return c.isViewOnlyAccess;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _childId = widget.lockedChild?.id;
    Future.microtask(() async {
      if (_childId == null) {
        await ref.read(childrenControllerProvider.notifier).bootstrap();
        final items = ref.read(childrenControllerProvider).items;
        if (items.isEmpty) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        _childId = items.first.id;
      }
      await _load(_childId!);
    });
  }

  void _applySnapshot(_HomeBySnapshot snap) {
    _mode = snap.mode;
    _customHour = snap.customHour;
    _customMinute = snap.customMinute;
    _graceMinutes = snap.graceMinutes;
    _weekendMode = snap.weekendMode;
    _weekendHour = snap.weekendHour;
    _weekendMinute = snap.weekendMinute;
    _today = snap.today;
    _skipDates = List<Map<String, dynamic>>.from(snap.skipDates);
  }

  _HomeBySnapshot _currentSnapshot() {
    return _HomeBySnapshot(
      mode: _mode,
      customHour: _customHour,
      customMinute: _customMinute,
      graceMinutes: _graceMinutes,
      weekendMode: _weekendMode,
      weekendHour: _weekendHour,
      weekendMinute: _weekendMinute,
      today: _today,
      skipDates: List<Map<String, dynamic>>.from(_skipDates),
    );
  }

  void _selectChild(String id) {
    if (_childId == id) return;
    unawaited(_load(id));
  }

  Future<void> _load(String childId, {bool force = false}) {
    if (!force && _inFlight != null && _childId == childId) {
      return _inFlight!;
    }
    final run = _loadBody(childId);
    _inFlight = run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
    return _inFlight!;
  }

  Future<void> _loadBody(String childId) async {
    final gen = ++_loadGen;
    final cached = _cache[childId];
    setState(() {
      _childId = childId;
      if (cached != null) {
        _applySnapshot(cached);
        _loading = false;
      } else {
        _loading = true;
      }
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/api/v1/home-by/$childId'),
        api.get('/api/v1/home-by/$childId/today'),
        api.get('/api/v1/home-by/$childId/skip-dates'),
      ]).timeout(_timeout);
      if (!mounted || gen != _loadGen) return;
      final s = results[0]['settings'] as Map<String, dynamic>? ?? {};
      final snap = _HomeBySnapshot(
        mode: s['mode'] as String? ?? 'off',
        customHour: (s['customHour'] as num?)?.toInt() ?? 18,
        customMinute: (s['customMinute'] as num?)?.toInt() ?? 0,
        graceMinutes: (s['gracePeriodMinutes'] as num?)?.toInt() ?? 30,
        weekendMode: s['weekendMode'] as String? ?? 'off',
        weekendHour: (s['weekendHour'] as num?)?.toInt() ?? 20,
        weekendMinute: (s['weekendMinute'] as num?)?.toInt() ?? 0,
        today: results[1]['today'] as Map<String, dynamic>?,
        skipDates: (results[2]['skipDates'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
      _cache[childId] = snap;
      setState(() {
        _applySnapshot(snap);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final id = _childId;
    if (id == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put(
        '/api/v1/home-by/$id',
        body: {
          'mode': _mode,
          'customHour': _mode == 'custom' ? _customHour : null,
          'customMinute': _mode == 'custom' ? _customMinute : null,
          'gracePeriodMinutes': _graceMinutes,
          'weekendMode': _weekendMode,
          'weekendHour': _weekendMode == 'custom' ? _weekendHour : null,
          'weekendMinute': _weekendMode == 'custom' ? _weekendMinute : null,
          'enabled': true,
        },
      );
      if (!mounted) return;
      _cache[id] = _currentSnapshot();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeBySaved)),
      );
      await _load(id, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime({required bool weekend}) async {
    final initial = TimeOfDay(
      hour: weekend ? _weekendHour : _customHour,
      minute: weekend ? _weekendMinute : _customMinute,
    );
    final refresh = visualRefreshOf(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: refresh
              ? Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: VisualRefreshColors.anchor,
                          onPrimary: VisualRefreshColors.background,
                          secondary: VisualRefreshColors.accent,
                          surface: VisualRefreshColors.surface,
                          onSurface: VisualRefreshColors.textPrimary,
                        ),
                    timePickerTheme: TimePickerThemeData(
                      dialHandColor: VisualRefreshColors.accent,
                      dialBackgroundColor: VisualRefreshColors.accentTint,
                      hourMinuteColor: VisualRefreshColors.accentTint,
                      hourMinuteTextColor: VisualRefreshColors.anchor,
                      dayPeriodColor: VisualRefreshColors.accentTint,
                      helpTextStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: VisualRefreshColors.textPrimary,
                      ),
                    ),
                  ),
                  child: child!,
                )
              : child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (weekend) {
        _weekendHour = picked.hour;
        _weekendMinute = picked.minute;
      } else {
        _customHour = picked.hour;
        _customMinute = picked.minute;
      }
    });
  }

  Future<void> _addSkipDate() async {
    final childId = _childId;
    if (childId == null) return;
    final now = DateTime.now();
    final refresh = visualRefreshOf(context);
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      cancelText: l10n.cancel,
      confirmText: l10n.doneAction,
      builder: refresh
          ? (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: VisualRefreshColors.accent,
                        onPrimary: VisualRefreshColors.background,
                        surface: VisualRefreshColors.surface,
                        onSurface: VisualRefreshColors.textPrimary,
                      ),
                ),
                child: child!,
              );
            }
          : null,
    );
    if (picked == null) return;
    final date =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/home-by/$childId/skip-dates',
        body: {'skipDate': date},
      );
      await _load(childId, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeSkip(String id) async {
    final childId = _childId;
    try {
      await ref.read(apiClientProvider).delete('/api/v1/home-by/skip-dates/$id');
      if (childId != null) await _load(childId, force: true);
    } catch (_) {}
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'pre_notified':
        return l10n.homeByStatusPreNotified;
      case 'target_notified':
        return l10n.homeByStatusTargetNotified;
      case 'grace_notified':
        return l10n.homeByStatusGraceNotified;
      case 'resolved':
        return l10n.homeByStatusResolved;
      case 'skipped':
        return l10n.homeByStatusSkipped;
      case 'pending':
      default:
        return l10n.homeByStatusPending;
    }
  }

  String _fmtHm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String? _todayTargetLabel() {
    final raw = _today?['targetTime'] as String?;
    if (raw == null) return null;
    final at = DateTime.tryParse(raw)?.toLocal();
    if (at == null) return null;
    return _fmtHm(at.hour, at.minute);
  }

  String _modeSummaryValue(AppLocalizations l10n) {
    switch (_mode) {
      case 'maghrib':
        return l10n.homeByModeMaghrib;
      case 'custom':
        return '${l10n.homeByModeCustom} · ${_fmtHm(_customHour, _customMinute)}';
      case 'off':
      default:
        return l10n.homeByModeOff;
    }
  }

  String _weekendSummaryValue(AppLocalizations l10n) {
    switch (_weekendMode) {
      case 'same':
        return l10n.homeByWeekendSame;
      case 'custom':
        return '${l10n.homeByWeekendCustom} · ${_fmtHm(_weekendHour, _weekendMinute)}';
      case 'off':
      default:
        return l10n.homeByWeekendOff;
    }
  }

  String _holidaysSummaryValue(AppLocalizations l10n) {
    if (_skipDates.isEmpty) return l10n.homeBySkipDatesEmpty;
    return l10n.homeBySkipDatesCount(_skipDates.length);
  }

  Widget _todayStatusCard(AppLocalizations l10n, bool refresh) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeByTodayStatus,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: refresh ? 15.5 : null,
              color: refresh ? VisualRefreshColors.textPrimary : null,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusLabel(l10n, _today?['status'] as String?),
            style: TextStyle(
              color: refresh ? VisualRefreshColors.textSecondary : null,
              fontWeight: refresh ? FontWeight.w500 : null,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
          if (_todayTargetLabel() != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.homeByTargetTime(_todayTargetLabel()!),
              style: refresh
                  ? GoogleFonts.fraunces(
                      color: VisualRefreshColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 26,
                      height: 1.2,
                      letterSpacing: -0.4,
                    )
                  : const TextStyle(
                      color: AppColors.tealDeep,
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.homeByOnceHomeNote,
            style: TextStyle(
              color: refresh
                  ? VisualRefreshColors.textTertiary
                  : AppColors.inkSoft,
              fontSize: 13,
              height: 1.35,
              fontWeight: refresh ? FontWeight.w500 : null,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _viewOnlySummaryChildren(
    AppLocalizations l10n,
    bool refresh,
  ) {
    return [
      _SectionCard(
        child: Column(
          children: [
            _SummaryRow(
              label: l10n.homeByModeLabel,
              value: _modeSummaryValue(l10n),
            ),
            if (_mode != 'off') ...[
              const SizedBox(height: 14),
              _SummaryRow(
                label: l10n.homeByGraceLabel,
                value: l10n.homeByGraceHint(_graceMinutes),
              ),
              const SizedBox(height: 14),
              _SummaryRow(
                label: l10n.homeByWeekendTitle,
                value: _weekendSummaryValue(l10n),
              ),
              const SizedBox(height: 14),
              _SummaryRow(
                label: l10n.homeBySkipDatesTitle,
                value: _holidaysSummaryValue(l10n),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _todayStatusCard(l10n, refresh),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final children = ref.watch(childrenControllerProvider).items;
    String? selectedName = widget.lockedChild?.name;
    if (selectedName == null) {
      for (final c in children) {
        if (c.id == _childId) {
          selectedName = c.name;
          break;
        }
      }
    }
    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.homeByTitle,
              subtitle: selectedName,
              showBack: Navigator.of(context).canPop(),
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
            ),
            if (!_childLocked && children.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = children[i];
                      final selected = c.id == _childId;
                      if (refresh) {
                        return _VrChildChip(
                          name: c.name,
                          selected: selected,
                          onTap: () => _selectChild(c.id),
                        );
                      }
                      return ChoiceChip(
                        label: Text(c.name),
                        selected: selected,
                        onSelected: (_) => _selectChild(c.id),
                        selectedColor: AppColors.tealDeep,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: refresh
                            ? VisualRefreshColors.accent
                            : AppColors.teal,
                      ),
                    )
                  : _childId == null
                  ? Center(
                      child: Text(
                        l10n.homeByNoChildren,
                        style: TextStyle(
                          color: refresh
                              ? VisualRefreshColors.textSecondary
                              : AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontFamily: refresh
                              ? GoogleFonts.plusJakartaSans().fontFamily
                              : null,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        Text(
                          l10n.homeBySubtitle,
                          style: TextStyle(
                            color: refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft,
                            fontWeight:
                                refresh ? FontWeight.w500 : FontWeight.w600,
                            fontSize: refresh ? 14 : null,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_effectiveReadOnly)
                          ..._viewOnlySummaryChildren(l10n, refresh)
                        else ...[
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ModeTile(
                                  selected: _mode == 'off',
                                  title: l10n.homeByModeOff,
                                  onTap: () => setState(() => _mode = 'off'),
                                ),
                                _ModeTile(
                                  selected: _mode == 'maghrib',
                                  title: l10n.homeByModeMaghrib,
                                  subtitle: l10n.homeByModeMaghribHint,
                                  featuredIcon: Icons.nights_stay_rounded,
                                  onTap: () =>
                                      setState(() => _mode = 'maghrib'),
                                ),
                                _ModeTile(
                                  selected: _mode == 'custom',
                                  title: l10n.homeByModeCustom,
                                  onTap: () =>
                                      setState(() => _mode = 'custom'),
                                ),
                                if (_mode == 'custom') ...[
                                  const SizedBox(height: 8),
                                  _TimePickRow(
                                    label: _fmtHm(_customHour, _customMinute),
                                    onTap: () => _pickTime(weekend: false),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_mode != 'off') ...[
                            const SizedBox(height: 12),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.homeByGraceLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: refresh ? 15.5 : null,
                                      color: refresh
                                          ? VisualRefreshColors.textPrimary
                                          : null,
                                      fontFamily: refresh
                                          ? GoogleFonts.plusJakartaSans()
                                              .fontFamily
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    l10n.homeByGraceHint(_graceMinutes),
                                    style: TextStyle(
                                      color: refresh
                                          ? VisualRefreshColors.textSecondary
                                          : null,
                                      fontWeight:
                                          refresh ? FontWeight.w500 : null,
                                      fontFamily: refresh
                                          ? GoogleFonts.plusJakartaSans()
                                              .fontFamily
                                          : null,
                                    ),
                                  ),
                                  Slider(
                                    value: _graceMinutes.toDouble(),
                                    min: 5,
                                    max: 120,
                                    divisions: 23,
                                    label: '$_graceMinutes',
                                    activeColor: refresh
                                        ? VisualRefreshColors.anchor
                                        : null,
                                    inactiveColor: refresh
                                        ? VisualRefreshColors.tagMuted
                                        : null,
                                    onChanged: (v) => setState(
                                      () => _graceMinutes = v.round(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!refresh) ...[
                                    Text(
                                      l10n.homeByWeekendTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _ModeTile(
                                    selected: _weekendMode == 'off',
                                    title: l10n.homeByWeekendOff,
                                    featuredIcon: Icons.nights_stay_rounded,
                                    onTap: () => setState(
                                      () => _weekendMode = 'off',
                                    ),
                                  ),
                                  _ModeTile(
                                    selected: _weekendMode == 'same',
                                    title: l10n.homeByWeekendSame,
                                    onTap: () => setState(
                                      () => _weekendMode = 'same',
                                    ),
                                  ),
                                  _ModeTile(
                                    selected: _weekendMode == 'custom',
                                    title: l10n.homeByWeekendCustom,
                                    onTap: () => setState(
                                      () => _weekendMode = 'custom',
                                    ),
                                  ),
                                  if (_weekendMode == 'custom')
                                    _TimePickRow(
                                      label: _fmtHm(
                                        _weekendHour,
                                        _weekendMinute,
                                      ),
                                      onTap: () => _pickTime(weekend: true),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.homeBySkipDatesTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: refresh ? 15.5 : null,
                                            color: refresh
                                                ? VisualRefreshColors
                                                    .textPrimary
                                                : null,
                                            fontFamily: refresh
                                                ? GoogleFonts.plusJakartaSans()
                                                    .fontFamily
                                                : null,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _addSkipDate,
                                        style: TextButton.styleFrom(
                                          foregroundColor: refresh
                                              ? VisualRefreshColors.accent
                                              : null,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                        ),
                                        child: Text(
                                          l10n.homeBySkipDatesAdd,
                                          style: TextStyle(
                                            fontWeight: refresh
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            fontFamily: refresh
                                                ? GoogleFonts.plusJakartaSans()
                                                    .fontFamily
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_skipDates.isEmpty)
                                    Text(
                                      l10n.homeBySkipDatesEmpty,
                                      style: TextStyle(
                                        color: refresh
                                            ? VisualRefreshColors
                                                .textSecondary
                                            : AppColors.inkSoft,
                                        fontWeight:
                                            refresh ? FontWeight.w500 : null,
                                        fontFamily: refresh
                                            ? GoogleFonts.plusJakartaSans()
                                                .fontFamily
                                            : null,
                                      ),
                                    )
                                  else
                                    ..._skipDates.map((s) {
                                      final id = s['id'] as String? ?? '';
                                      final date =
                                          '${s['skipDate']}'.split('T').first;
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          date,
                                          style: TextStyle(
                                            color: refresh
                                                ? VisualRefreshColors
                                                    .textPrimary
                                                : null,
                                            fontFamily: refresh
                                                ? GoogleFonts.plusJakartaSans()
                                                    .fontFamily
                                                : null,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.close_rounded,
                                            color: refresh
                                                ? VisualRefreshColors
                                                    .textSecondary
                                                : null,
                                          ),
                                          onPressed: id.isEmpty
                                              ? null
                                              : () => unawaited(
                                                    _removeSkip(id),
                                                  ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _todayStatusCard(l10n, refresh),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: refresh ? 56 : null,
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              style: refresh
                                  ? FilledButton.styleFrom(
                                      backgroundColor:
                                          VisualRefreshColors.anchor,
                                      foregroundColor:
                                          VisualRefreshColors.background,
                                      disabledBackgroundColor:
                                          VisualRefreshColors.anchor
                                              .withValues(alpha: 0.45),
                                      elevation: 0,
                                      shape: const StadiumBorder(),
                                    )
                                  : null,
                              child: Text(
                                _saving ? '...' : l10n.homeBySave,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: refresh ? 16 : null,
                                  fontFamily: refresh
                                      ? GoogleFonts.plusJakartaSans()
                                          .fontFamily
                                      : null,
                                ),
                              ),
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
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: refresh ? 13.5 : 13,
              color: refresh
                  ? VisualRefreshColors.textSecondary
                  : AppColors.inkSoft,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: refresh ? 15 : 14.5,
              height: 1.35,
              color: refresh
                  ? VisualRefreshColors.textPrimary
                  : AppColors.ink,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(refresh ? 12 : 14),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 16,
        ),
        border: Border.all(
          color: refresh
              ? VisualRefreshColors.border
              : const Color(0xFFE2E6EA),
          width: refresh ? 0.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.featuredIcon,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? featuredIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    if (!refresh) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color: selected ? AppColors.tealDeep : AppColors.inkSoft,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(fontSize: 12.5),
              ),
        onTap: onTap,
      );
    }

    final useFeatureIcon = selected && featuredIcon != null;
    return Material(
      color: selected ? VisualRefreshColors.accentTint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (useFeatureIcon)
                Icon(
                  featuredIcon,
                  size: 22,
                  color: VisualRefreshColors.accent,
                )
              else
                _VrRadioDot(selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? VisualRefreshColors.accent
                            : VisualRefreshColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: VisualRefreshColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VrRadioDot extends StatelessWidget {
  const _VrRadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? VisualRefreshColors.accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? VisualRefreshColors.accent
              : VisualRefreshColors.border,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            )
          : null,
    );
  }
}

class _VrChildChip extends StatelessWidget {
  const _VrChildChip({
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
      color: selected
          ? VisualRefreshColors.anchor
          : VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: VisualRefreshColors.border,
                    width: 0.5,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: VisualRefreshColors.background,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: selected
                      ? VisualRefreshColors.background
                      : VisualRefreshColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickRow extends StatelessWidget {
  const _TimePickRow({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    if (!refresh) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: const Icon(Icons.schedule_rounded),
        onTap: onTap,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.schedule_rounded,
                color: VisualRefreshColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
