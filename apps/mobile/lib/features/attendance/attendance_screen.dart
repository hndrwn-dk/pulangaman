import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../parent/children_controller.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _selectedChildId;
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;

  Future<void> _load(String childId) async {
    setState(() {
      _selectedChildId = childId;
      _loading = true;
    });
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/attendance',
        query: {'childId': childId, 'date': date},
      );
      setState(() {
        _events = (data['events'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    if (_selectedChildId == null && children.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedChildId == null) _load(children.items.first.id);
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sekolah')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Apakah anak sudah di sekolah?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Catatan masuk/pulang muncul otomatis saat anak sampai di area sekolah. '
            'Anak tidak perlu menekan apa pun.',
            style: TextStyle(color: AppColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          if (children.items.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedChildId ?? children.items.first.id,
              decoration: const InputDecoration(labelText: 'Lihat anak'),
              items: children.items
                  .map((child) => DropdownMenuItem(
                        value: child.id,
                        child: Text(child.name),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _load(value);
              },
            ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_events.isEmpty)
            const PaEmptyState(
              icon: Icons.school_outlined,
              title: 'Belum ada catatan hari ini',
              message:
                  'Kalau zona sekolah sudah diatur dan lokasi anak aktif, '
                  'catatan tiba/pulang akan muncul di sini.',
            )
          else
            ..._events.map((event) {
              final checkIn = event['event_type'] == 'check_in';
              final raw = event['recorded_at']?.toString();
              final at = raw == null ? null : DateTime.tryParse(raw);
              final timeLabel = at == null
                  ? (raw ?? '')
                  : '${at.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${at.toLocal().minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PaSectionCard(
                  color: (checkIn ? AppColors.mint : AppColors.sky)
                      .withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: checkIn ? AppColors.success : AppColors.sky,
                        child: Icon(
                          checkIn ? Icons.login : Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkIn ? 'Sudah tiba di sekolah' : 'Sudah pulang sekolah',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text('${event['school_name']} · jam $timeLabel'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
