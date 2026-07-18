import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../community/reports_screen.dart';
import '../community/safe_route_screen.dart';
import 'children_controller.dart';
import 'live_map_screen.dart';
import 'zones_screen.dart';
import 'guardians_screen.dart';

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(childrenControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.brand} · ${auth.name ?? ''}'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(childrenControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(AppStrings.childrenTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (children.loading)
              const Center(child: CircularProgressIndicator())
            else if (children.items.isEmpty)
              Text(AppStrings.noChildren)
            else
              ...children.items.map((child) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(child.name),
                    subtitle: Text(
                      child.lastSeenAt == null
                          ? 'Belum ada lokasi'
                          : 'Terakhir terlihat: ${child.lastSeenAt}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LiveMapScreen(child: child),
                        ),
                      );
                    },
                  ),
                );
              }),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showAddChild(context),
              icon: const Icon(Icons.person_add),
              label: const Text(AppStrings.addChild),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddChild(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+62813');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.addChild),
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(childrenControllerProvider.notifier).addChild(
            name: nameCtrl.text,
            phone: phoneCtrl.text,
          );
    }
  }
}

class ParentShell extends ConsumerWidget {
  const ParentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: const TabBarView(
          children: [
            ParentHomeScreen(),
            ZonesEntryScreen(),
            GuardiansEntryScreen(),
            ReportsScreen(),
            SafeRouteScreen(),
          ],
        ),
        bottomNavigationBar: const TabBar(
          isScrollable: true,
          labelColor: AppColors.tealDeep,
          tabs: [
            Tab(icon: Icon(Icons.family_restroom), text: 'Anak'),
            Tab(icon: Icon(Icons.fence), text: 'Zona'),
            Tab(icon: Icon(Icons.shield), text: 'Wali'),
            Tab(icon: Icon(Icons.report), text: 'Lapor'),
            Tab(icon: Icon(Icons.route), text: 'Rute'),
          ],
        ),
      ),
    );
  }
}
