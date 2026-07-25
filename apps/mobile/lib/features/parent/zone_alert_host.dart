import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ws_client.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';
import 'live_map_screen.dart';

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

/// Listens for geofence arrivals and panic while parent app is open (any tab).
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
  Timer? _pollTimer;
  bool _dialogOpen = false;
  String? _panicBanner;
  String? _panicAlertId;
  String? _panicChildId;
  String? _seenPanicAlertId;
  bool _connecting = false;
  bool _panicBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await _connectWs(force: true);
      await _pollActivePanic();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => unawaited(_pollActivePanic()),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerClear?.cancel();
    _pollTimer?.cancel();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_connectWs(force: true));
      unawaited(_pollActivePanic());
    }
  }

  Future<void> _connectWs({bool force = false}) async {
    if (_connecting) return;
    final token = ref.read(authControllerProvider).token;
    final userId = ref.read(authControllerProvider).userId;
    if (token == null) return;

    _connecting = true;
    try {
      if (force || !_ws.isConnected) {
        _ws.addHandler(_onWs);
        await _ws.connect(token);
        _subscribed = {};
      }
      if (userId != null) {
        _ws.subscribe('parent:$userId');
      }
      _syncSubscriptions();
    } catch (_) {
      // Will retry on resume / next poll cycle reconnect.
    } finally {
      _connecting = false;
    }
  }

  void _syncSubscriptions() {
    final children = ref.read(childrenControllerProvider).items;
    final ids = children.map((c) => c.id).toSet();
    for (final id in ids.difference(_subscribed)) {
      _ws.subscribe('child:$id');
    }
    _subscribed = {..._subscribed, ...ids};
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:panic_triggered') {
      _handlePanic(payload);
      return;
    }
    if (event == 'child:panic_acked' || event == 'child:panic_resolved') {
      final alertId = payload['alertId'] as String?;
      if (alertId != null && alertId == _panicAlertId) {
        _clearPanicUi();
      }
      return;
    }
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

  Future<void> _pollActivePanic() async {
    if (!mounted) return;
    try {
      if (!_ws.isConnected) {
        await _connectWs(force: true);
      }
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/panic/active');
      final alerts = (data['alerts'] as List?) ?? const [];
      if (alerts.isEmpty) {
        if (_panicBanner != null && !_dialogOpen) {
          _clearPanicUi();
        }
        return;
      }
      final first = alerts.first;
      if (first is! Map) return;
      final map = Map<String, dynamic>.from(first);
      final alertId = map['alertId'] as String?;
      if (alertId == null) return;
      if (alertId == _seenPanicAlertId && _panicBanner != null) return;
      _handlePanic({
        'alertId': alertId,
        'childId': map['childId'],
        'location': map['location'],
      });
    } catch (_) {}
  }

  void _clearPanicUi() {
    if (!mounted) return;
    setState(() {
      _panicBanner = null;
      _panicAlertId = null;
      _panicChildId = null;
    });
  }

  void _handlePanic(Map<String, dynamic> payload) {
    if (!mounted) return;
    final alertId = payload['alertId'] as String?;
    if (alertId != null && alertId == _seenPanicAlertId && _panicBanner != null) {
      return;
    }
    if (alertId != null) {
      _seenPanicAlertId = alertId;
    }

    final childId = payload['childId'] as String? ?? '';
    final children = ref.read(childrenControllerProvider).items;
    var name = 'Anak';
    for (final c in children) {
      if (c.id == childId) {
        name = c.name;
        break;
      }
    }
    final message = '$name memicu tombol panik. Buka lokasi sekarang.';

    setState(() {
      _panicBanner = message;
      _panicAlertId = alertId;
      _panicChildId = childId.isEmpty ? null : childId;
      _banner = null;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 12),
      ),
    );
    unawaited(_showPanicDialog(name, message));
  }

  Future<void> _ackPanic() async {
    final alertId = _panicAlertId;
    if (alertId == null || _panicBusy) return;
    _panicBusy = true;
    try {
      await ref.read(apiClientProvider).post('/api/v1/panic/$alertId/ack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peringatan direspons. Cascade dihentikan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim respons. Coba lagi.')),
      );
    } finally {
      _panicBusy = false;
    }
  }

  Future<void> _resolvePanic() async {
    final alertId = _panicAlertId;
    if (alertId == null || _panicBusy) return;
    _panicBusy = true;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/panic/$alertId/resolve',
        body: {'notes': 'Diselesaikan orang tua'},
      );
      if (!mounted) return;
      _clearPanicUi();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panik ditandai selesai / aman.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyelesaikan panik. Coba lagi.')),
      );
    } finally {
      _panicBusy = false;
    }
  }

  void _openPanicMap() {
    final childId = _panicChildId;
    if (childId == null) return;
    final children = ref.read(childrenControllerProvider).items;
    ChildSummary? child;
    for (final c in children) {
      if (c.id == childId) {
        child = c;
        break;
      }
    }
    if (child == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveMapScreen(child: child!)),
    );
  }

  Future<void> _showPanicDialog(String childName, String message) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFFFE8E6),
                  child: Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PANIK',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(height: 1.35, fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPanicMap();
                },
                child: const Text('Buka lokasi'),
              ),
              TextButton(
                onPressed: () async {
                  await _ackPanic();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(AppStrings.ackAlert),
              ),
              FilledButton(
                onPressed: () async {
                  await _resolvePanic();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text(AppStrings.resolveAlert),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
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

    // Stack (not Column) so a zone/panic banner never blocks the shell layout.
    return Material(
      color: AppColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_panicBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 3,
                  color: const Color(0xFFFFE8E6),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                          ),
                          title: const Text(
                            'PANIK',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.danger,
                            ),
                          ),
                          subtitle: Text(_panicBanner!),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _openPanicMap,
                              child: const Text('Buka lokasi'),
                            ),
                            TextButton(
                              onPressed: () => unawaited(_ackPanic()),
                              child: const Text(AppStrings.ackAlert),
                            ),
                            FilledButton(
                              onPressed: () => unawaited(_resolvePanic()),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              child: const Text(AppStrings.resolveAlert),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_banner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 2,
                  color: _banner!.isEnter
                      ? const Color(0xFFE8F8F2)
                      : const Color(0xFFFFF4E5),
                  child: ListTile(
                    leading: Icon(
                      _banner!.icon,
                      color: _banner!.isEnter
                          ? AppColors.tealDeep
                          : AppColors.amber,
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
            ),
        ],
      ),
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
