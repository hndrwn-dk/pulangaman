import 'dart:async';

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
  LatLng? _position;
  bool _stale = true;
  String? _alertId;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _fetchLocation();
    final token = ref.read(authControllerProvider).token;
    if (token != null) {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      _ws.subscribe('child:${widget.child.id}');
    }
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLocation());
  }

  void _updatePosition(LatLng position, {required bool stale}) {
    final isFirst = _position == null;
    final moved = isFirst ||
        (_position!.latitude - position.latitude).abs() > 0.00001 ||
        (_position!.longitude - position.longitude).abs() > 0.00001;
    setState(() {
      _position = position;
      _stale = stale;
    });
    if (moved) {
      _mapController?.animateCamera(
        isFirst
            ? CameraUpdate.newLatLngZoom(position, 15)
            : CameraUpdate.newLatLng(position),
      );
    }
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:location_update' &&
        payload['childId'] == widget.child.id) {
      final lat = (payload['lat'] as num?)?.toDouble();
      final lng = (payload['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _updatePosition(LatLng(lat, lng), stale: false);
      }
    }
    if (event == 'child:panic_triggered') {
      setState(() => _alertId = payload['alertId'] as String?);
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
        _updatePosition(LatLng(lat, lng), stale: data['isStale'] == true);
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

  @override
  void dispose() {
    _poll?.cancel();
    _mapController?.dispose();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _position ?? const LatLng(-6.2, 106.8);

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
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: center, zoom: 15),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_position != null) {
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
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                if (_position != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.95),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          '${AppStrings.lastKnownCoords}: '
                          '${_position!.latitude.toStringAsFixed(5)}, '
                          '${_position!.longitude.toStringAsFixed(5)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 72,
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
