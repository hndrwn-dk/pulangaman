import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class ZonesEntryScreen extends ConsumerWidget {
  const ZonesEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.zonesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (children.items.isEmpty)
            const Text(AppStrings.noChildren)
          else
            ...children.items.map(
              (child) => ListTile(
                title: Text(child.name),
                subtitle: const Text('Atur zona Rumah / Sekolah'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ZonesScreen(child: child),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ZonesScreen extends ConsumerStatefulWidget {
  const ZonesScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends ConsumerState<ZonesScreen> {
  List<Map<String, dynamic>> _zones = [];
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
      final data = await api.get('/api/v1/zones', query: {
        'childId': widget.child.id,
      });
      setState(() {
        _zones = (data['zones'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addZone(String type) async {
    final latCtrl = TextEditingController(text: '-6.200');
    final lngCtrl = TextEditingController(text: '106.816');
    final radiusCtrl = TextEditingController(text: '150');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'home' ? AppStrings.homeZone : AppStrings.schoolZone),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude')),
            TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Longitude')),
            TextField(
              controller: radiusCtrl,
              decoration: const InputDecoration(labelText: 'Radius (m)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.save)),
        ],
      ),
    );
    if (ok != true) return;

    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/zones', body: {
      'childId': widget.child.id,
      'type': type,
      'lat': double.parse(latCtrl.text),
      'lng': double.parse(lngCtrl.text),
      'radiusM': int.parse(radiusCtrl.text),
      'name': type == 'home' ? AppStrings.homeZone : AppStrings.schoolZone,
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${AppStrings.zonesTitle} · ${widget.child.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._zones.map(
                  (z) => ListTile(
                    title: Text('${z['type']} · ${z['name'] ?? '-'}'),
                    subtitle: Text(
                      'r=${z['radius_m']}m @ ${z['lat']}, ${z['lng']}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _addZone('home'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  child: Text('Tambah ${AppStrings.homeZone}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _addZone('school'),
                  child: Text('Tambah ${AppStrings.schoolZone}'),
                ),
              ],
            ),
    );
  }
}
