import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../parent/children_controller.dart';

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen> {
  String? _childId;
  double _limit = 120;
  bool _enabled = true;
  final _packages = TextEditingController(text: 'com.google.android.youtube\ncom.instagram.android');
  List<Map<String, dynamic>> _summary = [];

  @override
  void dispose() {
    _packages.dispose();
    super.dispose();
  }

  Future<void> _load(String childId) async {
    _childId = childId;
    try {
      final policy = await ref.read(apiClientProvider).get('/api/v1/policies/$childId');
      final current = policy['policy'] as Map<String, dynamic>?;
      final summary = await ref.read(apiClientProvider).get('/api/v1/telemetry/$childId/summary');
      setState(() {
        if (current != null) {
          _enabled = current['enabled'] == true;
          _limit = (current['daily_limit_minutes'] as num?)?.toDouble() ?? 120;
          final blocked = (current['blocked_packages'] as List<dynamic>? ?? []).join('\n');
          if (blocked.isNotEmpty) _packages.text = blocked;
        }
        _summary = (summary['apps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final childId = _childId;
    if (childId == null) return;
    await ref.read(apiClientProvider).put(
      '/api/v1/policies/$childId',
      body: {
        'enabled': _enabled,
        'dailyLimitMinutes': _limit.round(),
        'blockedPackages': _packages.text
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aturan dikirim ke perangkat anak')),
      );
    }
    await _load(childId);
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    if (_childId == null && children.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _childId == null) _load(children.items.first.id);
      });
    }
    final usedSeconds = _summary.fold<int>(
      0,
      (sum, item) => sum + ((item['duration_seconds'] as num?)?.toInt() ?? 0),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Waktu layar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (children.items.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _childId ?? children.items.first.id,
              decoration: const InputDecoration(labelText: 'Pilih anak'),
              items: children.items
                  .map((child) => DropdownMenuItem(value: child.id, child: Text(child.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _load(value);
              },
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
                    Switch(value: _enabled, onChanged: (value) => setState(() => _enabled = value)),
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
                const Text('PulangAman, Telepon, Pesan, dan panggilan darurat selalu diizinkan.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _packages,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Package aplikasi yang dibatasi',
              helperText: 'Satu package per baris',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _childId == null ? null : _save,
            icon: const Icon(Icons.shield),
            label: const Text('Terapkan aturan'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Pemakaian hari ini', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              )),
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Belum ada telemetry dari perangkat anak.'),
            )
          else
            ..._summary.map((item) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apps)),
                  title: Text('${item['package_name'] ?? 'Unknown'}'),
                  subtitle: Text('${((item['duration_seconds'] as num?) ?? 0) ~/ 60} menit'),
                  trailing: Text('${item['blocked_count']} diblokir'),
                )),
        ],
      ),
    );
  }
}
