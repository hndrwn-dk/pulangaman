import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_screen.dart';
import 'child_avatar.dart';
import 'child_detail_screen.dart';
import 'child_home_map_card.dart';
import 'children_controller.dart';
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'more_screen.dart';
import 'zones_screen.dart';
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
  Set<String> _subscribedChildren = {};
  final Map<String, ChildGender> _genders = {};
  final Map<String, LatLng> _positions = {};
  Timer? _locationPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      await _loadMessages();
      await _loadLocations();
      await _connectWs();
      _locationPoll?.cancel();
      _locationPoll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _loadLocations(),
      );
    });
  }

  Future<void> _loadGenders() async {
    final children = ref.read(childrenControllerProvider).items;
    final map = <String, ChildGender>{};
    for (final c in children) {
      var g = await ChildGenderStore.instance.get(c.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(c.name);
      }
      map[c.id] = g;
    }
    if (!mounted) return;
    setState(() {
      _genders
        ..clear()
        ..addAll(map);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationPoll?.cancel();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(childrenControllerProvider.notifier).refresh();
      unawaited(_loadMessages());
      unawaited(_loadLocations());
      unawaited(_connectWs());
    }
  }

  Future<void> _loadLocations() async {
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) return;
    final api = ref.read(apiClientProvider);
    final next = <String, LatLng>{..._positions};
    await Future.wait(children.map((c) async {
      try {
        final data = await api.get('/api/v1/children/${c.id}/location');
        final loc = data['location'] as Map<String, dynamic>?;
        final lat = (loc?['lat'] as num?)?.toDouble();
        final lng = (loc?['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          next[c.id] = LatLng(lat, lng);
        }
      } catch (_) {}
    }));
    if (!mounted) return;
    setState(() {
      _positions
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _loadMessages() async {
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
    if (event == 'child:location_update') {
      final childId = payload['childId'] as String?;
      final lat = (payload['lat'] as num?)?.toDouble();
      final lng = (payload['lng'] as num?)?.toDouble();
      if (childId != null && lat != null && lng != null && mounted) {
        setState(() => _positions[childId] = LatLng(lat, lng));
      }
      return;
    }
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
    final urgent = _messages.where((m) => m.isUrgent).toList();
    if (children.items.isNotEmpty && _genders.length < children.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGenders());
    }
    if (children.items.isNotEmpty &&
        _positions.length < children.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocations());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (children.items.isNotEmpty) _syncSubscriptions();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.brand} · ${auth.name ?? ''}'),
        actions: [
          if (_messages.isNotEmpty)
            TextButton(
              onPressed: () => _openInbox(),
              child: Text(
                'Kabar (${_messages.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout, size: 26),
            tooltip: AppStrings.logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(childrenControllerProvider.notifier).refresh();
          await _loadGenders();
          await _loadMessages();
          await _loadLocations();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Anak saya',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Ketuk kartu anak untuk buka peta lokasi.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (urgent.isNotEmpty) ...[
              ...urgent.take(2).map(
                    (msg) => _UrgentBanner(
                      msg: msg,
                      onOpen: () => _openInbox(childId: msg.childId),
                    ),
                  ),
              const SizedBox(height: 8),
            ],
            if (children.loading && !children.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (children.items.isEmpty)
              const PaEmptyState(
                icon: Icons.child_care,
                title: 'Belum ada anak',
                message:
                    'Gunakan “Mau tambah anak?” di bawah untuk buat kode, '
                    'lalu masukkan di HP anak.',
              )
            else ...[
              ...children.items.map((child) {
                final kabar = _latestFor(child.id);
                final gender = _genders[child.id] ??
                    ChildGenderStore.guessFromName(child.name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ChildHomeMapCard(
                    child: child,
                    gender: gender,
                    position: _positions[child.id],
                    kabar: kabar,
                    onOpenKabar: kabar == null
                        ? null
                        : () => _openInbox(childId: child.id),
                    onOpenMap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChildDetailScreen(
                            child: child,
                            gender: gender,
                            initialKabar: List<ChildKabarMessage>.from(_messages),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
            if (children.invites.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Kode menunggu dipakai',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Ketik kode ini di HP anak (buka PulangAman → pilih Anak).',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 10),
              ...children.invites.map((invite) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.vpn_key, color: AppColors.teal, size: 28),
                    title: Text(
                      invite.code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    subtitle: Text(
                      invite.childDisplayName == null
                          ? 'Berlaku sampai ${invite.expiresAt.toLocal()}'
                          : '${invite.childDisplayName} · sampai ${invite.expiresAt.toLocal()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              }),
            ],
            if (children.error != null) ...[
              const SizedBox(height: 8),
              Text(
                children.error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22075A4F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mau tambah anak?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buat kode, lalu ketik kode itu di HP anak. '
                    'Satu kode untuk satu anak.',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showCreateInvite(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
                    label: const Text('Tambah anak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.tealDeep,
                      side: const BorderSide(color: AppColors.teal, width: 2),
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
        title: const Text('Tambah anak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isi nama panggilan supaya mudah diingat (boleh dikosongkan).',
              style: TextStyle(color: AppColors.inkSoft, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama panggilan anak (opsional)',
                hintText: 'Contoh: Andi, Sinta',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
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
          title: const Text('Kode siap dipakai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                invite.code,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.tealDeep,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Buka PulangAman di HP anak → pilih Anak → masukkan kode ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSoft,
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      if (context.mounted) {
        await ref.read(childrenControllerProvider.notifier).refresh(force: true);
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
      const ParentHomeScreen(),
      const ScreenTimeScreen(),
      const PlacesEntryScreen(),
      const MoreScreen(),
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
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Waktu HP',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_work_outlined),
              selectedIcon: Icon(Icons.home_work),
              label: 'Tempat',
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
