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
    required this.blockedCount,
  });

  final String packageName;
  final String label;
  final int durationSeconds;
  final int blockedCount;
}

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen> {
  String? _childId;
  double _limit = 120;
  bool _enabled = true;
  bool _saving = false;
  bool _loading = false;
  final Set<String> _blocked = {};
  List<_UsageAppRow> _apps = [];

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
              blockedCount: (item['blocked_count'] as num?)?.toInt() ?? 0,
            );
          })
          .where((a) => a.packageName.isNotEmpty)
          .toList();

      // Keep blocked apps visible even if no usage today.
      for (final pkg in blocked) {
        if (apps.every((a) => a.packageName != pkg)) {
          apps.add(
            _UsageAppRow(
              packageName: pkg,
              label: friendlyAppName(pkg),
              durationSeconds: 0,
              blockedCount: 0,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        if (current != null) {
          _enabled = current['enabled'] == true;
          _limit = (current['daily_limit_minutes'] as num?)?.toDouble() ?? 120;
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
          'dailyLimitMinutes': _limit.round(),
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
        const SnackBar(
          content: Text(
            'Aturan dikirim. HP anak akan menerapkan saat app dibuka / resume.',
          ),
        ),
      );
      await _load(childId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menerapkan aturan: $e')),
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
    final usedSeconds = _apps.fold<int>(0, (sum, a) => sum + a.durationSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waktu layar'),
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
              decoration: const InputDecoration(labelText: 'Pilih anak'),
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
          PaSectionCard(
            color: AppColors.sky.withValues(alpha: 0.12),
            child: const Text(
              'Terapkan aturan mengirim batas waktu harian dan daftar aplikasi '
              'yang diblokir ke HP anak. Blokir bekerja jika aksesibilitas '
              'PulangAman aktif di perangkat anak.',
              style: TextStyle(color: AppColors.inkSoft, height: 1.35),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PaSectionCard(
            color: AppColors.lavender.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timelapse, color: AppColors.tealDeep, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${(usedSeconds / 60).round()} dari ${_limit.round()} menit',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
                Slider(
                  value: _limit,
                  min: 15,
                  max: 360,
                  divisions: 23,
                  label: '${_limit.round()} menit',
                  onChanged: (value) => setState(() => _limit = value),
                ),
                const Text(
                  'PulangAman, Telepon, Pesan, dan panggilan darurat selalu diizinkan.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Aplikasi di HP anak',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              if (_blocked.isNotEmpty)
                Text(
                  '${_blocked.length} diblokir',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Nyahkan saklar untuk memblokir. Lalu tekan Terapkan aturan.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_apps.isEmpty)
            PaSectionCard(
              color: AppColors.sand.withValues(alpha: 0.5),
              child: const Text(
                'Belum ada data pemakaian dari HP anak.\n'
                'Buka PulangAman di HP anak (izin Usage Access aktif) '
                'agar daftar aplikasi muncul di sini.',
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
                                  : formatDuration(app.durationSeconds),
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
                            blocked ? 'Blokir' : 'Izinkan',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: blocked ? AppColors.coral : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _childId == null || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shield),
            label: Text(_saving ? 'Mengirim...' : 'Terapkan aturan'),
          ),
        ],
      ),
    );
  }
}
