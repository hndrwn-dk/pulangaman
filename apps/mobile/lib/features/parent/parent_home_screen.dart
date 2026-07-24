import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_screen.dart';
import 'account_settings_screen.dart';
import 'child_avatar.dart';
import 'child_detail_screen.dart';
import 'child_home_map_card.dart';
import 'children_controller.dart';
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'live_map_screen.dart';
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
  final Map<String, int?> _batteryLevels = {};
  final Map<String, bool> _batteryCharging = {};
  final Map<String, bool> _staleByChild = {};
  final Map<String, DateTime?> _updatedAt = {};
  String? _selectedChildId;
  Map<String, dynamic>? _activitySummary;
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
    final nextPos = <String, LatLng>{..._positions};
    final nextBat = <String, int?>{..._batteryLevels};
    final nextCharge = <String, bool>{..._batteryCharging};
    final nextStale = <String, bool>{..._staleByChild};
    final nextAt = <String, DateTime?>{..._updatedAt};

    await Future.wait(children.map((c) async {
      try {
        final data = await api.get('/api/v1/children/${c.id}/location');
        final loc = data['location'] as Map<String, dynamic>?;
        final lat = (loc?['lat'] as num?)?.toDouble();
        final lng = (loc?['lng'] as num?)?.toDouble();
        final recorded = loc?['recordedAt'] as String?;
        nextStale[c.id] = data['isStale'] == true;
        nextBat[c.id] = (data['batteryLevel'] as num?)?.toInt() ??
            (loc?['batteryLevel'] as num?)?.toInt();
        nextCharge[c.id] =
            data['batteryCharging'] == true || loc?['batteryCharging'] == true;
        if (recorded != null) {
          nextAt[c.id] = DateTime.tryParse(recorded)?.toLocal();
        }
        if (lat != null && lng != null) {
          nextPos[c.id] = LatLng(lat, lng);
        }
      } catch (_) {}
    }));
    if (!mounted) return;
    setState(() {
      _positions
        ..clear()
        ..addAll(nextPos);
      _batteryLevels
        ..clear()
        ..addAll(nextBat);
      _batteryCharging
        ..clear()
        ..addAll(nextCharge);
      _staleByChild
        ..clear()
        ..addAll(nextStale);
      _updatedAt
        ..clear()
        ..addAll(nextAt);
    });
  }

  Future<void> _loadActivityFor(String childId) async {
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/children/$childId/activity');
      if (!mounted || _selectedChildId != childId) return;
      setState(() {
        _activitySummary = data['summary'] as Map<String, dynamic>?;
      });
    } catch (_) {
      if (!mounted || _selectedChildId != childId) return;
      setState(() => _activitySummary = null);
    }
  }

  void _selectChild(String childId) {
    if (_selectedChildId == childId) return;
    setState(() {
      _selectedChildId = childId;
      _activitySummary = null;
    });
    unawaited(_loadActivityFor(childId));
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
    } catch (_) {}
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
        setState(() {
          _positions[childId] = LatLng(lat, lng);
          _staleByChild[childId] = false;
          _updatedAt[childId] = DateTime.now();
          final bl = (payload['batteryLevel'] as num?)?.toInt();
          if (bl != null) _batteryLevels[childId] = bl;
          if (payload.containsKey('batteryCharging')) {
            _batteryCharging[childId] = payload['batteryCharging'] == true;
          }
        });
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  String? _stayDurationLabel() {
    final places = (_activitySummary?['places'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (places.isEmpty) return null;
    final sec = (places.first['durationSeconds'] as num?)?.toInt() ?? 0;
    if (sec <= 0) return null;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }

  void _openChildDetail(ChildSummary child) {
    final gender =
        _genders[child.id] ?? ChildGenderStore.guessFromName(child.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildDetailScreen(
          child: child,
          gender: gender,
          initialKabar: List<ChildKabarMessage>.from(_messages),
        ),
      ),
    );
  }

  void _openLiveMap(ChildSummary child) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveMapScreen(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final urgent = _messages.where((m) => m.isUrgent).toList();
    final items = children.items;

    if (items.isNotEmpty) {
      final ids = items.map((c) => c.id).toSet();
      if (_selectedChildId == null || !ids.contains(_selectedChildId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final id = items.first.id;
          setState(() => _selectedChildId = id);
          unawaited(_loadActivityFor(id));
        });
      }
    }

    if (items.isNotEmpty && _genders.length < items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGenders());
    }
    if (items.isNotEmpty && _positions.length < items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocations());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (items.isNotEmpty) _syncSubscriptions();
    });

    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (c) => c.id == _selectedChildId,
            orElse: () => items.first,
          );
    final placeCount = _activitySummary?['placeCount'] as int? ??
        ((_activitySummary?['places'] as List?)?.length ?? 0);
    final distM =
        (_activitySummary?['totalDistanceM'] as num?)?.toDouble() ?? 0.0;
    final distLabel = distM >= 1000
        ? '${(distM / 1000).toStringAsFixed(1)} km'
        : '${distM.round()} m';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: () async {
            await ref.read(childrenControllerProvider.notifier).refresh();
            await _loadGenders();
            await _loadMessages();
            await _loadLocations();
            final id = _selectedChildId;
            if (id != null) await _loadActivityFor(id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _HomeHeader(
                greeting: _greeting(),
                name: auth.name ?? 'Orang tua',
                initials: _initials(auth.name),
                notificationCount: _messages.length,
                onNotifications: () => _openInbox(),
                onAccount: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
              if (urgent.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...urgent.take(2).map(
                      (msg) => _UrgentBanner(
                        msg: msg,
                        onOpen: () => _openInbox(childId: msg.childId),
                      ),
                    ),
              ],
              const SizedBox(height: 18),
              if (children.loading && !children.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty) ...[
                const PaEmptyState(
                  icon: Icons.child_care,
                  title: 'Belum ada anak',
                  message:
                      'Ketuk “Tambah anak” di bawah untuk buat kode, '
                      'lalu masukkan di HP anak. Jika pindah ke login OTP, '
                      'pulihkan dulu dari nomor lama.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _showRecoverChildren(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealDeep,
                    side: const BorderSide(color: AppColors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Pulihkan anak dari nomor lama'),
                ),
              ] else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lokasi Anak',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (selected != null)
                      TextButton(
                        onPressed: () => _openLiveMap(selected),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Lihat peta ›',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = items[i];
                      final selectedChip = c.id == selected?.id;
                      final online = _staleByChild[c.id] != true &&
                          _positions.containsKey(c.id);
                      return _ChildChip(
                        name: c.name,
                        selected: selectedChip,
                        online: online,
                        gender: _genders[c.id] ??
                            ChildGenderStore.guessFromName(c.name),
                        onTap: () => _selectChild(c.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (selected != null)
                  ChildHomeMapCard(
                    child: selected,
                    gender: _genders[selected.id] ??
                        ChildGenderStore.guessFromName(selected.name),
                    position: _positions[selected.id],
                    batteryLevel: _batteryLevels[selected.id],
                    batteryCharging: _batteryCharging[selected.id] == true,
                    stale: _staleByChild[selected.id] ?? true,
                    updatedAt: _updatedAt[selected.id],
                    stayDurationLabel: _stayDurationLabel(),
                    onRelinkCode: () => _showRelinkInvite(context, selected),
                    onRemove: () => _confirmRemoveChild(context, selected),
                    onOpenMap: () => _openChildDetail(selected),
                  ),
                const SizedBox(height: 22),
                const Text(
                  'Ringkasan Hari Ini',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        value: '$placeCount',
                        label: 'Tempat dikunjungi',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        value: distLabel,
                        label: 'Total perjalanan',
                      ),
                    ),
                  ],
                ),
              ],
              if (children.invites.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Kode menunggu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...children.invites.map((invite) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key, color: AppColors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invite.code,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                              if (invite.childDisplayName != null)
                                Text(
                                  invite.childDisplayName!,
                                  style: const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
              const SizedBox(height: 18),
              _AddChildButton(onTap: () => _showCreateInvite(context)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoverChildren(BuildContext context) async {
    final phoneCtrl = TextEditingController(text: '+628126281233300011');
    final previous = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan anak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masukkan nomor yang dipakai akun orang tua lama '
              '(sebelum login OTP Firebase).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor lama',
                hintText: '+62812...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    phoneCtrl.dispose();
    if (previous == null || previous.isEmpty || !context.mounted) return;

    try {
      final count = await ref
          .read(authControllerProvider.notifier)
          .recoverChildrenFromPhone(previous);
      await ref.read(childrenControllerProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Berhasil memulihkan $count anak. Lalu buat kode masuk ulang di menu anak.'
                : 'Tidak ada anak yang dipindahkan. Cek nomor lama.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulihkan: $e')),
      );
    }
  }

  Future<void> _showRelinkInvite(BuildContext context, ChildSummary child) async {
    try {
      final invite =
          await ref.read(childrenControllerProvider.notifier).createInvite(
                childDisplayName: child.name,
                relinkChildId: child.id,
              );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Kode masuk ulang ${child.name}'),
          content: Text(
            invite.code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: AppColors.tealDeep,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
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

  Future<void> _confirmRemoveChild(
    BuildContext context,
    ChildSummary child,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${child.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(childrenControllerProvider.notifier).unlinkChild(child.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${child.name} dihapus')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

  Future<void> _showCreateInvite(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah anak'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama',
          ),
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
      final invite =
          await ref.read(childrenControllerProvider.notifier).createInvite(
                childDisplayName: nameCtrl.text,
              );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode'),
          content: Text(
            invite.code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: AppColors.tealDeep,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('OK'),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.initials,
    required this.notificationCount,
    required this.onNotifications,
    required this.onAccount,
  });

  final String greeting;
  final String name;
  final String initials;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: Colors.black12,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onNotifications,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.notifications_none_rounded, size: 22),
                ),
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.tealDeep,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAccount,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.online,
    required this.gender,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool online;
  final ChildGender gender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealDeep : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: const Color(0xFFE2E6EA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ChildAvatar(name: name, gender: gender, size: 30),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.05,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F6F1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.teal.withValues(alpha: 0.55),
            radius: 16,
          ),
          child: const SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: AppColors.tealDeep),
                SizedBox(width: 8),
                Text(
                  'Tambah anak',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.tealDeep,
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${msg.childName} butuh bantuan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.coral,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${kabarRelativeTime(msg.sentAt)} · Tap untuk detail',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A3B35),
                        ),
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
              label: 'Waktu Layar',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_work_outlined),
              selectedIcon: Icon(Icons.home_work),
              label: 'Zona',
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
