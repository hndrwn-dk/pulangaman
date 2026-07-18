import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../attendance/attendance_screen.dart';
import '../auth/auth_controller.dart';
import '../rewards/rewards_screen.dart';
import '../screentime/screen_time_screen.dart';
import 'children_controller.dart';
import 'live_map_screen.dart';
import 'more_screen.dart';

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
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.tealDeep, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${auth.name ?? 'Keluarga'}!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Text(
                          'Semua perjalanan aman, dalam satu tempat.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.amber,
                    child: Icon(Icons.family_restroom, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.childrenTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            if (children.loading)
              const Center(child: CircularProgressIndicator())
            else if (children.items.isEmpty)
              const PaEmptyState(
                icon: Icons.child_care,
                title: 'Belum ada anak',
                message: 'Hubungkan perangkat anak untuk mulai menjaga perjalanan mereka.',
              )
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

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      ParentHomeScreen(),
      AttendanceScreen(),
      ScreenTimeScreen(),
      RewardsScreen(),
      MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom), label: 'Anak'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Sekolah'),
          NavigationDestination(icon: Icon(Icons.hourglass_empty), selectedIcon: Icon(Icons.hourglass_bottom), label: 'Layar'),
          NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star), label: 'Hadiah'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Lainnya'),
        ],
      ),
    );
  }
}
