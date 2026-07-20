import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../parent/children_controller.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  String? _childId;
  Map<String, dynamic> _balance = {};
  List<Map<String, dynamic>> _ledger = [];

  Future<void> _load(String childId) async {
    _childId = childId;
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/rewards/$childId');
      setState(() {
        _balance = (data['balance'] as Map<String, dynamic>?) ?? {};
        _ledger = (data['ledger'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _bonus() async {
    final childId = _childId;
    if (childId == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berikan bonus'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Alasan positif'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tambah 5')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(apiClientProvider).post(
      '/api/v1/rewards/$childId/adjust',
      body: {'delta': 5, 'reason': controller.text.trim().isEmpty ? 'Bonus orang tua' : controller.text.trim()},
    );
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
    final points = _balance['points'] ?? 0;
    final streak = _balance['current_streak'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Hadiah')),
      floatingActionButton: _childId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _bonus,
              backgroundColor: AppColors.coral,
              icon: const Icon(Icons.favorite),
              label: const Text('Kasih pujian (+5)'),
            ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text(
            'Poin dikumpulkan saat anak tiba di sekolah tepat waktu. '
            'Bisa juga ditambah manual sebagai pujian.',
            style: TextStyle(color: AppColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          if (children.items.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _childId ?? children.items.first.id,
              decoration: const InputDecoration(labelText: 'Lihat anak'),
              items: children.items
                  .map((child) => DropdownMenuItem(value: child.id, child: Text(child.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _load(value);
              },
            ),
          const SizedBox(height: AppSpacing.md),
          PaSectionCard(
            color: AppColors.amber.withValues(alpha: 0.22),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$points',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total poin anak',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        streak == 0
                            ? 'Belum ada streak harian'
                            : 'Rajin $streak hari berturut-turut',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Contoh: tiba di sekolah +10 poin',
                        style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Riwayat poin',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          if (_ledger.isEmpty)
            const Text(
              'Belum ada poin. Setelah anak check-in sekolah, poin muncul di sini.',
              style: TextStyle(color: AppColors.inkSoft),
            )
          else
            ..._ledger.map((item) {
              final raw = item['created_at']?.toString();
              final at = raw == null ? null : DateTime.tryParse(raw);
              final when = at == null
                  ? (raw ?? '')
                  : '${at.toLocal().day}/${at.toLocal().month} '
                      '${at.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${at.toLocal().minute.toString().padLeft(2, '0')}';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Text(
                    '+${item['delta']}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                title: Text('${item['reason']}'),
                subtitle: Text(when),
              );
            }),
        ],
      ),
    );
  }
}
