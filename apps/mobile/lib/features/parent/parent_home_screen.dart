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
                message:
                    'Buat kode undangan, lalu masukkan kode itu di HP anak.',
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
            if (children.invites.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Kode menunggu dipakai',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              ...children.invites.map((invite) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key, color: AppColors.teal),
                    title: Text(
                      invite.code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    subtitle: Text(
                      invite.childDisplayName == null
                          ? 'Berlaku sampai ${invite.expiresAt.toLocal()}'
                          : '${invite.childDisplayName} · sampai ${invite.expiresAt.toLocal()}',
                    ),
                  ),
                );
              }),
            ],
            if (children.error != null) ...[
              const SizedBox(height: 8),
              Text(children.error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showCreateInvite(context),
              icon: const Icon(Icons.qr_code_2),
              label: const Text(AppStrings.createInvite),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateInvite(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.createInvite),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama panggilan anak (opsional)',
            hintText: 'Contoh: Andi',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buat kode'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final invite = await ref.read(childrenControllerProvider.notifier).createInvite(
            childDisplayName: nameCtrl.text,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode undangan siap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                invite.code,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.tealDeep,
                ),
              ),
              const SizedBox(height: 12),
              const Text(AppStrings.inviteShareHint),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal buat kode: $e')),
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
