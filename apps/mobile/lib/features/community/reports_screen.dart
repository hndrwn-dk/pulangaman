import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/reports');
      setState(() {
        _reports = (data['reports'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addReport() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}

    final noteCtrl = TextEditingController();
    String category = 'hazard';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Laporan komunitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                items: const [
                  DropdownMenuItem(value: 'hazard', child: Text('Bahaya')),
                  DropdownMenuItem(value: 'traffic', child: Text('Lalu lintas')),
                  DropdownMenuItem(value: 'crowd', child: Text('Kerumunan')),
                  DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                ],
                onChanged: (v) => setLocal(() => category = v ?? 'hazard'),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.save)),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/reports', body: {
      'category': category,
      'note': noteCtrl.text.trim(),
      'lat': pos?.latitude ?? -6.2,
      'lng': pos?.longitude ?? 106.816,
    });
    await _load();
  }

  Future<void> _verify(String id) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/reports/$id/verify');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan komunitas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReport,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Tambah pin'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Pin kadaluarsa 72 jam kecuali diverifikasi. Tidak ada marketplace orang asing.',
                  ),
                  const SizedBox(height: 12),
                  if (_reports.isEmpty)
                    const Text('Belum ada laporan aktif')
                  else
                    ..._reports.map(
                      (r) => ListTile(
                        title: Text('${r['category']} · ${r['status']}'),
                        subtitle: Text(
                          '${r['note'] ?? '-'} @ ${r['lat']}, ${r['lng']}\n'
                          'kedaluwarsa: ${r['expires_at']}',
                        ),
                        isThreeLine: true,
                        trailing: r['status'] == 'verified'
                            ? const Icon(Icons.verified, color: AppColors.teal)
                            : IconButton(
                                icon: const Icon(Icons.verified_outlined),
                                onPressed: () => _verify(r['id'] as String),
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
