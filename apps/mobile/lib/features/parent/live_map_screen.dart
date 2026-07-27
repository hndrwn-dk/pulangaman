import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
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
  bool _atHome = false;
  String? _placeLabel;
  String? _alertId;
  String? _kabarBanner;
  Timer? _poll;
  Timer? _kabarClear;
  LatLng? _homeCenter;
  double _homeRadiusM = 120;
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _loadHomeZone();
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
    return distanceMeters(
          home.latitude,
          home.longitude,
          p.latitude,
          p.longitude,
        ) <=
        _homeRadiusM;
  }

  Future<void> _fetchHistory() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get(
        '/api/v1/children/${widget.child.id}/location/history',
        query: {'minutes': '120'},
      );
      final rawPoints = (data['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final lat = (p['lat'] as num?)?.toDouble();
            final lng = (p['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return LatLng(lat, lng);
          })
          .whereType<LatLng>()
          .toList();
      if (!mounted || rawPoints.isEmpty) return;

      final cleaned = _simplifyTrail(rawPoints);
      final last = rawPoints.last;
      final atHome = _isInsideHome(last);
      setState(() {
        _trail
          ..clear()
          ..addAll(atHome ? [last] : cleaned);
        _position = last;
        _atHome = atHome;
        _stale = false;
      });
      unawaited(_reverseGeocode(last));
      if (atHome) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(last, 16));
      } else {
        _fitTrail();
      }
    } catch (_) {}
  }

  /// Drop GPS jitter: keep points only if moved ~35m+, collapse home cluster.
  List<LatLng> _simplifyTrail(List<LatLng> points) {
    if (points.isEmpty) return points;
    final out = <LatLng>[points.first];
    for (final p in points.skip(1)) {
      if (_homeCenter != null && _isInsideHome(p)) {
        // Skip scribble while inside home — keep at most one home point.
        if (!_isInsideHome(out.last)) {
          out.add(p);
        } else {
          out[out.length - 1] = p;
        }
        continue;
      }
      final last = out.last;
      final moved = distanceMeters(
        last.latitude,
        last.longitude,
        p.latitude,
        p.longitude,
      );
      if (moved >= 35) out.add(p);
    }
    if (out.length > 120) {
      final step = (out.length / 120).ceil();
      final sampled = <LatLng>[];
      for (var i = 0; i < out.length; i += step) {
        sampled.add(out[i]);
      }
      if (sampled.last != out.last) sampled.add(out.last);
      return sampled;
    }
    return out;
  }

  void _appendTrail(LatLng position) {
    if (_atHome || _isInsideHome(position)) {
      // Freeze path at home — update marker only.
      if (_trail.isEmpty) {
        _trail.add(position);
      } else {
        _trail
          ..clear()
          ..add(position);
      }
      return;
    }
    if (_trail.isNotEmpty) {
      final last = _trail.last;
      final moved = distanceMeters(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved < 35) return;
    }
    _trail.add(position);
    if (_trail.length > 120) {
      _trail.removeRange(0, _trail.length - 120);
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
      final label = data['label'] as String?;
      if (!mounted || label == null) return;
      setState(() => _placeLabel = label);
    } catch (_) {}
  }

  void _updatePosition(LatLng position, {required bool stale, DateTime? at}) {
    final isFirst = _position == null;
    final atHome = _isInsideHome(position);
    final moved = isFirst ||
        distanceMeters(
              _position!.latitude,
              _position!.longitude,
              position.latitude,
              position.longitude,
            ) >=
            12;

    setState(() {
      _position = position;
      _stale = stale;
      _updatedAt = at ?? DateTime.now();
      _atHome = atHome;
      if (moved) _appendTrail(position);
    });
    if (moved) {
      unawaited(_reverseGeocode(position));
      if (!atHome) {
        _mapController?.animateCamera(
          isFirst
              ? CameraUpdate.newLatLngZoom(position, 15)
              : CameraUpdate.newLatLng(position),
        );
      }
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
      final l10n = AppLocalizations.of(context);
      final text = payload['text'] as String? ?? l10n.newKabarBanner;
      final name = payload['childName'] as String? ?? widget.child.name;
      setState(() => _kabarBanner = '$name: $text');
      _kabarClear?.cancel();
      _kabarClear = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _kabarBanner = null);
      });
    }
    if (event == 'parent:zone_event' &&
        payload['childId'] == widget.child.id) {
      final l10n = AppLocalizations.of(context);
      final isEnter = payload['event'] == 'enter';
      final message = payload['message'] as String? ??
          (isEnter
              ? l10n.childInSafeZoneMsg(widget.child.name)
              : l10n.leftSafeZoneMsg(widget.child.name));
      setState(() {
        _kabarBanner = message;
        if (isEnter) _atHome = payload['zoneType'] == 'home' || _atHome;
      });
      _kabarClear?.cancel();
      _kabarClear = Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() => _kabarBanner = null);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.tealDeep,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alertAcknowledged)),
      );
    }
  }

  Future<void> _resolve() async {
    if (_alertId == null) return;
    final l10n = AppLocalizations.of(context);
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/resolve', body: {
      'notes': l10n.resolvedByParentNote,
    });
    setState(() => _alertId = null);
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_position == null) return l10n.waitingGpsSignal;
    if (_atHome) return l10n.atHomeTrackingStopped;
    if (_stale) return l10n.locationNotUpdatedRecently;
    if (_updatedAt == null) return l10n.movingNow;
    final age = DateTime.now().difference(_updatedAt!);
    if (age.inSeconds < 20) return l10n.liveJustNow;
    if (age.inMinutes < 1) return l10n.liveSecondsAgo(age.inSeconds);
    return l10n.liveMinutesAgo(age.inMinutes);
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

  Future<void> _openSafeZones() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacesScreen(child: widget.child),
      ),
    );
    await _loadHomeZone();
    if (_position != null && mounted) {
      setState(() => _atHome = _isInsideHome(_position!));
    }
  }

  Widget _statusCard(AppLocalizations l10n, {required bool refresh}) {
    final dotColor = refresh
        ? (_atHome
            ? VisualRefreshColors.accent
            : _stale
                ? VisualRefreshColors.routeText
                : VisualRefreshColors.accent)
        : (_atHome
            ? AppColors.teal
            : _stale
                ? AppColors.amber
                : AppColors.success);
    final muted = refresh
        ? VisualRefreshColors.textSecondary
        : AppColors.inkSoft;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(refresh ? 18 : 16),
        border: refresh
            ? const Border.fromBorderSide(VisualRefreshColors.hairline)
            : null,
        boxShadow: refresh
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusLabel(l10n),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: refresh ? VisualRefreshColors.textPrimary : null,
                    ),
                  ),
                ),
                Text(
                  _atHome
                      ? l10n.homeZone
                      : _trail.length < 2
                          ? l10n.shortTrailLabel
                          : l10n.trailPointsCount(_trail.length),
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (_placeLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                _placeLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _safeZonesButton(AppLocalizations l10n, {required bool refresh}) {
    final label = Text(l10n.importantPlacesLabel);
    final icon = Icon(
      Icons.home_work_outlined,
      size: 18,
      color: refresh ? VisualRefreshColors.background : Colors.white,
    );
    if (refresh) {
      return FilledButton.icon(
        onPressed: _openSafeZones,
        style: FilledButton.styleFrom(
          backgroundColor: VisualRefreshColors.anchor,
          foregroundColor: VisualRefreshColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
        ),
        icon: icon,
        label: label,
      );
    }
    return FloatingActionButton.extended(
      onPressed: _openSafeZones,
      backgroundColor: AppColors.teal,
      label: label,
      icon: const Icon(Icons.home_work_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final center = _position ?? const LatLng(-6.2, 106.8);
    final trailColor =
        refresh ? VisualRefreshColors.accent : AppColors.teal;
    final polylines = <Polyline>{
      if (!_atHome && _trail.length >= 2)
        Polyline(
          polylineId: const PolylineId('trail'),
          points: List<LatLng>.from(_trail),
          color: trailColor,
          width: 5,
          geodesic: true,
        ),
    };

    final titleStyle = refresh
        ? Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: VisualRefreshColors.textPrimary,
            )
        : null;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : null,
      appBar: AppBar(
        backgroundColor:
            refresh ? VisualRefreshColors.background : null,
        surfaceTintColor: refresh ? Colors.transparent : null,
        scrolledUnderElevation: refresh ? 0 : null,
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        title: Text(
          '${l10n.liveMap} · ${widget.child.name}',
          style: titleStyle,
        ),
      ),
      body: Column(
        children: [
          if (_stale)
            MaterialBanner(
              content: Text(
                l10n.staleLocation,
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.routeText
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: refresh
                  ? VisualRefreshColors.routeTint
                  : const Color(0xFFFFF4E5),
              actions: [
                TextButton(
                  onPressed: _fetchLocation,
                  style: TextButton.styleFrom(
                    foregroundColor: refresh
                        ? VisualRefreshColors.accent
                        : null,
                  ),
                  child: Text(l10n.reloadTooltip),
                ),
              ],
            ),
          if (_alertId != null)
            MaterialBanner(
              content: Text(l10n.panicModeActiveWaiting),
              backgroundColor: refresh
                  ? VisualRefreshColors.dangerTint
                  : const Color(0xFFFEE4E2),
              actions: [
                TextButton(onPressed: _ack, child: Text(l10n.ackAlert)),
                TextButton(
                  onPressed: _resolve,
                  child: Text(l10n.resolveAlert),
                ),
              ],
            ),
          if (_kabarBanner != null)
            MaterialBanner(
              content: Text(_kabarBanner!),
              backgroundColor: refresh
                  ? VisualRefreshColors.accentTint
                  : const Color(0xFFE8F8F2),
              leading: Icon(
                Icons.chat_bubble,
                color: refresh
                    ? VisualRefreshColors.accent
                    : AppColors.teal,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _kabarBanner = null),
                  child: Text(l10n.closeAction),
                ),
              ],
            ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: center, zoom: 15),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_position != null) {
                  controller.animateCamera(
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
                      snippet:
                          _atHome ? l10n.statusHomeLabel : _placeLabel,
                    ),
                  ),
              },
              circles: _circles,
              polylines: polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: _safeZonesButton(l10n, refresh: refresh),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: _statusCard(l10n, refresh: refresh),
          ),
        ],
      ),
    );
  }
}
