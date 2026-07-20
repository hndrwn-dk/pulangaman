import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class ZoneArrivalNotice {
  ZoneArrivalNotice({
    required this.childId,
    required this.childName,
    required this.zoneLabel,
    required this.zoneType,
    required this.event,
    required this.message,
    required this.at,
  });

  final String childId;
  final String childName;
  final String zoneLabel;
  final String zoneType;
  final String event;
  final String message;
  final DateTime at;

  bool get isEnter => event == 'enter';

  factory ZoneArrivalNotice.fromPayload(Map<String, dynamic> payload) {
    final zoneType = payload['zoneType'] as String? ?? 'custom';
    final zoneName = payload['zoneName'] as String?;
    final zoneLabel = (payload['zoneLabel'] as String?) ??
        (zoneName?.trim().isNotEmpty == true
            ? zoneName!.trim()
            : zoneType == 'home'
                ? 'Rumah'
                : zoneType == 'school'
                    ? 'Sekolah'
                    : 'Zona aman');
    final childName = payload['childName'] as String? ?? 'Anak';
    final event = payload['event'] as String? ?? 'enter';
    final message = payload['message'] as String? ??
        (event == 'enter'
            ? '$childName sudah sampai di $zoneLabel'
            : '$childName meninggalkan $zoneLabel');
    final atRaw = payload['at'] as String?;
    return ZoneArrivalNotice(
      childId: payload['childId'] as String? ?? '',
      childName: childName,
      zoneLabel: zoneLabel,
      zoneType: zoneType,
      event: event,
      message: message,
      at: atRaw != null ? DateTime.tryParse(atRaw) ?? DateTime.now() : DateTime.now(),
    );
  }

  IconData get icon {
    if (zoneType == 'home') return Icons.home_rounded;
    if (zoneType == 'school') return Icons.school_rounded;
    return Icons.shield_rounded;
  }
}

/// Listens for geofence arrivals while parent app is open (any tab).
class ParentZoneAlertHost extends ConsumerStatefulWidget {
  const ParentZoneAlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ParentZoneAlertHost> createState() => _ParentZoneAlertHostState();
}

class _ParentZoneAlertHostState extends ConsumerState<ParentZoneAlertHost>
    with WidgetsBindingObserver {
  final _ws = WsClient();
  Set<String> _subscribed = {};
  ZoneArrivalNotice? _banner;
  Timer? _bannerClear;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_connectWs);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerClear?.cancel();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_connectWs());
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
    for (final id in ids.difference(_subscribed)) {
      _ws.subscribe('child:$id');
    }
    _subscribed = ids;
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event != 'parent:zone_event') return;
    final notice = ZoneArrivalNotice.fromPayload(payload);
    if (notice.childId.isEmpty) return;
    if (!mounted) return;

    setState(() => _banner = notice);
    _bannerClear?.cancel();
    _bannerClear = Timer(const Duration(seconds: 45), () {
      if (mounted && _banner == notice) {
        setState(() => _banner = null);
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice.message),
        backgroundColor:
            notice.isEnter ? AppColors.tealDeep : AppColors.inkSoft,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    if (notice.isEnter) {
      unawaited(_showArriveDialog(notice));
      unawaited(ref.read(childrenControllerProvider.notifier).refresh());
    }
  }

  Future<void> _showArriveDialog(ZoneArrivalNotice notice) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(notice.icon, color: AppColors.tealDeep),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Anak di zona aman',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: Text(
              notice.message,
              style: const TextStyle(height: 1.35, fontSize: 16),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Mengerti'),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(childrenControllerProvider, (_, next) {
      if (next.items.isNotEmpty) _syncSubscriptions();
    });

    return Column(
      children: [
        if (_banner != null)
          Material(
            color: _banner!.isEnter
                ? const Color(0xFFE8F8F2)
                : const Color(0xFFFFF4E5),
            child: SafeArea(
              bottom: false,
              child: ListTile(
                leading: Icon(
                  _banner!.icon,
                  color: _banner!.isEnter ? AppColors.tealDeep : AppColors.amber,
                ),
                title: Text(
                  _banner!.isEnter ? 'Zona aman' : 'Update zona',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(_banner!.message),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _banner = null),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

String commuteStatusLabel(String? status) {
  switch (status) {
    case 'home':
      return 'Di rumah';
    case 'school':
      return 'Di sekolah';
    case 'safe_zone':
      return 'Di zona aman';
    case 'commuting':
      return 'Dalam perjalanan';
    default:
      return '';
  }
}
