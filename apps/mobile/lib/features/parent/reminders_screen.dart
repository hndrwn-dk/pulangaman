import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'vr_sheet_chrome.dart';

class ChildReminder {
  ChildReminder({
    required this.id,
    required this.childId,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    required this.style,
    required this.enabled,
  });

  final String id;
  final String childId;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final List<int> daysOfWeek;
  final String style;
  final bool enabled;

  factory ChildReminder.fromJson(Map<String, dynamic> json) {
    return ChildReminder(
      id: json['id'] as String,
      childId: json['childId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      style: json['style'] as String? ?? 'fullscreen',
      enabled: json['enabled'] != false,
    );
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({
    super.key,
    this.initialChildId,
    this.lockChild = false,
  });

  /// Prefill / lock the selected child (e.g. from child detail).
  final String? initialChildId;

  /// When true with [initialChildId], hide the child picker.
  final bool lockChild;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String? _childId;
  List<ChildReminder> _items = [];
  bool _loading = false;
  String? _error;
  Future<void>? _inFlight;
  int _loadGen = 0;
  final Map<String, ChildGender> _genders = {};
  /// Per-child list cache — chip switches stay instant; spinner only on cold miss.
  final Map<String, List<ChildReminder>> _cache = {};
  static const _timeout = Duration(seconds: 12);

  bool get _childLocked =>
      widget.lockChild && (widget.initialChildId?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialChildId;
    if (initial != null && initial.isNotEmpty) {
      _childId = initial;
    }
    Future.microtask(() async {
      await _hydrateGenders();
      final id = _childId;
      if (id != null) await _load(id);
    });
  }

  Future<void> _hydrateGenders() async {
    final children = ref.read(childrenControllerProvider).items;
    final map = <String, ChildGender>{};
    for (final c in children) {
      var g = await ChildGenderStore.instance.get(c.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(c.name);
      }
      map[c.id] = g;
    }
    if (!mounted) return;
    setState(() {
      _genders
        ..clear()
        ..addAll(map);
    });
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
        _items = List<ChildReminder>.from(cached);
        _loading = false;
      } else {
        _items = [];
        _loading = true;
      }
      _error = null;
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/reminders/$childId')
          .timeout(_timeout);
      if (!mounted || gen != _loadGen) return;
      final list = (data['reminders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildReminder.fromJson)
          .toList();
      _cache[childId] = list;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) {
          _error = AppLocalizations.of(context).remindersLoadError;
        }
      });
    }
  }

  void _putCache(String childId, List<ChildReminder> items) {
    _cache[childId] = List<ChildReminder>.from(items);
  }

  Future<void> _createPreset({
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final childId = _childId;
    if (childId == null) return;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/reminders/$childId',
        body: {
          'title': title,
          'body': body,
          'hour': hour,
          'minute': minute,
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
          'style': 'fullscreen',
          'enabled': true,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).reminderPresetSaved(title),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      await _load(childId, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<TimeOfDay?> _pickReminderTime({
    required BuildContext dialogContext,
    required AppLocalizations l10n,
    required int hour,
    required int minute,
    required bool refresh,
  }) {
    return showTimePicker(
      context: dialogContext,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: l10n.reminderPickTimeHelp,
      cancelText: l10n.cancel,
      confirmText: l10n.reminderUseThisTime,
      hourLabelText: l10n.reminderHourLabel,
      minuteLabelText: l10n.reminderMinuteLabel,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                dialHandColor:
                    refresh ? VisualRefreshColors.accent : AppColors.teal,
                dialBackgroundColor: refresh
                    ? VisualRefreshColors.accentTint
                    : AppColors.mint.withValues(alpha: 0.35),
                hourMinuteColor: refresh
                    ? VisualRefreshColors.accentTint
                    : AppColors.teal.withValues(alpha: 0.12),
                hourMinuteTextColor: refresh
                    ? VisualRefreshColors.anchor
                    : AppColors.tealDeep,
                dayPeriodColor:
                    refresh ? VisualRefreshColors.accentTint : AppColors.mint,
                helpTextStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: refresh
                      ? VisualRefreshColors.textPrimary
                      : null,
                ),
              ),
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: refresh
                        ? VisualRefreshColors.anchor
                        : AppColors.teal,
                  ),
            ),
            child: child!,
          ),
        );
      },
    );
  }

  Future<void> _showCustomDialog({ChildReminder? existing}) async {
    final childId = _childId;
    if (childId == null) return;
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    var hour = existing?.hour ?? 19;
    var minute = existing?.minute ?? 0;
    var style = existing?.style ?? 'fullscreen';
    final days = {...(existing?.daysOfWeek ?? const [1, 2, 3, 4, 5, 6, 7])};
    final editing = existing != null;

    try {
      final bool? ok;
      if (refresh) {
        ok = await showVrModalBottomSheet<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setLocal) {
                final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: VrSheetShell(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VrSheetTitle(
                            editing
                                ? l10n.reminderEditTitle
                                : l10n.reminderCustomTitle,
                          ),
                          const SizedBox(height: 20),
                          _VrFieldLabel(l10n.reminderTitleFieldLabel),
                          const SizedBox(height: 6),
                          TextField(
                            controller: titleCtrl,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrInputDecoration(),
                          ),
                          const SizedBox(height: 14),
                          _VrFieldLabel(l10n.reminderMessageFieldLabel),
                          const SizedBox(height: 6),
                          TextField(
                            controller: bodyCtrl,
                            maxLines: 2,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrInputDecoration(),
                          ),
                          const SizedBox(height: 16),
                          _VrFieldLabel(l10n.reminderTimeQuestion),
                          const SizedBox(height: 8),
                          Material(
                            color: VisualRefreshColors.accentTint,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final picked = await _pickReminderTime(
                                  dialogContext: ctx,
                                  l10n: l10n,
                                  hour: hour,
                                  minute: minute,
                                  refresh: true,
                                );
                                if (picked != null) {
                                  setLocal(() {
                                    hour = picked.hour;
                                    minute = picked.minute;
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      color: VisualRefreshColors.accent,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                          color: VisualRefreshColors.anchor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      l10n.editAction,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: VisualRefreshColors.accent,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _VrStyleSegment(
                            style: style,
                            fullscreenLabel: l10n.reminderStyleFullscreen,
                            notificationLabel: l10n.reminderStyleNotification,
                            onChanged: (v) => setLocal(() => style = v),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in [
                                (1, l10n.weekdayMonShort),
                                (2, l10n.weekdayTueShort),
                                (3, l10n.weekdayWedShort),
                                (4, l10n.weekdayThuShort),
                                (5, l10n.weekdayFriShort),
                                (6, l10n.weekdaySatShort),
                                (7, l10n.weekdaySunShort),
                              ])
                                _VrDayChip(
                                  label: entry.$2,
                                  selected: days.contains(entry.$1),
                                  onSelected: (selected) {
                                    setLocal(() {
                                      if (selected) {
                                        days.add(entry.$1);
                                      } else if (days.length > 1) {
                                        days.remove(entry.$1);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      VisualRefreshColors.textSecondary,
                                ),
                                child: Text(
                                  l10n.cancel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: VisualRefreshColors.anchor,
                                    foregroundColor:
                                        VisualRefreshColors.background,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                    ),
                                  ),
                                  child: Text(
                                    editing
                                        ? l10n.reminderSaveChanges
                                        : l10n.save,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      } else {
        ok = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setLocal) {
                return AlertDialog(
                  title: Text(
                    editing ? l10n.reminderEditTitle : l10n.reminderCustomTitle,
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.reminderTitleFieldLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: bodyCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.reminderMessageFieldLabel,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.reminderTimeQuestion,
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: AppColors.mint.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final picked = await _pickReminderTime(
                                dialogContext: ctx,
                                l10n: l10n,
                                hour: hour,
                                minute: minute,
                                refresh: false,
                              );
                              if (picked != null) {
                                setLocal(() {
                                  hour = picked.hour;
                                  minute = picked.minute;
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: AppColors.tealDeep,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: AppColors.tealDeep,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.editAction,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.teal,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'fullscreen',
                              label: Text(l10n.reminderStyleFullscreen),
                              icon: const Icon(Icons.fullscreen),
                            ),
                            ButtonSegment(
                              value: 'notification',
                              label: Text(l10n.reminderStyleNotification),
                              icon: const Icon(Icons.notifications),
                            ),
                          ],
                          selected: {style},
                          onSelectionChanged: (s) =>
                              setLocal(() => style = s.first),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final entry in [
                              (1, l10n.weekdayMonShort),
                              (2, l10n.weekdayTueShort),
                              (3, l10n.weekdayWedShort),
                              (4, l10n.weekdayThuShort),
                              (5, l10n.weekdayFriShort),
                              (6, l10n.weekdaySatShort),
                              (7, l10n.weekdaySunShort),
                            ])
                              FilterChip(
                                label: Text(entry.$2),
                                selected: days.contains(entry.$1),
                                onSelected: (selected) {
                                  setLocal(() {
                                    if (selected) {
                                      days.add(entry.$1);
                                    } else if (days.length > 1) {
                                      days.remove(entry.$1);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                      ),
                      child: Text(
                        editing ? l10n.reminderSaveChanges : l10n.save,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      if (ok != true || !mounted) return;
      final title = titleCtrl.text.trim();
      final body = bodyCtrl.text.trim();
      if (title.isEmpty || body.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reminderTitleBodyRequired)),
        );
        return;
      }

      final payload = {
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'daysOfWeek': (days.toList()..sort()),
        'style': style,
        'enabled': existing?.enabled ?? true,
      };

      try {
        if (editing) {
          await ref.read(apiClientProvider).put(
                '/api/v1/reminders/${existing.id}',
                body: payload,
              );
        } else {
          await ref.read(apiClientProvider).post(
                '/api/v1/reminders/$childId',
                body: payload,
              );
        }
        if (!mounted) return;
        await _load(childId, force: true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).errorWithDetail('$e'),
            ),
          ),
        );
      }
    } finally {
      titleCtrl.dispose();
      bodyCtrl.dispose();
    }
  }

  InputDecoration _vrInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: VisualRefreshColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: VisualRefreshColors.accent,
          width: 1.2,
        ),
      ),
    );
  }

  Future<void> _toggleEnabled(ChildReminder item, bool enabled) async {
    final childId = _childId;
    // Optimistic UI — avoid blanking the list while PUT round-trips.
    final next = _items
        .map(
          (e) => e.id == item.id
              ? ChildReminder(
                  id: e.id,
                  childId: e.childId,
                  title: e.title,
                  body: e.body,
                  hour: e.hour,
                  minute: e.minute,
                  daysOfWeek: e.daysOfWeek,
                  style: e.style,
                  enabled: enabled,
                )
              : e,
        )
        .toList();
    setState(() => _items = next);
    if (childId != null) _putCache(childId, next);
    try {
      await ref.read(apiClientProvider).put(
        '/api/v1/reminders/${item.id}',
        body: {
          'title': item.title,
          'body': item.body,
          'hour': item.hour,
          'minute': item.minute,
          'daysOfWeek': item.daysOfWeek,
          'style': item.style,
          'enabled': enabled,
        },
      );
    } catch (e) {
      if (childId != null) unawaited(_load(childId, force: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _delete(ChildReminder item) async {
    final childId = _childId;
    final previous = List<ChildReminder>.from(_items);
    final next = _items.where((e) => e.id != item.id).toList();
    setState(() => _items = next);
    if (childId != null) _putCache(childId, next);
    try {
      await ref.read(apiClientProvider).delete('/api/v1/reminders/${item.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = previous);
      if (childId != null) _putCache(childId, previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).deleteFailedWithDetail('$e')),
        ),
      );
    }
  }

  String _daysLabel(AppLocalizations l10n, List<int> days) {
    if (days.length >= 7) return l10n.reminderEveryDay;
    final names = {
      1: l10n.weekdayMonShort,
      2: l10n.weekdayTueShort,
      3: l10n.weekdayWedShort,
      4: l10n.weekdayThuShort,
      5: l10n.weekdayFriShort,
      6: l10n.weekdaySatShort,
      7: l10n.weekdaySunShort,
    };
    return days.map((d) => names[d] ?? '$d').join(', ');
  }

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('tidur') || t.contains('istirahat')) {
      return Icons.bedtime_rounded;
    }
    if (t.contains('belajar')) return Icons.menu_book_rounded;
    return Icons.alarm_rounded;
  }

  Color _iconBgForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('tidur') || t.contains('istirahat')) {
      return const Color(0xFFDCEBFF);
    }
    if (t.contains('belajar')) return const Color(0xFFE8F6F1);
    return const Color(0xFFFFF0DC);
  }

  Color _iconFgForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('tidur') || t.contains('istirahat')) {
      return const Color(0xFF2563EB);
    }
    if (t.contains('belajar')) return AppColors.tealDeep;
    return const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider);
    final refresh = visualRefreshOf(context);
    if (_childId == null && children.items.isNotEmpty && !_childLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _childId == null) {
          unawaited(_hydrateGenders());
          unawaited(_load(children.items.first.id));
        }
      });
    }

    final activeCount = _items.where((e) => e.enabled).length;
    final sectionLabelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: refresh ? 1.1 : 0.8,
      color: refresh ? VisualRefreshColors.textSecondary : AppColors.inkSoft,
      fontFamily: refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
    );

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.remindersTitle,
              subtitle: l10n.reminderActiveCount(activeCount),
              showBack: Navigator.of(context).canPop(),
              titleStyle: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
              subtitleStyle: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: refresh ? VisualRefreshColors.accent : AppColors.teal,
                onRefresh: () async {
                  final id = _childId;
                  if (id != null) await _load(id, force: true);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: refresh
                            ? VisualRefreshColors.accentTint
                            : const Color(0xFFE8F6F1),
                        borderRadius: BorderRadius.circular(
                          refresh ? AppRadius.vrCard : 16,
                        ),
                        border: refresh
                            ? Border.all(
                                color: VisualRefreshColors.border,
                                width: 0.5,
                              )
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: refresh
                                ? VisualRefreshColors.accent
                                : AppColors.tealDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.reminderInfoBanner,
                              style: TextStyle(
                                color: refresh
                                    ? VisualRefreshColors.anchor
                                    : AppColors.tealDeep,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontSize: 13.5,
                                fontFamily: refresh
                                    ? GoogleFonts.plusJakartaSans().fontFamily
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (children.items.isEmpty) ...[
                      const SizedBox(height: 24),
                      PaEmptyState(
                        icon: Icons.child_care,
                        title: l10n.noChildrenTitle,
                        message: l10n.reminderNoChildrenMessage,
                      ),
                    ] else ...[
                      if (!_childLocked) ...[
                        const SizedBox(height: 18),
                        Text(l10n.sectionForChild, style: sectionLabelStyle),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: children.items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final child = children.items[index];
                              final selected = child.id ==
                                  (_childId ?? children.items.first.id);
                              final gender = _genders[child.id] ??
                                  ChildGenderStore.guessFromName(child.name);
                              return Material(
                                color: selected
                                    ? (refresh
                                        ? VisualRefreshColors.anchor
                                        : AppColors.tealDeep)
                                    : (refresh
                                        ? VisualRefreshColors.surface
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(999),
                                child: InkWell(
                                  onTap: () {
                                    if (child.id == _childId) return;
                                    unawaited(_load(child.id));
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      6,
                                      4,
                                      12,
                                      4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      border: selected
                                          ? null
                                          : Border.all(
                                              color: refresh
                                                  ? VisualRefreshColors.border
                                                  : const Color(0xFFE2E6EA),
                                            ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ChildAvatar(
                                          name: child.name,
                                          gender: gender,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          child.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: selected
                                                ? Colors.white
                                                : (refresh
                                                    ? VisualRefreshColors
                                                        .textPrimary
                                                    : AppColors.ink),
                                            fontFamily: refresh
                                                ? GoogleFonts.plusJakartaSans()
                                                    .fontFamily
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(l10n.sectionQuickAdd, style: sectionLabelStyle),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _QuickChip(
                              refresh: refresh,
                              icon: Icons.menu_book_rounded,
                              label: l10n.reminderStudyChipLabel,
                              onTap: () => _createPreset(
                                title: l10n.reminderStudyPresetTitle,
                                body: l10n.reminderStudyPresetBody,
                                hour: 19,
                                minute: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _QuickChip(
                              refresh: refresh,
                              icon: Icons.bedtime_rounded,
                              label: l10n.reminderSleepChipLabel,
                              onTap: () => _createPreset(
                                title: l10n.reminderSleepPresetTitle,
                                body: l10n.reminderSleepPresetBody,
                                hour: 21,
                                minute: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.reminderActiveScheduleTitle,
                              style: refresh
                                  ? GoogleFonts.fraunces(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: VisualRefreshColors.textPrimary,
                                    )
                                  : const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showCustomDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: refresh
                                  ? VisualRefreshColors.accent
                                  : AppColors.teal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.reminderAddShort,
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
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null && _items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDecoration(refresh),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                              TextButton(
                                onPressed: _childId == null
                                    ? null
                                    : () => _load(_childId!, force: true),
                                child: Text(l10n.retryAction),
                              ),
                            ],
                          ),
                        )
                      else if (_items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(refresh),
                          child: Text(
                            l10n.reminderEmptyMessage,
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
                        ..._items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReminderCard(
                              refresh: refresh,
                              item: item,
                              daysLabel: _daysLabel(l10n, item.daysOfWeek),
                              icon: _iconForTitle(item.title),
                              iconBg: _iconBgForTitle(item.title),
                              iconFg: _iconFgForTitle(item.title),
                              onToggle: (v) => _toggleEnabled(item, v),
                              onEdit: () =>
                                  unawaited(_showCustomDialog(existing: item)),
                              onDelete: () => unawaited(_delete(item)),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(bool refresh) => BoxDecoration(
      color: refresh ? VisualRefreshColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 18),
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
    );

class _VrFieldLabel extends StatelessWidget {
  const _VrFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: VisualRefreshColors.textSecondary,
      ),
    );
  }
}

class _VrStyleSegment extends StatelessWidget {
  const _VrStyleSegment({
    required this.style,
    required this.fullscreenLabel,
    required this.notificationLabel,
    required this.onChanged,
  });

  final String style;
  final String fullscreenLabel;
  final String notificationLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VisualRefreshColors.warmTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VisualRefreshColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VrSegChip(
              selected: style == 'fullscreen',
              icon: Icons.check_rounded,
              showCheck: true,
              label: fullscreenLabel,
              onTap: () => onChanged('fullscreen'),
            ),
          ),
          Expanded(
            child: _VrSegChip(
              selected: style == 'notification',
              icon: Icons.notifications_outlined,
              showCheck: false,
              label: notificationLabel,
              onTap: () => onChanged('notification'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VrSegChip extends StatelessWidget {
  const _VrSegChip({
    required this.selected,
    required this.icon,
    required this.showCheck,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final bool showCheck;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VisualRefreshColors.accentTint : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected && showCheck ? Icons.check_rounded : icon,
                size: 16,
                color: selected
                    ? VisualRefreshColors.accent
                    : VisualRefreshColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? VisualRefreshColors.anchor
                        : VisualRefreshColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VrDayChip extends StatelessWidget {
  const _VrDayChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VisualRefreshColors.accentTint : VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? VisualRefreshColors.accentTint
                  : VisualRefreshColors.border,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: VisualRefreshColors.accent,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected
                      ? VisualRefreshColors.anchor
                      : VisualRefreshColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.refresh = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: refresh ? VisualRefreshColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: refresh
                  ? VisualRefreshColors.border
                  : AppColors.teal.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: refresh
                    ? VisualRefreshColors.accent
                    : AppColors.tealDeep,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: refresh
                      ? VisualRefreshColors.anchor
                      : AppColors.tealDeep,
                  fontFamily:
                      refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.item,
    required this.daysLabel,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.refresh = false,
  });

  final ChildReminder item;
  final String daysLabel;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fullscreen = item.style == 'fullscreen';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: _cardDecoration(refresh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: refresh
                      ? iconBg.withValues(alpha: 0.85)
                      : iconBg,
                  borderRadius: BorderRadius.circular(
                    refresh ? AppRadius.vrChip : 14,
                  ),
                ),
                child: Icon(icon, color: iconFg, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.timeLabel} · ${item.title}',
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
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(
                          fullscreen
                              ? l10n.reminderStyleFullscreen
                              : l10n.reminderStyleNotification,
                          refresh: refresh,
                        ),
                        _Tag(daysLabel, refresh: refresh),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            decoration: BoxDecoration(
              color: refresh
                  ? VisualRefreshColors.warmTint
                  : const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _CardAction(
                  refresh: refresh,
                  icon: Icons.edit_outlined,
                  label: l10n.editAction,
                  onTap: onEdit,
                ),
                Container(
                  width: 1,
                  height: 22,
                  color: refresh
                      ? VisualRefreshColors.border
                      : const Color(0xFFE2E6EA),
                ),
                _CardAction(
                  refresh: refresh,
                  icon: Icons.delete_outline_rounded,
                  label: l10n.delete,
                  onTap: onDelete,
                  danger: true,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Switch.adaptive(
                    value: item.enabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: refresh
                        ? VisualRefreshColors.accent
                        : AppColors.teal,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: onToggle,
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

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.refresh = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? (refresh
            ? VisualRefreshColors.textSecondary
            : AppColors.inkSoft)
        : (refresh ? VisualRefreshColors.anchor : AppColors.tealDeep);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.refresh = false});

  final String label;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.tagMuted : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: refresh
              ? VisualRefreshColors.textSecondary
              : AppColors.inkSoft,
          fontFamily:
              refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
        ),
      ),
    );
  }
}
