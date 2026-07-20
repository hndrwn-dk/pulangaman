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
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ketuk untuk buka jam putar (lebih mudah dari angka).',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat jadwal')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PaSectionCard(
            color: AppColors.sky.withValues(alpha: 0.12),
            child: const Text(
              'Buat pengingat supaya HP anak menampilkan pesan besar di jam tertentu '
              '(misalnya belajar jam 7 malam, tidur jam 9 malam). '
              'Anak cukup tekan Mengerti untuk menutup.',
              style: TextStyle(color: AppColors.inkSoft, height: 1.35, fontSize: 15),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (children.items.isEmpty)
            const PaEmptyState(
              icon: Icons.child_care,
              title: 'Belum ada anak',
              message: 'Hubungkan anak dulu sebelum membuat pengingat.',
            )
          else ...[
            Text(
              'Untuk anak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final child = children.items[index];
                  final selected = child.id == (_childId ?? children.items.first.id);
                  final gender = _genders[child.id] ??
                      ChildGenderStore.guessFromName(child.name);
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (child.id == _childId) return;
                      unawaited(_load(child.id));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 88,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.mint.withValues(alpha: 0.45)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppColors.teal : const Color(0x22075A4F),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChildAvatar(
                            name: child.name,
                            gender: gender,
                            size: 48,
                            selected: selected,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            child.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: selected ? AppColors.tealDeep : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tambah cepat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _createPreset(
                    title: 'Waktunya belajar',
                    body: 'Sekarang jam belajar. Matikan game dulu ya.',
                    hour: 19,
                    minute: 0,
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Belajar 19:00'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _createPreset(
                    title: 'Waktunya tidur',
                    body: 'Sudah malam. Waktunya istirahat agar besok semangat.',
                    hour: 21,
                    minute: 0,
                  ),
                  icon: const Icon(Icons.bedtime_rounded),
                  label: const Text('Tidur 21:00'),
                ),
                OutlinedButton.icon(
                  onPressed: _showCustomDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Kustom'),
                ),
                OutlinedButton.icon(
                  onPressed: _createTestInOneMinute,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Coba 1 menit lagi'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Jadwal aktif',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _items.isEmpty)
              PaSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 10),
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
              const PaSectionCard(
                child: Text(
                  'Belum ada pengingat. Pakai tombol cepat di atas.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              )
            else
              ..._items.map((item) {
                final fullscreen = item.style == 'fullscreen';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: fullscreen
                          ? AppColors.coral.withValues(alpha: 0.15)
                          : AppColors.mint,
                      child: Icon(
                        fullscreen
                            ? Icons.fullscreen_rounded
                            : Icons.notifications_active_rounded,
                        color: fullscreen ? AppColors.coral : AppColors.teal,
                      ),
                    ),
                    title: Text(
                      '${item.timeLabel} · ${item.title}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${item.body}\n'
                      '${fullscreen ? 'Layar penuh' : 'Notifikasi'} · '
                      '${item.daysOfWeek.length == 7 ? 'Setiap hari' : '${item.daysOfWeek.length} hari'}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.enabled,
                          onChanged: (v) => _toggleEnabled(item, v),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          onPressed: () => _delete(item),
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
