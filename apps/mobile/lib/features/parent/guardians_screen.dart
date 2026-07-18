import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class GuardiansEntryScreen extends ConsumerWidget {
  const GuardiansEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.guardiansTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Undang wali yang sudah dikenal. Tidak ada pencarian orang asing.',
          ),
          const SizedBox(height: 12),
          if (children.items.isEmpty)
            const Text(AppStrings.noChildren)
          else
            ...children.items.map(
              (child) => ListTile(
                title: Text(child.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuardiansScreen(child: child),
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

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  List<Map<String, dynamic>> _guardians = [];
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
      final data = await api.get('/api/v1/guardians', query: {
        'childId': widget.child.id,
      });
      setState(() {
        _guardians = (data['guardians'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+62814');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.inviteGuardian),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: AppStrings.nameLabel),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: AppStrings.phoneLabel),
              keyboardType: TextInputType.phone,
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
    await api.post('/api/v1/guardians/invite', body: {
      'childId': widget.child.id,
      'guardianName': nameCtrl.text.trim(),
      'guardianPhone': phoneCtrl.text.trim(),
    });
    await _load();
  }

  Future<void> _revoke(String guardianId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/revoke', body: {
      'childId': widget.child.id,
      'guardianId': guardianId,
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${AppStrings.guardiansTitle} · ${widget.child.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.person_add),
        label: const Text(AppStrings.inviteGuardian),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _guardians
                  .map(
                    (g) => ListTile(
                      title: Text('${g['name']}'),
                      subtitle: Text('${g['phone']} · ${g['status']}'),
                      trailing: g['status'] == 'revoked'
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.block, color: AppColors.danger),
                              onPressed: () => _revoke(g['guardian_id'] as String),
                            ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
