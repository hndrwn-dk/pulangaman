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

/// Preset batas yang mudah dipilih ortu (bukan slider teknis).
const _limitPresets = <({int minutes, String label})>[
  (minutes: 30, label: '30 menit'),
  (minutes: 60, label: '1 jam'),
  (minutes: 90, label: '1,5 jam'),
  (minutes: 120, label: '2 jam'),
  (minutes: 180, label: '3 jam'),
];

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen> {
  String? _childId;
  int _limitMinutes = 120;
  bool _enabled = true;
  bool _saving = false;
  bool _loading = false;
  final Set<String> _blocked = {};
  List<_UsageAppRow> _apps = [];

  String get _childName {
    final children = ref.read(childrenControllerProvider).items;
    for (final c in children) {
      if (c.id == _childId) return c.name;
    }
    return 'anak';
  }

  Future<void> _load(String childId) async {
    _childId = childId;
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
        if (current != null) {
          _enabled = current['enabled'] == true;
          _limitMinutes =
              (current['daily_limit_minutes'] as num?)?.toInt() ?? 120;
        }
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

  Future<void> _save() async {
    final childId = _childId;
    if (childId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put(
        '/api/v1/policies/$childId',
        body: {
          'enabled': _enabled,
          'dailyLimitMinutes': _limitMinutes,
          'blockedPackages': _blocked.toList()..sort(),
          'schedules': [
            {
              'days': [1, 2, 3, 4, 5],
              'start': '07:00',
              'end': '14:00',
            }
          ],
          'emergencyAllowlist': const <String>[],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled
                ? 'Aturan tersimpan. Buka PulangAman di HP $_childName supaya aktif.'
                : 'Batas waktu dimatikan untuk $_childName.',
          ),
        ),
      );
      await _load(childId);
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

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    if (_childId == null && children.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _childId == null) _load(children.items.first.id);
      });
    }

    final usedMinutes =
        (_apps.fold<int>(0, (sum, a) => sum + a.durationSeconds) / 60).round();
    final over = usedMinutes > _limitMinutes;
    final remaining = (_limitMinutes - usedMinutes).clamp(0, _limitMinutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batas main HP'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _childId == null ? null : () => _load(_childId!),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (children.items.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _childId ?? children.items.first.id,
              decoration: const InputDecoration(
                labelText: 'Aturan untuk anak',
              ),
              items: children.items
                  .map(
                    (child) => DropdownMenuItem(
                      value: child.id,
                      child: Text(child.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _load(value);
              },
            ),
          const SizedBox(height: AppSpacing.md),

          // Status pemakaian — bahasa orang tua, bukan "X dari Y"
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: !_enabled
                  ? AppColors.inkSoft.withValues(alpha: 0.08)
                  : over
                      ? AppColors.coral.withValues(alpha: 0.12)
                      : AppColors.mint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      !_enabled
                          ? Icons.pause_circle_filled
                          : over
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                      color: !_enabled
                          ? AppColors.inkSoft
                          : over
                              ? AppColors.coral
                              : AppColors.success,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !_enabled
                            ? 'Batas waktu sedang dimatikan'
                            : over
                                ? 'Sudah lewat batas hari ini'
                                : 'Masih dalam batas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Sudah dipakai: ${formatDuration(usedMinutes * 60)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !_enabled
                      ? 'Anak bisa main HP tanpa batas dari PulangAman.'
                      : over
                          ? 'Batas kamu: $_limitMinutes menit. '
                              'Kelebihan ${usedMinutes - _limitMinutes} menit '
                              '(app yang diblokir akan ditahan).'
                          : 'Batas kamu: $_limitMinutes menit. '
                              'Sisa sekitar $remaining menit.',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text(
            '1. Nyalakan batas waktu?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          PaSectionCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _enabled ? 'Ya, batasi main HP' : 'Tidak, bebas dulu',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _enabled
                    ? 'Setelah lewat batas, app yang kamu blokir akan ditahan.'
                    : 'Matikan hanya jika ingin anak main tanpa batas sementara.',
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text(
            '2. Berapa lama boleh main per hari?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih salah satu. Mudah diubah kapan saja.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _limitPresets)
                ChoiceChip(
                  label: Text(
                    preset.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _limitMinutes == preset.minutes
                          ? Colors.white
                          : AppColors.ink,
                    ),
                  ),
                  selected: _limitMinutes == preset.minutes,
                  selectedColor: AppColors.teal,
                  onSelected: _enabled
                      ? (_) => setState(() => _limitMinutes = preset.minutes)
                      : null,
                ),
            ],
          ),
          if (!_limitPresets.any((p) => p.minutes == _limitMinutes)) ...[
            const SizedBox(height: 8),
            Text(
              'Batas saat ini: $_limitMinutes menit (dari pengaturan lama)',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text(
            '3. App mana yang mau ditahan?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Geser ke "Tahan" untuk app yang tidak boleh dipakai berlebihan '
            '(misalnya YouTube, game). Telepon & pesan tetap boleh.',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_apps.isEmpty)
            PaSectionCard(
              color: AppColors.sand.withValues(alpha: 0.55),
              child: const Text(
                'Daftar app belum muncul.\n\n'
                'Minta anak buka PulangAman di HP-nya sekali, '
                'lalu di sini tekan ikon segarkan di pojok kanan atas.',
                style: TextStyle(color: AppColors.inkSoft, height: 1.4),
              ),
            )
          else
            ..._apps.map((app) {
              final blocked = _blocked.contains(app.packageName);
              final accent = appAccentForPackage(app.packageName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: blocked
                        ? AppColors.coral.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: blocked
                          ? AppColors.coral.withValues(alpha: 0.35)
                          : const Color(0x14075A4F),
                    ),
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
                              style: const TextStyle(fontWeight: FontWeight.w800),
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
                      Column(
                        children: [
                          Switch(
                            value: blocked,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.coral,
                            onChanged: (value) =>
                                _toggleBlock(app.packageName, value),
                          ),
                          Text(
                            blocked ? 'Tahan' : 'Boleh',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color:
                                  blocked ? AppColors.coral : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _childId == null || _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.teal,
            ),
            child: Text(
              _saving ? 'Menyimpan...' : 'Simpan aturan ke HP anak',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Setelah simpan, buka sebentar PulangAman di HP anak supaya aturan aktif.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
