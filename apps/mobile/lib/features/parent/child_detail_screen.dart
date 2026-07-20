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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: center, zoom: 15),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Kembali',
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          elevation: 2,
                          child: IconButton(
                            onPressed: () {
                              if (_position == null) return;
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  _position!,
                                  _atHome ? 16 : 15,
                                ),
                              );
                            },
                            icon: const Icon(Icons.my_location),
                            tooltip: 'Pusatkan',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          elevation: 2,
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LiveMapScreen(child: widget.child),
                                ),
                              );
                            },
                            icon: const Icon(Icons.fullscreen),
                            tooltip: 'Peta penuh',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 56,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealDeep,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_statusBubble · $_whenLabel',
                        textAlign: TextAlign.center,
                        maxLines: 2,
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
            flex: 6,
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _fetchLocation(),
                    _fetchActivity(),
                    _loadHomeZone(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.inkSoft.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChildAvatar(
                          name: widget.child.name,
                          gender: _gender,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.child.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _stale
                                    ? 'Lokasi tidak baru'
                                    : (_atHome ? 'Di rumah' : 'Sedang dipantau'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _stale
                                      ? AppColors.amber
                                      : AppColors.tealDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_batteryLevel != null)
                          _BatteryChip(
                            level: _batteryLevel!,
                            charging: _batteryCharging,
                          ),
                      ],
                    ),
                    if (banner != null) ...[
                      const SizedBox(height: 12),
                      _AlertPill(
                        text: banner,
                        onTap: _fetchLocation,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Aksi cepat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.home_work_outlined,
                            label: 'Tempat aman',
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
                            icon: Icons.chat_bubble_outline,
                            label: 'Kabar',
                            onTap: _openKabar,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.phone_android,
                            label: 'Waktu HP',
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
                            icon: Icons.alarm,
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
                    Row(
                      children: [
                        Text(
                          'Hari ini',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _activityLoading ? null : _fetchActivity,
                          child: const Text('Muat ulang'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_activityLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
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
                      const SizedBox(height: 10),
                      if (_activityEvents.isEmpty)
                        const Text(
                          'Belum ada jejak hari ini. '
                          'Pastikan HP anak menyala dan mengirim lokasi.',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            height: 1.4,
                          ),
                        )
                      else
                        ..._activityEvents.map((e) {
                          final type = e['type'] as String?;
                          if (type == 'stay') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StayCard(event: e),
                            );
                          }
                          if (type == 'trip') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
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

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.level, required this.charging});

  final int level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final low = level <= 15 && !charging;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: low
            ? AppColors.coral.withValues(alpha: 0.12)
            : AppColors.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            charging ? Icons.battery_charging_full : Icons.battery_std,
            size: 18,
            color: low ? AppColors.coral : AppColors.tealDeep,
          ),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: low ? AppColors.coral : AppColors.tealDeep,
            ),
          ),
        ],
      ),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.amber, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    fontSize: 14,
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
    return Material(
      color: const Color(0xFFF7FAF9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.tealDeep, size: 26),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
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
    final placeLines = places.take(3).map((p) {
      final name = p['name'] as String? ?? 'Tempat';
      final secs = (p['durationSeconds'] as num?)?.toInt() ?? 0;
      return '$name: ${_fmtDuration(secs)}';
    }).join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.teal, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$placeCount tempat',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                if (placeLines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    placeLines,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.route, color: AppColors.teal, size: 20),
                const SizedBox(height: 6),
                Text(
                  distM >= 1000
                      ? '${(distM / 1000).toStringAsFixed(1)} km'
                      : '${distM.round()} m',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Perjalanan',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final name = event['placeName'] as String? ?? 'Tempat';
    final type = event['placeType'] as String? ?? 'custom';
    final start = DateTime.tryParse(event['startAt'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(event['endAt'] as String? ?? '')?.toLocal();
    final dur = (event['durationSeconds'] as num?)?.toInt() ?? 0;
    final icon = type == 'home'
        ? Icons.home_rounded
        : type == 'school'
            ? Icons.school_rounded
            : Icons.place_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22075A4F)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
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
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtClock(start)} — ${_fmtClock(end)} (${_fmtDuration(dur)})',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final startLabel = event['startLabel'] as String? ?? 'Berangkat';
    final endLabel = event['endLabel'] as String? ?? 'Tiba';
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22075A4F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (path.length >= 2)
            SizedBox(
              height: 120,
              child: GoogleMap(
                key: ValueKey(
                  'trip-${event['startAt']}-${path.length}',
                ),
                initialCameraPosition: CameraPosition(
                  target: path[path.length ~/ 2],
                  zoom: 13,
                ),
                liteModeEnabled: true,
                markers: {
                  Marker(
                    markerId: const MarkerId('start'),
                    position: path.first,
                    infoWindow: const InfoWindow(title: 'START'),
                  ),
                  Marker(
                    markerId: const MarkerId('finish'),
                    position: path.last,
                    infoWindow: const InfoWindow(title: 'FINISH'),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('trip'),
                    points: path,
                    color: AppColors.teal,
                    width: 4,
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
              height: 72,
              color: AppColors.mint.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: const Text(
                'Rute',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmtClock(start)} → ${_fmtClock(end)} (${_fmtDuration(dur)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        startLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 2,
                    height: 10,
                    color: AppColors.inkSoft.withValues(alpha: 0.4),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        endLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (inaccurate) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Rute kurang akurat karena sinyal HP lemah.',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      height: 1.3,
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
