import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_screen.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'live_map_screen.dart';
import 'reminders_screen.dart';
import 'zones_screen.dart';

/// Find My Kids–inspired child hub: map + actions + daily timeline.
class ChildDetailScreen extends ConsumerStatefulWidget {
  const ChildDetailScreen({
    super.key,
    required this.child,
    this.gender = ChildGender.unknown,
    this.initialKabar = const [],
  });

  final ChildSummary child;
  final ChildGender gender;
  final List<ChildKabarMessage> initialKabar;

  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  final _ws = WsClient();
  GoogleMapController? _mapController;
  LatLng? _position;
  DateTime? _updatedAt;
  bool _stale = true;
  bool _atHome = false;
  String? _placeLabel;
  int? _batteryLevel;
  bool _batteryCharging = false;
  String _batteryAlert = 'none';
  LatLng? _homeCenter;
  double _homeRadiusM = 120;
  Set<Circle> _circles = {};
  final List<LatLng> _trail = [];
  Timer? _poll;
  ChildGender _gender = ChildGender.unknown;

  Map<String, dynamic>? _activitySummary;
  List<Map<String, dynamic>> _activityEvents = [];
  bool _activityLoading = true;
  String? _activityError;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    if (_gender == ChildGender.unknown) {
      var g = await ChildGenderStore.instance.get(widget.child.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(widget.child.name);
      }
      if (mounted) setState(() => _gender = g);
    }
    await _loadHomeZone();
    await Future.wait([_fetchLocation(), _fetchActivity(), _fetchHistory()]);
    final token = ref.read(authControllerProvider).token;
    if (token != null) {
      try {
        await _ws.connect(token);
        _ws.addHandler(_onWs);
        _ws.subscribe('child:${widget.child.id}');
      } catch (_) {}
    }
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      _fetchLocation();
    });
  }

  Future<void> _loadHomeZone() async {
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/zones',
        query: {'childId': widget.child.id},
      );
      final zones = (data['zones'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      Map<String, dynamic>? home;
      for (final z in zones) {
        if (z['type'] == 'home') {
          home = z;
          break;
        }
      }
      if (home == null) return;
      final lat = (home['lat'] as num?)?.toDouble();
      final lng = (home['lng'] as num?)?.toDouble();
      final radius = (home['radius_m'] as num?)?.toDouble() ?? 120;
      if (lat == null || lng == null) return;
      if (!mounted) return;
      setState(() {
        _homeCenter = LatLng(lat, lng);
        _homeRadiusM = radius;
        _circles = {
          Circle(
            circleId: const CircleId('home'),
            center: _homeCenter!,
            radius: _homeRadiusM,
            fillColor: AppColors.teal.withValues(alpha: 0.12),
            strokeColor: AppColors.teal,
            strokeWidth: 2,
          ),
        };
      });
    } catch (_) {}
  }

  bool _isInsideHome(LatLng p) {
    final home = _homeCenter;
    if (home == null) return false;
    const r = 6371000.0;
    final dLat = (p.latitude - home.latitude) * math.pi / 180;
    final dLng = (p.longitude - home.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(home.latitude * math.pi / 180) *
            math.cos(p.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final d = 2 * r * math.asin(math.sqrt(a));
    return d <= _homeRadiusM;
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/children/${widget.child.id}/location/history',
        query: {'minutes': '120'},
      );
      final points = (data['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final lat = (p['lat'] as num?)?.toDouble();
            final lng = (p['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return LatLng(lat, lng);
          })
          .whereType<LatLng>()
          .toList();
      if (!mounted || points.isEmpty) return;
      setState(() {
        _trail
          ..clear()
          ..addAll(_simplifyTrail(points));
      });
    } catch (_) {}
  }

  List<LatLng> _simplifyTrail(List<LatLng> points) {
    if (points.length <= 40) return points;
    final out = <LatLng>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      if (i % ((points.length / 40).ceil()) == 0) out.add(points[i]);
    }
    out.add(points.last);
    return out;
  }

  Future<void> _fetchLocation() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/children/${widget.child.id}/location');
      final loc = data['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      final recorded = loc?['recordedAt'] as String?;
      final at = recorded != null ? DateTime.tryParse(recorded) : null;
      if (!mounted) return;
      setState(() {
        _stale = data['isStale'] == true;
        _batteryLevel = (data['batteryLevel'] as num?)?.toInt() ??
            (loc?['batteryLevel'] as num?)?.toInt();
        _batteryCharging = data['batteryCharging'] == true ||
            loc?['batteryCharging'] == true;
        _batteryAlert = data['batteryAlert'] as String? ?? 'none';
        if (lat != null && lng != null) {
          final pos = LatLng(lat, lng);
          _position = pos;
          _updatedAt = at?.toLocal() ?? DateTime.now();
          _atHome = _isInsideHome(pos);
          if (!_atHome) {
            if (_trail.isEmpty || _trail.last != pos) {
              _trail.add(pos);
              if (_trail.length > 80) _trail.removeAt(0);
            }
          }
        }
      });
      if (lat != null && lng != null) {
        await _reverseGeocode(LatLng(lat, lng));
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(lat, lng),
            _atHome ? 16 : 15,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _stale = true);
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/places/reverse',
        query: {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
        },
      );
      final label = data['label'] as String? ?? data['address'] as String?;
      if (!mounted || label == null || label.isEmpty) return;
      setState(() => _placeLabel = label);
    } catch (_) {}
  }

  Future<void> _fetchActivity() async {
    if (mounted) {
      setState(() {
        _activityLoading = true;
        _activityError = null;
      });
    }
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/children/${widget.child.id}/activity');
      if (!mounted) return;
      setState(() {
        _activitySummary = data['summary'] as Map<String, dynamic>?;
        _activityEvents = (data['events'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _activityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activityLoading = false;
        _activityError = 'Riwayat hari ini belum bisa dimuat';
      });
    }
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:location_update' &&
        payload['childId'] == widget.child.id) {
      final lat = (payload['lat'] as num?)?.toDouble();
      final lng = (payload['lng'] as num?)?.toDouble();
      if (lat == null || lng == null || !mounted) return;
      final pos = LatLng(lat, lng);
      setState(() {
        _position = pos;
        _updatedAt = DateTime.now();
        _stale = false;
        _atHome = _isInsideHome(pos);
        final bl = (payload['batteryLevel'] as num?)?.toInt();
        if (bl != null) _batteryLevel = bl;
        if (payload.containsKey('batteryCharging')) {
          _batteryCharging = payload['batteryCharging'] == true;
        }
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _mapController?.dispose();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  String get _statusBubble {
    if (_atHome) return 'Di rumah';
    if (_placeLabel != null && _placeLabel!.isNotEmpty) {
      return _placeLabel!;
    }
    if (_position == null) return 'Menunggu lokasi...';
    return 'Terlihat di peta';
  }

  String get _whenLabel {
    final at = _updatedAt;
    if (at == null) return 'Belum ada sinyal';
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return 'Update $hm';
  }

  String? get _batteryBannerText {
    switch (_batteryAlert) {
      case 'dead':
        return 'HP anak hampir habis / mati. Lokasi mungkin tidak diperbarui.';
      case 'low':
        return 'Baterai HP anak lemah (${_batteryLevel ?? '?'}%).';
      case 'stale':
        return 'Sinyal lokasi lama. HP anak mungkin mati atau tanpa jaringan.';
      default:
        if (_batteryLevel != null && _batteryLevel! <= 15 && !_batteryCharging) {
          return 'Baterai HP anak lemah ($_batteryLevel%).';
        }
        return null;
    }
  }

  void _openKabar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KabarInboxScreen(
          messages: List<ChildKabarMessage>.from(widget.initialKabar),
          initialChildId: widget.child.id,
          childNames: {widget.child.id: widget.child.name},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _position ?? const LatLng(-6.2, 106.8);
    final polylines = <Polyline>{
      if (!_atHome && _trail.length >= 2)
        Polyline(
          polylineId: const PolylineId('trail'),
          points: List<LatLng>.from(_trail),
          color: AppColors.teal,
          width: 4,
          geodesic: true,
        ),
    };
    final banner = _batteryBannerText;
    final mapHeight = MediaQuery.sizeOf(context).height * 0.36;
    final statusLine = _stale
        ? 'Lokasi tidak bisa diperbarui'
        : (_atHome ? 'Di rumah' : 'Sedang dipantau');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          SizedBox(
            height: mapHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: center, zoom: 15),
                  onMapCreated: (c) {
                    _mapController = c;
                    if (_position != null) {
                      c.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          _position!,
                          _atHome ? 16 : 15,
                        ),
                      );
                    }
                  },
                  markers: {
                    if (_position != null)
                      Marker(
                        markerId: MarkerId(widget.child.id),
                        position: _position!,
                        infoWindow: InfoWindow(
                          title: widget.child.name,
                          snippet: _batteryLevel == null
                              ? _statusBubble
                              : 'Baterai $_batteryLevel%'
                                  '${_batteryCharging ? ' · cas' : ''}',
                        ),
                      ),
                  },
                  circles: _circles,
                  polylines: polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MapRoundButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            _MapRoundButton(
                              icon: Icons.gps_fixed_rounded,
                              iconColor: const Color(0xFFE85A7A),
                              onTap: () {
                                if (_position == null) return;
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    _position!,
                                    _atHome ? 16 : 15,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _MapRoundButton(
                              icon: Icons.open_in_full_rounded,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LiveMapScreen(child: widget.child),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 48,
                  right: 48,
                  top: MediaQuery.paddingOf(context).top + 10,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealDeep,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tealDeep.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '$_statusBubble · $_whenLabel',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () async {
                  await Future.wait([
                    _fetchLocation(),
                    _fetchActivity(),
                    _loadHomeZone(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  children: [
                    _ProfileStatusCard(
                      name: widget.child.name,
                      gender: _gender,
                      statusLine: statusLine,
                      stale: _stale,
                      banner: banner,
                      batteryLevel: _batteryLevel,
                      batteryCharging: _batteryCharging,
                      onRefresh: _fetchLocation,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.home_work_rounded,
                            label: 'Zona aman',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlacesScreen(child: widget.child),
                                ),
                              );
                              await _loadHomeZone();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.chat_bubble_rounded,
                            label: 'Kabar',
                            onTap: _openKabar,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.phone_android_rounded,
                            label: 'Waktu Layar',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScreenTimeScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.alarm_rounded,
                            label: 'Pengingat',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RemindersScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Hari ini',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_activityLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_activityError != null)
                      Text(
                        _activityError!,
                        style: const TextStyle(color: AppColors.coral),
                      )
                    else ...[
                      if (_activitySummary != null)
                        _ActivitySummaryRow(summary: _activitySummary!),
                      const SizedBox(height: 12),
                      if (_activityEvents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),
                          decoration: _cardDecoration,
                          child: const Text(
                            'Belum ada jejak hari ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ...List.generate(_activityEvents.length, (i) {
                          final e = _activityEvents[i];
                          final type = e['type'] as String?;
                          final isLast = i == _activityEvents.length - 1;
                          if (type == 'stay') {
                            return _TimelineStayCard(
                              event: e,
                              showConnector: !isLast,
                            );
                          }
                          if (type == 'trip') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TripCard(event: e),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: iconColor ?? AppColors.ink),
        ),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({
    required this.name,
    required this.gender,
    required this.statusLine,
    required this.stale,
    required this.banner,
    required this.batteryLevel,
    required this.batteryCharging,
    required this.onRefresh,
  });

  final String name;
  final ChildGender gender;
  final String statusLine;
  final bool stale;
  final String? banner;
  final int? batteryLevel;
  final bool batteryCharging;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(name: name, gender: gender, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: stale
                                ? const Color(0xFFE8A11A)
                                : AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusLine,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: stale
                                  ? const Color(0xFFC46A0A)
                                  : AppColors.tealDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFFF3F5F7),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onRefresh(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (banner != null) ...[
            const SizedBox(height: 12),
            _AlertPill(text: banner!, onTap: () => onRefresh()),
          ],
          const SizedBox(height: 14),
          _BatteryMeter(level: batteryLevel, charging: batteryCharging),
        ],
      ),
    );
  }
}

class _BatteryMeter extends StatelessWidget {
  const _BatteryMeter({required this.level, required this.charging});

  final int? level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final value = level;
    final known = value != null;
    final low = known && value <= 15 && !charging;
    final pct = known ? (value.clamp(0, 100) / 100.0) : 0.0;
    final label = !known
        ? 'Baterai belum diketahui'
        : charging
            ? 'Baterai $value% · di-cas'
            : 'Baterai $value%';
    final color = low ? AppColors.coral : AppColors.teal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              charging
                  ? Icons.battery_charging_full_rounded
                  : low
                      ? Icons.battery_alert_rounded
                      : Icons.battery_std_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: low ? AppColors.coral : AppColors.ink,
                ),
              ),
            ),
            if (known)
              Text(
                '$value%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: color,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: known ? pct : 0.08,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8ECF0),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AlertPill extends StatelessWidget {
  const _AlertPill({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3E6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    fontSize: 13,
                    color: Color(0xFF9A5B00),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.tealDeep, size: 26),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.15,
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

class _ActivitySummaryRow extends StatelessWidget {
  const _ActivitySummaryRow({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final places = (summary['places'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final placeCount = summary['placeCount'] as int? ?? places.length;
    final distM = (summary['totalDistanceM'] as num?)?.toDouble() ?? 0;
    final distLabel = distM >= 1000
        ? '${(distM / 1000).toStringAsFixed(1)} km'
        : '${distM.round()} m';

    return Row(
      children: [
        Expanded(
          child: _SummaryStat(
            value: '$placeCount',
            label: 'tempat',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryStat(
            value: distLabel,
            label: 'Perjalanan',
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1.05,
              letterSpacing: -0.8,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStayCard extends StatelessWidget {
  const _TimelineStayCard({
    required this.event,
    required this.showConnector,
  });

  final Map<String, dynamic> event;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final type = event['placeType'] as String? ?? 'custom';
    final name = _friendlyPlaceName(event['placeName'] as String?, type);
    final start =
        DateTime.tryParse(event['startAt'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(event['endAt'] as String? ?? '')?.toLocal();
    final dur = (event['durationSeconds'] as num?)?.toInt() ?? 0;
    final icon = type == 'home'
        ? Icons.home_rounded
        : type == 'school'
            ? Icons.school_rounded
            : Icons.place_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.inkSoft.withValues(alpha: 0.22),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                decoration: _cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.tealDeep,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_fmtClock(start)} — ${_fmtClock(end)}',
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtDuration(dur),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(event['startAt'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(event['endAt'] as String? ?? '')?.toLocal();
    final dur = (event['durationSeconds'] as num?)?.toInt() ?? 0;
    final startLabel = _friendlyPlaceName(
      event['startLabel'] as String?,
      null,
    );
    final endLabel = _friendlyPlaceName(
      event['endLabel'] as String?,
      null,
    );
    final inaccurate = event['inaccurate'] == true;
    final path = (event['path'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((p) {
          final lat = (p['lat'] as num?)?.toDouble();
          final lng = (p['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (path.length >= 2)
            SizedBox(
              height: 128,
              child: GoogleMap(
                key: ValueKey('trip-${event['startAt']}-${path.length}'),
                initialCameraPosition: CameraPosition(
                  target: path[path.length ~/ 2],
                  zoom: 13,
                ),
                liteModeEnabled: true,
                markers: {
                  Marker(
                    markerId: const MarkerId('start'),
                    position: path.first,
                  ),
                  Marker(
                    markerId: const MarkerId('finish'),
                    position: path.last,
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('trip'),
                    points: path,
                    color: AppColors.tealDeep,
                    width: 5,
                  ),
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
            )
          else
            Container(
              height: 64,
              color: AppColors.mint.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: const Text(
                'Perjalanan',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_fmtClock(start)} → ${_fmtClock(end)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _fmtDuration(dur),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TripEndpoint(
                  color: AppColors.success,
                  label: startLabel,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: AppColors.inkSoft.withValues(alpha: 0.35),
                  ),
                ),
                _TripEndpoint(
                  color: AppColors.coral,
                  label: endLabel,
                ),
                if (inaccurate) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Sinyal lemah — rute kurang akurat.',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripEndpoint extends StatelessWidget {
  const _TripEndpoint({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

String _friendlyPlaceName(String? raw, String? type) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty || RegExp(r'^\d{4,}$').hasMatch(name)) {
    if (type == 'home') return 'Rumah';
    if (type == 'school') return 'Sekolah';
    if (name == 'Berangkat' || name == 'Dalam perjalanan' || name == 'Tiba') {
      return name;
    }
    return type == 'custom' ? 'Tempat aman' : (name.isEmpty ? 'Tempat' : name);
  }
  return name;
}

String _fmtClock(DateTime? at) {
  if (at == null) return '--:--';
  return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

String _fmtDuration(int seconds) {
  if (seconds < 60) return '$seconds dtk';
  final m = seconds ~/ 60;
  if (m < 60) return '$m m';
  final h = m ~/ 60;
  final rem = m % 60;
  if (rem == 0) return '$h j';
  return '$h j $rem m';
}
