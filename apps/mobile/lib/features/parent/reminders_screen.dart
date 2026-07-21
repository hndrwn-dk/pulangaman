import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
import 'children_controller.dart';

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
  const RemindersScreen({super.key});

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
  static const _timeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    Future.microtask(_hydrateGenders);
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
    final showSpinner = _childId != childId || _items.isEmpty;
    setState(() {
      _childId = childId;
      _loading = showSpinner;
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
          _error = 'Gagal memuat jadwal. Periksa koneksi, lalu coba lagi.';
        }
      });
    }
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
            'Pengingat "$title" disimpan.\n'
            'Buka PulangAman di HP anak supaya jadwal aktif. '
            'Untuk uji cepat, tekan "Coba 1 menit lagi".',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      await _load(childId, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _showCustomDialog() async {
    final childId = _childId;
    if (childId == null) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var hour = 19;
    var minute = 0;
    var style = 'fullscreen';
    final days = {1, 2, 3, 4, 5, 6, 7};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Pengingat kustom'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Judul'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bodyCtrl,
                      decoration: const InputDecoration(labelText: 'Pesan'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Jam berapa?',
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
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(hour: hour, minute: minute),
                            initialEntryMode: TimePickerEntryMode.dial,
                            helpText: 'Pilih jam pengingat',
                            cancelText: 'Batal',
                            confirmText: 'Pakai jam ini',
                            hourLabelText: 'Jam',
                            minuteLabelText: 'Menit',
                            builder: (context, child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  alwaysUse24HourFormat: true,
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    timePickerTheme: TimePickerThemeData(
                                      dialHandColor: AppColors.teal,
                                      dialBackgroundColor: AppColors.mint
                                          .withValues(alpha: 0.35),
                                      hourMinuteColor: AppColors.teal
                                          .withValues(alpha: 0.12),
                                      hourMinuteTextColor: AppColors.tealDeep,
                                      dayPeriodColor: AppColors.mint,
                                      helpTextStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    colorScheme: Theme.of(context)
                                        .colorScheme
                                        .copyWith(primary: AppColors.teal),
                                  ),
                                  child: child!,
                                ),
                              );
                            },
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
                              const Text(
                                'Ubah',
                                style: TextStyle(
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
                      segments: const [
                        ButtonSegment(
                          value: 'fullscreen',
                          label: Text('Layar penuh'),
                          icon: Icon(Icons.fullscreen),
                        ),
                        ButtonSegment(
                          value: 'notification',
                          label: Text('Notifikasi'),
                          icon: Icon(Icons.notifications),
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
                        for (final entry in const [
                          (1, 'Sen'),
                          (2, 'Sel'),
                          (3, 'Rab'),
                          (4, 'Kam'),
                          (5, 'Jum'),
                          (6, 'Sab'),
                          (7, 'Min'),
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
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan pesan wajib diisi')),
      );
      return;
    }

    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/reminders/$childId',
        body: {
          'title': titleCtrl.text.trim(),
          'body': bodyCtrl.text.trim(),
          'hour': hour,
          'minute': minute,
          'daysOfWeek': days.toList()..sort(),
          'style': style,
          'enabled': true,
        },
      );
      await _load(childId, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _toggleEnabled(ChildReminder item, bool enabled) async {
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
      if (_childId != null) await _load(_childId!, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _delete(ChildReminder item) async {
    try {
      await ref.read(apiClientProvider).delete('/api/v1/reminders/${item.id}');
      if (_childId != null) await _load(_childId!, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

  Future<void> _createTestInOneMinute() async {
    final childId = _childId;
    if (childId == null) return;
    final now = DateTime.now().add(const Duration(minutes: 1));
    await _createPreset(
      title: 'Tes pengingat',
      body: 'Ini tes layar penuh dari orang tua. Ketuk Mengerti untuk menutup.',
      hour: now.hour,
      minute: now.minute,
    );
  }

  String _daysLabel(List<int> days) {
    if (days.length >= 7) return 'Setiap hari';
    const names = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
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
    final children = ref.watch(childrenControllerProvider);
    if (_childId == null && children.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _childId == null) {
          unawaited(_hydrateGenders());
          unawaited(_load(children.items.first.id));
        }
      });
    }

    final activeCount = _items.where((e) => e.enabled).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengingat Jadwal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$activeCount pengingat aktif',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
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
                        color: const Color(0xFFE8F6F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppColors.tealDeep,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'HP anak akan menampilkan pesan besar di jam tertentu. '
                              'Anak cukup tekan “Mengerti” untuk menutup.',
                              style: TextStyle(
                                color: AppColors.tealDeep,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (children.items.isEmpty) ...[
                      const SizedBox(height: 24),
                      const PaEmptyState(
                        icon: Icons.child_care,
                        title: 'Belum ada anak',
                        message:
                            'Hubungkan anak dulu sebelum membuat pengingat.',
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      const Text(
                        'UNTUK ANAK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.inkSoft,
                        ),
                      ),
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
                                  ? AppColors.tealDeep
                                  : Colors.white,
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
                                            color: const Color(0xFFE2E6EA),
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
                                              : AppColors.ink,
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
                      const SizedBox(height: 18),
                      const Text(
                        'TAMBAH CEPAT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _QuickChip(
                              icon: Icons.menu_book_rounded,
                              label: 'Belajar 19:00',
                              onTap: () => _createPreset(
                                title: 'Waktunya Belajar',
                                body:
                                    'Sekarang jam belajar. Matikan game dulu ya.',
                                hour: 19,
                                minute: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _QuickChip(
                              icon: Icons.bedtime_rounded,
                              label: 'Tidur 21:00',
                              onTap: () => _createPreset(
                                title: 'Waktunya Tidur',
                                body:
                                    'Sudah malam. Waktunya istirahat agar besok semangat.',
                                hour: 21,
                                minute: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: _showCustomDialog,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E6EA),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Jadwal Aktif',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showCustomDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '+ Tambah',
                              style: TextStyle(fontWeight: FontWeight.w800),
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
                          decoration: _cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                              TextButton(
                                onPressed: _childId == null
                                    ? null
                                    : () => _load(_childId!, force: true),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        )
                      else if (_items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration,
                          child: const Text(
                            'Belum ada pengingat. Pakai tambah cepat di atas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ..._items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReminderCard(
                              item: item,
                              daysLabel: _daysLabel(item.daysOfWeek),
                              icon: _iconForTitle(item.title),
                              iconBg: _iconBgForTitle(item.title),
                              iconFg: _iconFgForTitle(item.title),
                              onToggle: (v) => _toggleEnabled(item, v),
                              onDelete: () => _delete(item),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _createTestInOneMinute,
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Coba 1 menit lagi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.tealDeep,
                          side: const BorderSide(color: Color(0xFFE2E6EA)),
                          backgroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
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

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ],
);

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.tealDeep),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.tealDeep,
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
    required this.onDelete,
  });

  final ChildReminder item;
  final String daysLabel;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fullscreen = item.style == 'fullscreen';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(fullscreen ? 'Layar penuh' : 'Notifikasi'),
                    _Tag(daysLabel),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              Switch(
                value: item.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.teal,
                onChanged: onToggle,
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}
