import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
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

  Future<void> _load(String childId) async {
    setState(() {
      _childId = childId;
      _loading = true;
    });
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/reminders/$childId');
      final list = (data['reminders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildReminder.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
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
        SnackBar(content: Text('Pengingat "$title" dikirim ke anak')),
      );
      await _load(childId);
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
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: hour,
                            decoration: const InputDecoration(labelText: 'Jam'),
                            items: List.generate(
                              24,
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(i.toString().padLeft(2, '0')),
                              ),
                            ),
                            onChanged: (v) => setLocal(() => hour = v ?? hour),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: minute,
                            decoration: const InputDecoration(labelText: 'Menit'),
                            items: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m.toString().padLeft(2, '0')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setLocal(() => minute = v ?? minute),
                          ),
                        ),
                      ],
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
      await _load(childId);
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
      if (_childId != null) await _load(_childId!);
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
      if (_childId != null) await _load(_childId!);
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
        if (mounted && _childId == null) _load(children.items.first.id);
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
              'Atur jam belajar, tidur, atau pesan lain. Di jam tersebut '
              'HP anak menampilkan layar penuh (atau notifikasi) seperti siaran keluarga.',
              style: TextStyle(color: AppColors.inkSoft, height: 1.35),
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
            DropdownButtonFormField<String>(
              initialValue: _childId ?? children.items.first.id,
              decoration: const InputDecoration(labelText: 'Pilih anak'),
              items: children.items
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) _load(v);
              },
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
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Tes +1 mnt'),
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
              const Center(child: CircularProgressIndicator())
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
