import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';
import 'zones_screen.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final _ws = WsClient();
  GoogleMapController? _mapController;
  final List<LatLng> _trail = [];
  LatLng? _position;
  DateTime? _updatedAt;
  bool _stale = true;
  String? _alertId;
  String? _kabarBanner;
  Timer? _poll;
  Timer? _kabarClear;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _fetchHistory();
    await _fetchLocation();
    final token = ref.read(authControllerProvider).token;
    if (token != null) {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      _ws.subscribe('child:${widget.child.id}');
    }
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLocation());
  }

  Future<void> _fetchHistory() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get(
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
          ..addAll(_downsample(points));
        _position = points.last;
        _stale = false;
      });
      _fitTrail();
    } catch (_) {
      // History may be empty for new children.
    }
  }

  List<LatLng> _downsample(List<LatLng> points) {
    if (points.length <= 300) return points;
    final step = (points.length / 300).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      out.add(points[i]);
    }
    if (out.last != points.last) out.add(points.last);
    return out;
  }

  void _appendTrail(LatLng position) {
    if (_trail.isNotEmpty) {
      final last = _trail.last;
      final dLat = (last.latitude - position.latitude).abs();
      final dLng = (last.longitude - position.longitude).abs();
      // ~1m threshold — skip near-duplicates.
      if (dLat < 0.00001 && dLng < 0.00001) return;
    }
    _trail.add(position);
    if (_trail.length > 400) {
      _trail.removeRange(0, _trail.length - 400);
    }
  }

  void _updatePosition(LatLng position, {required bool stale, DateTime? at}) {
    final isFirst = _position == null;
    final moved = isFirst ||
        (_position!.latitude - position.latitude).abs() > 0.00001 ||
        (_position!.longitude - position.longitude).abs() > 0.00001;
    setState(() {
      _position = position;
      _stale = stale;
      _updatedAt = at ?? DateTime.now();
      if (moved) _appendTrail(position);
    });
    if (moved) {
      _mapController?.animateCamera(
        isFirst
            ? CameraUpdate.newLatLngZoom(position, 15)
            : CameraUpdate.newLatLng(position),
      );
    }
  }

  void _fitTrail() {
    if (_mapController == null || _trail.isEmpty) return;
    if (_trail.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_trail.first, 15),
      );
      return;
    }
    var minLat = _trail.first.latitude;
    var maxLat = _trail.first.latitude;
    var minLng = _trail.first.longitude;
    var maxLng = _trail.first.longitude;
    for (final p in _trail) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:location_update' &&
        payload['childId'] == widget.child.id) {
      final lat = (payload['lat'] as num?)?.toDouble();
      final lng = (payload['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final recorded = payload['recordedAt'] as String?;
        _updatePosition(
          LatLng(lat, lng),
          stale: false,
          at: recorded != null ? DateTime.tryParse(recorded) : null,
        );
      }
    }
    if (event == 'child:panic_triggered') {
      setState(() => _alertId = payload['alertId'] as String?);
    }
    if (event == 'child:message' && payload['childId'] == widget.child.id) {
      final text = payload['text'] as String? ?? 'Kabar baru';
      final name = payload['childName'] as String? ?? widget.child.name;
      setState(() => _kabarBanner = '$name: $text');
      _kabarClear?.cancel();
      _kabarClear = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _kabarBanner = null);
      });
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/children/${widget.child.id}/location');
      final loc = data['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final recorded = loc?['recordedAt'] as String?;
        _updatePosition(
          LatLng(lat, lng),
          stale: data['isStale'] == true,
          at: recorded != null ? DateTime.tryParse(recorded) : null,
        );
      } else {
        setState(() => _stale = true);
      }
    } catch (_) {
      setState(() => _stale = true);
    }
  }

  Future<void> _ack() async {
    if (_alertId == null) return;
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/ack');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peringatan direspons')),
      );
    }
  }

  Future<void> _resolve() async {
    if (_alertId == null) return;
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/resolve', body: {
      'notes': 'Diselesaikan orang tua',
    });
    setState(() => _alertId = null);
  }

  String _statusLabel() {
    if (_position == null) return 'Menunggu sinyal lokasi...';
    if (_stale) return 'Lokasi tidak diperbarui baru-baru ini';
    if (_updatedAt == null) return 'Live';
    final age = DateTime.now().difference(_updatedAt!);
    if (age.inSeconds < 20) return 'Live · baru saja';
    if (age.inMinutes < 1) return 'Live · ${age.inSeconds}d lalu';
    return 'Live · ${age.inMinutes} mnt lalu';
  }

  @override
  void dispose() {
    _poll?.cancel();
    _kabarClear?.cancel();
    _mapController?.dispose();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _position ?? const LatLng(-6.2, 106.8);
    final polylines = <Polyline>{
      if (_trail.length >= 2)
        Polyline(
          polylineId: const PolylineId('trail'),
          points: List<LatLng>.from(_trail),
          color: AppColors.teal,
          width: 5,
          geodesic: true,
        ),
    };

    return Scaffold(
      appBar: AppBar(title: Text('${AppStrings.liveMap} · ${widget.child.name}')),
      body: Column(
        children: [
          if (_stale)
            MaterialBanner(
              content: const Text(AppStrings.staleLocation),
              backgroundColor: const Color(0xFFFFF4E5),
              actions: [
                TextButton(onPressed: _fetchLocation, child: const Text('Muat ulang')),
              ],
            ),
          if (_alertId != null)
            MaterialBanner(
              content: const Text('PANIK aktif — hubungi anak / darurat'),
              backgroundColor: const Color(0xFFFEE4E2),
              actions: [
                TextButton(onPressed: _ack, child: const Text(AppStrings.ackAlert)),
                TextButton(onPressed: _resolve, child: const Text(AppStrings.resolveAlert)),
              ],
            ),
          if (_kabarBanner != null)
            MaterialBanner(
              content: Text(_kabarBanner!),
              backgroundColor: const Color(0xFFE8F8F2),
              leading: const Icon(Icons.chat_bubble, color: AppColors.teal),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _kabarBanner = null),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: center, zoom: 15),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_trail.length >= 2) {
                      _fitTrail();
                    } else if (_position != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_position!, 15),
                      );
                    }
                  },
                  markers: {
                    if (_position != null)
                      Marker(
                        markerId: MarkerId(widget.child.id),
                        position: _position!,
                        infoWindow: InfoWindow(title: widget.child.name),
                      ),
                  },
                  polylines: polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.96),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _stale ? AppColors.amber : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusLabel(),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                '${_trail.length} titik',
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (_position != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_position!.latitude.toStringAsFixed(5)}, '
                              '${_position!.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: AppColors.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 96,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ZonesScreen(child: widget.child),
                        ),
                      );
                    },
                    backgroundColor: AppColors.teal,
                    label: const Text(AppStrings.zonesTitle),
                    icon: const Icon(Icons.fence),
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
