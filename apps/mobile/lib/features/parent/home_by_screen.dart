import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class HomeByScreen extends ConsumerStatefulWidget {
  const HomeByScreen({super.key, this.lockedChild});

  /// When set (from child detail), the child picker is hidden.
  final ChildSummary? lockedChild;

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

  bool get _childLocked => widget.lockedChild != null;

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
      await _load();
    });
  }

  void _selectChild(String id) {
    if (_childId == id) return;
    setState(() => _childId = id);
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = _childId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final settingsRes = await api.get('/api/v1/home-by/$id');
      final todayRes = await api.get('/api/v1/home-by/$id/today');
      final skipRes = await api.get('/api/v1/home-by/$id/skip-dates');
      final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _mode = s['mode'] as String? ?? 'off';
        _customHour = (s['customHour'] as num?)?.toInt() ?? 18;
        _customMinute = (s['customMinute'] as num?)?.toInt() ?? 0;
        _graceMinutes = (s['gracePeriodMinutes'] as num?)?.toInt() ?? 30;
        _weekendMode = s['weekendMode'] as String? ?? 'off';
        _weekendHour = (s['weekendHour'] as num?)?.toInt() ?? 20;
        _weekendMinute = (s['weekendMinute'] as num?)?.toInt() ?? 0;
        _today = todayRes['today'] as Map<String, dynamic>?;
        _skipDates = (skipRes['skipDates'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeBySaved)),
      );
      await _load();
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
    final picked = await showTimePicker(context: context, initialTime: initial);
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
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeSkip(String id) async {
    try {
      await ref.read(apiClientProvider).delete('/api/v1/home-by/skip-dates/$id');
      await _load();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.homeByTitle,
              subtitle: selectedName,
            ),
            if (!_childLocked && children.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = children[i];
                    final selected = c.id == _childId;
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _childId == null
                  ? Center(
                      child: Text(
                        l10n.homeByNoChildren,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        Text(
                          l10n.homeBySubtitle,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
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
                                onTap: () => setState(() => _mode = 'maghrib'),
                              ),
                              _ModeTile(
                                selected: _mode == 'custom',
                                title: l10n.homeByModeCustom,
                                onTap: () => setState(() => _mode = 'custom'),
                              ),
                              if (_mode == 'custom') ...[
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_fmtHm(_customHour, _customMinute)),
                                  trailing: const Icon(Icons.schedule_rounded),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(l10n.homeByGraceHint(_graceMinutes)),
                                Slider(
                                  value: _graceMinutes.toDouble(),
                                  min: 5,
                                  max: 120,
                                  divisions: 23,
                                  label: '$_graceMinutes',
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
                                Text(
                                  l10n.homeByWeekendTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _ModeTile(
                                  selected: _weekendMode == 'off',
                                  title: l10n.homeByWeekendOff,
                                  onTap: () =>
                                      setState(() => _weekendMode = 'off'),
                                ),
                                _ModeTile(
                                  selected: _weekendMode == 'same',
                                  title: l10n.homeByWeekendSame,
                                  onTap: () =>
                                      setState(() => _weekendMode = 'same'),
                                ),
                                _ModeTile(
                                  selected: _weekendMode == 'custom',
                                  title: l10n.homeByWeekendCustom,
                                  onTap: () =>
                                      setState(() => _weekendMode = 'custom'),
                                ),
                                if (_weekendMode == 'custom')
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _fmtHm(_weekendHour, _weekendMinute),
                                    ),
                                    trailing:
                                        const Icon(Icons.schedule_rounded),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _addSkipDate,
                                      child: Text(l10n.homeBySkipDatesAdd),
                                    ),
                                  ],
                                ),
                                if (_skipDates.isEmpty)
                                  Text(
                                    l10n.homeBySkipDatesEmpty,
                                    style: const TextStyle(
                                      color: AppColors.inkSoft,
                                    ),
                                  )
                                else
                                  ..._skipDates.map((s) {
                                    final id = s['id'] as String? ?? '';
                                    final date = '${s['skipDate']}'.split('T').first;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(date),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: id.isEmpty
                                            ? null
                                            : () => unawaited(_removeSkip(id)),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.homeByTodayStatus,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _statusLabel(
                                  l10n,
                                  _today?['status'] as String?,
                                ),
                              ),
                              if (_todayTargetLabel() != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.homeByTargetTime(_todayTargetLabel()!),
                                  style: const TextStyle(
                                    color: AppColors.tealDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                l10n.homeByOnceHomeNote,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? '...' : l10n.homeBySave,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6EA)),
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
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}
