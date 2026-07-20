import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ws_client.dart';
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

class ChildKabarMessage {
  ChildKabarMessage({
    required this.id,
    required this.childId,
    required this.childName,
    required this.text,
    this.preset,
    required this.sentAt,
  });

  final String id;
  final String childId;
  final String childName;
  final String text;
  final String? preset;
  final DateTime sentAt;

  factory ChildKabarMessage.fromJson(Map<String, dynamic> json) {
    return ChildKabarMessage(
      id: json['id'] as String? ??
          '${json['childId']}-${json['sentAt']}-${json['text']}',
      childId: json['childId'] as String? ?? '',
      childName: json['childName'] as String? ?? 'Anak',
      text: json['text'] as String? ?? '',
      preset: json['preset'] as String?,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen>
    with WidgetsBindingObserver {
  final _ws = WsClient();
  final List<ChildKabarMessage> _messages = [];
  bool _messagesLoading = false;
  Set<String> _subscribedChildren = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).refresh();
      await _loadMessages();
      await _connectWs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(childrenControllerProvider.notifier).refresh();
      unawaited(_loadMessages());
      unawaited(_connectWs());
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _messagesLoading = true);
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/messages');
      final list = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildKabarMessage.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
    } catch (_) {
      // Parent may not have messages yet.
    } finally {
      if (mounted) setState(() => _messagesLoading = false);
    }
  }

  Future<void> _connectWs() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      if (!_ws.isConnected) {
        await _ws.connect(token);
        _ws.addHandler(_onWs);
      }
      _syncSubscriptions();
    } catch (_) {}
  }

  void _syncSubscriptions() {
    final children = ref.read(childrenControllerProvider).items;
    final ids = children.map((c) => c.id).toSet();
    for (final id in ids.difference(_subscribedChildren)) {
      _ws.subscribe('child:$id');
    }
    _subscribedChildren = ids;
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event != 'child:message') return;
    final msg = ChildKabarMessage.fromJson({
      'id': payload['id'] ??
          '${payload['childId']}-${payload['sentAt']}-${payload['text']}',
      'childId': payload['childId'],
      'childName': payload['childName'],
      'text': payload['text'],
      'preset': payload['preset'],
      'sentAt': payload['sentAt'] ?? DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
      _messages.insert(0, msg);
      if (_messages.length > 50) {
        _messages.removeRange(50, _messages.length);
      }
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${msg.childName}: ${msg.text}'),
        backgroundColor: AppColors.tealDeep,
      ),
    );
  }

  IconData _presetIcon(String? preset) {
    switch (preset) {
      case 'at_school':
        return Icons.school_rounded;
      case 'at_home':
        return Icons.home_rounded;
      case 'need_help':
        return Icons.support_agent_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _presetColor(String? preset) {
    switch (preset) {
      case 'at_school':
        return AppColors.teal;
      case 'at_home':
        return AppColors.success;
      case 'need_help':
        return AppColors.coral;
      default:
        return AppColors.sky;
    }
  }

  String _relativeTime(DateTime at) {
    final age = DateTime.now().difference(at.toLocal());
    if (age.inSeconds < 60) return 'baru saja';
    if (age.inMinutes < 60) return '${age.inMinutes} mnt lalu';
    if (age.inHours < 24) return '${age.inHours} jam lalu';
    return '${age.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);

    // Keep WS rooms in sync when children list changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (children.items.isNotEmpty) _syncSubscriptions();
    });

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
        onRefresh: () async {
          await ref.read(childrenControllerProvider.notifier).refresh();
          await _loadMessages();
        },
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
            Row(
              children: [
                Text(
                  'Kabar terbaru',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                if (_messagesLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_messages.isEmpty)
              PaSectionCard(
                color: AppColors.sand.withValues(alpha: 0.5),
                child: const Text(
                  'Belum ada kabar dari anak. Pesan cepat dari HP anak akan muncul di sini.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              )
            else
              ..._messages.take(8).map((msg) {
                final color = _presetColor(msg.preset);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_presetIcon(msg.preset), color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.childName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(msg.text),
                            ],
                          ),
                        ),
                        Text(
                          _relativeTime(msg.sentAt),
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
      if (context.mounted) {
        await ref.read(childrenControllerProvider.notifier).refresh();
      }
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
    final pages = [
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
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (value == 0) {
            ref.read(childrenControllerProvider.notifier).refresh();
          }
        },
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
