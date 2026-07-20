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
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'live_map_screen.dart';
import 'more_screen.dart';
import 'zone_alert_host.dart';

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
      await ref.read(childrenControllerProvider.notifier).bootstrap();
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
        backgroundColor: msg.isUrgent ? AppColors.coral : AppColors.tealDeep,
      ),
    );
  }

  void _openInbox({String? childId}) {
    final children = ref.read(childrenControllerProvider).items;
    final names = {for (final c in children) c.id: c.name};
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KabarInboxScreen(
          messages: List<ChildKabarMessage>.from(_messages),
          initialChildId: childId,
          childNames: names,
        ),
      ),
    );
  }

  ChildKabarMessage? _latestFor(String childId) {
    ChildKabarMessage? best;
    for (final m in _messages) {
      if (m.childId != childId) continue;
      if (best == null || m.sentAt.isAfter(best.sentAt)) best = m;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final latestPerChild = latestKabarPerChild(_messages);
    final urgent = latestPerChild.where((m) => m.isUrgent).toList();

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
                  'Status anak',
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
                  )
                else if (_messages.isNotEmpty)
                  TextButton(
                    onPressed: () => _openInbox(),
                    child: Text('Riwayat (${_messages.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Hanya kabar terakhir tiap anak. Buka riwayat untuk lihat semuanya.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (urgent.isNotEmpty) ...[
              ...urgent.map((msg) => _UrgentBanner(
                    msg: msg,
                    onOpen: () => _openInbox(childId: msg.childId),
                  )),
              const SizedBox(height: 8),
            ],
            if (latestPerChild.isEmpty)
              PaSectionCard(
                color: AppColors.sand.withValues(alpha: 0.5),
                child: const Text(
                  'Belum ada kabar dari anak. Saat anak kirim pesan cepat, statusnya muncul di sini (satu kartu per anak).',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              )
            else
              ...latestPerChild.map((msg) {
                if (msg.isUrgent) return const SizedBox.shrink();
                return _LatestStatusCard(
                  msg: msg,
                  onTap: () => _openInbox(childId: msg.childId),
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
            if (children.loading && !children.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (children.items.isEmpty)
              const PaEmptyState(
                icon: Icons.child_care,
                title: 'Belum ada anak',
                message:
                    'Buat kode undangan, lalu masukkan kode itu di HP anak.',
              )
            else ...[
              if (children.refreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ...children.items.map((child) {
                final kabar = _latestFor(child.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kabar == null
                          ? AppColors.mint
                          : kabarPresetColor(kabar.preset).withValues(alpha: 0.2),
                      child: Icon(
                        kabar == null
                            ? Icons.child_care
                            : kabarPresetIcon(kabar.preset),
                        color: kabar == null
                            ? AppColors.tealDeep
                            : kabarPresetColor(kabar.preset),
                      ),
                    ),
                    title: Text(
                      child.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatLastSeen(child.lastSeenAt)),
                        if (commuteStatusLabel(child.commuteStatus).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            commuteStatusLabel(child.commuteStatus),
                            style: const TextStyle(
                              color: AppColors.tealDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (kabar != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${kabar.text} · ${kabarRelativeTime(kabar.sentAt)}',
                            style: TextStyle(
                              color: kabar.isUrgent
                                  ? AppColors.coral
                                  : AppColors.tealDeep,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: kabar != null ||
                        commuteStatusLabel(child.commuteStatus).isNotEmpty,
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
            ],
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

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.msg, required this.onOpen});

  final ChildKabarMessage msg;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.priority_high_rounded, color: AppColors.coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${msg.childName} butuh bantuan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.coral,
                        ),
                      ),
                      Text(
                        '${msg.text} · ${kabarRelativeTime(msg.sentAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.coral),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestStatusCard extends StatelessWidget {
  const _LatestStatusCard({required this.msg, required this.onTap});

  final ChildKabarMessage msg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = kabarPresetColor(msg.preset);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
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
                  child: Icon(kabarPresetIcon(msg.preset), color: color),
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
                      Text(
                        msg.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  kabarRelativeTime(msg.sentAt),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    return ParentZoneAlertHost(
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            setState(() => _index = value);
            if (value == 0) {
              unawaited(
                ref.read(childrenControllerProvider.notifier).refresh(),
              );
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined),
              selectedIcon: Icon(Icons.family_restroom),
              label: 'Anak',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Sekolah',
            ),
            NavigationDestination(
              icon: Icon(Icons.phone_android_outlined),
              selectedIcon: Icon(Icons.phone_android),
              label: 'Batas HP',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star),
              label: 'Hadiah',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Lainnya',
            ),
          ],
        ),
      ),
    );
  }
}
