import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../child/child_usage_utils.dart';
import '../screentime/screen_time_screen.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'home_by_screen.dart';
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'kabar_read_store.dart';
import 'live_map_screen.dart';
import 'reminders_screen.dart';
import 'zones_screen.dart';

/// Find My Kids–inspired child hub: map + inline summaries + daily timeline.
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

class _ZoneSummary {
  const _ZoneSummary({
    required this.id,
    required this.type,
    required this.name,
    this.lat,
    this.lng,
  });

  final String id;
  final String type;
  final String name;
  final double? lat;
  final double? lng;

  String displayName(AppLocalizations l10n) {
    if (name.trim().isNotEmpty) return name.trim();
    if (type == 'home') return l10n.homeZone;
    if (type == 'school') return l10n.schoolZone;
    return l10n.safePlaceLabel;
  }
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  final _ws = WsClient();
  final _kabarRead = KabarReadStore();
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

  List<_ZoneSummary> _zones = [];
  List<ChildKabarMessage> _kabar = [];
  int _kabarUnread = 0;
  int _screenUsedSeconds = 0;
  int _screenLimitMinutes = 180;
  bool _screenEnabled = true;
  List<ChildReminder> _reminders = [];
  String _homeByMode = 'off';
  String? _homeByStatus;
  String? _homeByTargetLabel;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;
    _kabar = widget.initialKabar
        .where((m) => m.childId == widget.child.id)
        .toList();
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
    await Future.wait([
      _loadHomeZone(),
      _fetchLocation(),
      _fetchActivity(),
      _fetchHistory(),
      _fetchSummaries(),
    ]);
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

  Future<void> _fetchSummaries() async {
    await Future.wait([
      _loadZonesSummary(),
      _loadKabarSummary(),
      _loadScreenTimeSummary(),
      _loadRemindersSummary(),
      _loadHomeBySummary(),
    ]);
  }

  Future<void> _loadZonesSummary() async {
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/zones',
        query: {'childId': widget.child.id},
      );
      final zones = (data['zones'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((z) {
            return _ZoneSummary(
              id: z['id'] as String? ?? '',
              type: z['type'] as String? ?? 'custom',
              name: z['name'] as String? ?? '',
              lat: (z['lat'] as num?)?.toDouble(),
              lng: (z['lng'] as num?)?.toDouble(),
            );
          })
          .where((z) => z.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _zones = zones);
    } catch (_) {}
  }

  Future<void> _loadKabarSummary() async {
    try {
      await _kabarRead.load();
      final data = await ref.read(apiClientProvider).get('/api/v1/messages');
      final all = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildKabarMessage.fromJson)
          .where((m) => m.childId == widget.child.id)
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (!mounted) return;
      setState(() {
        _kabar = all;
        _kabarUnread = _kabarRead.unreadOf(all).length;
      });
    } catch (_) {
      if (!mounted) return;
      await _kabarRead.load();
      setState(() {
        _kabarUnread = _kabarRead.unreadOf(_kabar).length;
      });
    }
  }

  Future<void> _loadScreenTimeSummary() async {
    try {
      final api = ref.read(apiClientProvider);
      final policyRes = await api.get('/api/v1/policies/${widget.child.id}');
      final policy = policyRes['policy'] as Map<String, dynamic>?;
      final summary =
          await api.get('/api/v1/telemetry/${widget.child.id}/summary');
      final used = (summary['apps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .fold<int>(
            0,
            (sum, a) => sum + ((a['duration_seconds'] as num?)?.toInt() ?? 0),
          );
      final parsed = _parseScreenPolicy(policy);
      if (!mounted) return;
      setState(() {
        _screenUsedSeconds = used;
        _screenLimitMinutes = parsed.limitMinutes;
        _screenEnabled = parsed.enabled;
      });
    } catch (_) {}
  }

  ({bool enabled, int limitMinutes}) _parseScreenPolicy(
    Map<String, dynamic>? current,
  ) {
    if (current == null) {
      return (enabled: true, limitMinutes: 180);
    }
    final enabled = current['enabled'] == true;
    final limit = (current['daily_limit_minutes'] as num?)?.toInt() ?? 180;
    final schedules = (current['schedules'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    var schoolOn = false;
    var weekendOn = false;
    int? schoolLimit;
    int? weekendLimit;
    for (final s in schedules) {
      final days = (s['days'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final lim = (s['limitMinutes'] as num?)?.toInt() ??
          (s['limit_minutes'] as num?)?.toInt();
      final isSchool = days.any((d) => d >= 1 && d <= 5);
      final isWeekend = days.any((d) => d == 6 || d == 7);
      if (isSchool) {
        schoolOn = true;
        if (lim != null) schoolLimit = lim;
      }
      if (isWeekend) {
        weekendOn = true;
        if (lim != null) weekendLimit = lim;
      }
    }
    if (schedules.isEmpty) {
      schoolOn = true;
      weekendOn = true;
      schoolLimit = limit <= 180 ? limit : 180;
      weekendLimit = limit > 180 ? limit : 300;
    }
    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final active = isWeekend
        ? (weekendOn ? (weekendLimit ?? 300) : (schoolLimit ?? 180))
        : (schoolOn ? (schoolLimit ?? 180) : (weekendLimit ?? 300));
    return (enabled: enabled, limitMinutes: active);
  }

  Future<void> _loadRemindersSummary() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/reminders/${widget.child.id}');
      final list = (data['reminders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildReminder.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _reminders = list);
    } catch (_) {}
  }

  Future<void> _loadHomeBySummary() async {
    try {
      final api = ref.read(apiClientProvider);
      final id = widget.child.id;
      final settingsRes = await api.get('/api/v1/home-by/$id');
      final todayRes = await api.get('/api/v1/home-by/$id/today');
      final s = settingsRes['settings'] as Map<String, dynamic>? ?? {};
      final today = todayRes['today'] as Map<String, dynamic>?;
      String? targetLabel;
      final raw = today?['targetTime'] as String?;
      if (raw != null) {
        final at = DateTime.tryParse(raw)?.toLocal();
        if (at != null) {
          targetLabel =
              '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
        }
      }
      if (!mounted) return;
      setState(() {
        _homeByMode = s['mode'] as String? ?? 'off';
        _homeByStatus = today?['status'] as String?;
        _homeByTargetLabel = targetLabel;
        if (_homeByMode == 'custom') {
          final h = (s['customHour'] as num?)?.toInt();
          final m = (s['customMinute'] as num?)?.toInt();
          if (h != null && m != null) {
            _homeByTargetLabel ??=
                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _openHomeBy() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeByScreen(
          lockedChild: widget.child,
          readOnly: widget.child.isViewOnlyAccess,
        ),
      ),
    );
    await _loadHomeBySummary();
  }

  Future<void> _editGender() async {
    final picked = await showChildGenderPicker(
      context: context,
      childName: widget.child.name,
      current: _gender,
    );
    if (picked == null || !mounted) return;
    await ChildGenderStore.instance.set(widget.child.id, picked);
    if (!mounted) return;
    setState(() => _gender = picked);
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
        _activityError = AppLocalizations.of(context).activityLoadFailed;
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
    if ((event == 'parent:home_by_status' || event == 'parent:home_by_ack') &&
        payload['childId'] == widget.child.id) {
      unawaited(_loadHomeBySummary());
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

  String _statusBubble(AppLocalizations l10n) {
    if (_atHome) return l10n.statusHomeLabel;
    if (_placeLabel != null && _placeLabel!.isNotEmpty) {
      return _placeLabel!;
    }
    if (_position == null) return l10n.waitingLocationDots;
    return l10n.seenOnMap;
  }

  String _whenLabel(AppLocalizations l10n) {
    final at = _updatedAt;
    if (at == null) return l10n.noSignalYet;
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return l10n.updatedAtTime(hm);
  }

  String? _batteryBannerText(AppLocalizations l10n) {
    switch (_batteryAlert) {
      case 'dead':
        return l10n.batteryDeadBanner;
      case 'low':
        return l10n.batteryLowBanner('${_batteryLevel ?? '?'}');
      case 'stale':
        return l10n.locationStaleBanner;
      default:
        if (_batteryLevel != null && _batteryLevel! <= 15 && !_batteryCharging) {
          return l10n.batteryLowBanner('$_batteryLevel');
        }
        return null;
    }
  }

  void _openKabar() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => KabarInboxScreen(
          messages: List<ChildKabarMessage>.from(_kabar),
          initialChildId: widget.child.id,
          childNames: {widget.child.id: widget.child.name},
          unreadIds: {
            for (final m in _kabar)
              if (_kabarRead.isUnread(m)) m.id,
          },
          onMarkAllRead: () async {
            await _kabarRead.markAllRead();
            if (mounted) {
              setState(() {
                _kabarUnread = _kabarRead.unreadOf(_kabar).length;
              });
            }
          },
        ),
      ),
    )
        .then((_) {
      if (mounted) unawaited(_loadKabarSummary());
    });
  }

  Future<void> _openZones() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacesScreen(child: widget.child),
      ),
    );
    await Future.wait([_loadHomeZone(), _loadZonesSummary()]);
  }

  Future<void> _openScreenTime() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreenTimeScreen(
          lockedChild: widget.child,
          showBack: true,
        ),
      ),
    );
    await _loadScreenTimeSummary();
  }

  Future<void> _openReminders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemindersScreen(
          initialChildId: widget.child.id,
          lockChild: true,
        ),
      ),
    );
    await _loadRemindersSummary();
  }

  int get _activeZoneCount {
    var n = 0;
    for (final z in _zones) {
      if (z.type == 'home' && _atHome) n++;
    }
    return n;
  }

  bool _zoneIsActive(_ZoneSummary z) => z.type == 'home' && _atHome;

  String _zoneBody(AppLocalizations l10n, {required bool refresh}) {
    if (_zones.isEmpty) return l10n.noZonesYet;
    if (refresh) {
      return l10n.zonesSummaryActiveCount(_zones.length, _activeZoneCount);
    }
    _ZoneSummary? home;
    for (final z in _zones) {
      if (z.type == 'home') {
        home = z;
        break;
      }
    }
    if (_atHome && home != null) {
      return l10n.zoneNameActive(home.displayName(l10n));
    }
    if (home != null) {
      return l10n.zoneNameWithCount(home.displayName(l10n), _zones.length);
    }
    return l10n.safeZonesCount(_zones.length);
  }

  String? _zoneDetail(AppLocalizations l10n, {required bool refresh}) {
    if (_zones.isEmpty) return l10n.addHomeOrSchoolHint;
    if (refresh) return null;
    return l10n.zonesSummaryActiveCount(_zones.length, _activeZoneCount);
  }

  String _kabarBody(AppLocalizations l10n) {
    if (_kabar.isEmpty) return l10n.noKabarYet;
    final latest = _kabar.first;
    final clock =
        '${latest.sentAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${latest.sentAt.toLocal().minute.toString().padLeft(2, '0')}';
    return '${latest.text} · $clock';
  }

  String? _kabarDetail(AppLocalizations l10n) {
    if (_kabarUnread <= 0) return null;
    return l10n.unreadKabarCount(_kabarUnread);
  }

  String _screenBody(AppLocalizations l10n) {
    if (!_screenEnabled) return l10n.screenLimitsOff;
    final used = formatDurationCompact(_screenUsedSeconds);
    final limit = _fmtLimitCompact(_screenLimitMinutes);
    return l10n.screenUsedToday(used, limit);
  }

  double get _screenProgress {
    final limitSec = _screenLimitMinutes * 60;
    if (limitSec <= 0) return 0;
    return (_screenUsedSeconds / limitSec).clamp(0.0, 1.0);
  }

  String _reminderBody(AppLocalizations l10n) {
    final active = _reminders.where((r) => r.enabled).toList();
    if (active.isEmpty) {
      return _reminders.isEmpty
          ? l10n.noRemindersYet
          : l10n.remindersNoneActive;
    }
    final next = _nextReminder(active);
    if (next == null) return l10n.remindersActiveCount(active.length);
    return l10n.remindersActiveNext(
      active.length,
      next.title,
      next.timeLabel,
    );
  }

  String _homeBySummaryBody(AppLocalizations l10n) {
    if (_homeByMode == 'off') return l10n.homeBySummaryOff;
    final status = _homeByStatusLabel(l10n, _homeByStatus);
    if (_homeByMode == 'maghrib') {
      return l10n.homeBySummaryMaghrib(status);
    }
    final time = _homeByTargetLabel ?? '--:--';
    return l10n.homeBySummaryCustom(time, status);
  }

  String _homeByStatusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'pre_notified':
        return l10n.homeByStatusPreNotified;
      case 'target_notified':
        return l10n.homeByStatusTargetNotified;
      case 'grace_notified':
        return l10n.homeByStatusGraceNotified;
      case 'resolved':
        return l10n.homeByStatusResolved;
      case 'skipped':
        return l10n.homeByStatusSkipped;
      case 'pending':
        return l10n.homeByStatusPending;
      default:
        // Mode is configured but not actively monitoring yet.
        return l10n.homeBySummaryNotTurnedOn;
    }
  }

  ChildReminder? _nextReminder(List<ChildReminder> active) {
    final now = DateTime.now();
    ChildReminder? best;
    Duration? bestDelta;
    for (final r in active) {
      final days = r.daysOfWeek.isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : r.daysOfWeek;
      for (var offset = 0; offset < 8; offset++) {
        final day = now.add(Duration(days: offset));
        final weekday = day.weekday; // 1=Mon .. 7=Sun
        if (!days.contains(weekday)) continue;
        final at = DateTime(day.year, day.month, day.day, r.hour, r.minute);
        if (!at.isAfter(now)) continue;
        final delta = at.difference(now);
        if (bestDelta == null || delta < bestDelta) {
          bestDelta = delta;
          best = r;
        }
        break;
      }
    }
    return best;
  }

  String _fmtLimitCompact(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60}j';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}j ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final center = _position ?? const LatLng(-6.2, 106.8);
    final polylines = <Polyline>{
      if (!_atHome && _trail.length >= 2)
        Polyline(
          polylineId: const PolylineId('trail'),
          points: List<LatLng>.from(_trail),
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          width: 4,
          geodesic: true,
        ),
    };
    final banner = _batteryBannerText(l10n);
    final mapHeight = MediaQuery.sizeOf(context).height * 0.36;
    final statusLine = _stale
        ? l10n.locationCannotUpdate
        : (_atHome ? l10n.statusHomeLabel : l10n.beingMonitored);
    final pillFill =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;

    // Sheet peeks 28px over the map; clipped so scroll never paints over it.
    const sheetOverlap = 28.0;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                              ? _statusBubble(l10n)
                              : '${l10n.batteryPercentLabel(_batteryLevel!)}'
                                  '${_batteryCharging ? l10n.chargingShortSuffix : ''}',
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
                    padding: const EdgeInsets.fromLTRB(
                      PaScreenHeader.edgePad,
                      6,
                      PaScreenHeader.edgePad,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PaRoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            PaRoundIconButton(
                              icon: Icons.gps_fixed_rounded,
                              iconColor: refresh
                                  ? VisualRefreshColors.accent
                                  : const Color(0xFFE85A7A),
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
                            PaRoundIconButton(
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
                        color: pillFill,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: refresh
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.tealDeep
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Text(
                        '${_statusBubble(l10n)} · ${_whenLabel(l10n)}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          fontFamily: refresh
                              ? GoogleFonts.plusJakartaSans().fontFamily
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: mapHeight - sheetOverlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: RefreshIndicator(
                color: refresh ? VisualRefreshColors.accent : AppColors.teal,
                onRefresh: () async {
                  await Future.wait([
                    _fetchLocation(),
                    _fetchActivity(),
                    _loadHomeZone(),
                    _fetchSummaries(),
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
                      onEditGender: _editGender,
                      refresh: refresh,
                    ),
                    const SizedBox(height: 14),
                    _FeatureSummaryCard(
                      title: l10n.safeZoneFeatureTitle,
                      body: _zoneBody(l10n, refresh: refresh),
                      detail: _zoneDetail(l10n, refresh: refresh),
                      onOpen: _openZones,
                      refresh: refresh,
                      chips: _zones.isEmpty
                          ? const []
                          : [
                              for (final z in _zones.take(3))
                                _MiniZoneChip(
                                  label: _zoneIsActive(z)
                                      ? l10n.zoneNameActive(
                                          z.displayName(l10n),
                                        )
                                      : z.displayName(l10n),
                                  active: _zoneIsActive(z),
                                  refresh: refresh,
                                ),
                            ],
                    ),
                    const SizedBox(height: 10),
                    _FeatureSummaryCard(
                      title: l10n.parentKabarFeatureTitle,
                      body: _kabarBody(l10n),
                      detail: _kabarDetail(l10n),
                      onOpen: _openKabar,
                      refresh: refresh,
                    ),
                    const SizedBox(height: 10),
                    _FeatureSummaryCard(
                      title: l10n.screenTimeTitle,
                      body: _screenBody(l10n),
                      onOpen: _openScreenTime,
                      refresh: refresh,
                      progress: _screenEnabled ? _screenProgress : null,
                      progressCaption: _screenEnabled
                          ? l10n.limitCaptionShort(
                              _fmtLimitCompact(_screenLimitMinutes),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _FeatureSummaryCard(
                      title: l10n.remindersFeatureTitle,
                      body: _reminderBody(l10n),
                      onOpen: _openReminders,
                      refresh: refresh,
                    ),
                    const SizedBox(height: 10),
                    _FeatureSummaryCard(
                      title: l10n.homeByTitle,
                      body: _homeBySummaryBody(l10n),
                      onOpen: _openHomeBy,
                      linkLabel: l10n.homeBySeeAll,
                      refresh: refresh,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      refresh
                          ? l10n.todaySectionTitle.toUpperCase()
                          : l10n.todaySectionTitle,
                      style: refresh
                          ? GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: VisualRefreshColors.textTertiary,
                            )
                          : const TextStyle(
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
                        style: TextStyle(
                          color: refresh
                              ? VisualRefreshColors.danger
                              : AppColors.coral,
                        ),
                      )
                    else ...[
                      if (_activitySummary != null)
                        _ActivitySummaryRow(
                          summary: _activitySummary!,
                          refresh: refresh,
                        ),
                      const SizedBox(height: 12),
                      if (_activityEvents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),
                          decoration: _cardDecoration(refresh),
                          child: Text(
                            l10n.noTrailToday,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
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
                              refresh: refresh,
                            );
                          }
                          if (type == 'trip') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TripCard(event: e, refresh: refresh),
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

BoxDecoration _cardDecoration(bool refresh) {
  if (refresh) {
    return BoxDecoration(
      color: VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      border: Border.all(color: VisualRefreshColors.border, width: 0.5),
    );
  }
  return BoxDecoration(
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
    required this.onEditGender,
    this.refresh = false,
  });

  final String name;
  final ChildGender gender;
  final String statusLine;
  final bool stale;
  final String? banner;
  final int? batteryLevel;
  final bool batteryCharging;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditGender;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final staleDot =
        refresh ? VisualRefreshColors.routeText : const Color(0xFFE8A11A);
    final staleText =
        refresh ? VisualRefreshColors.routeText : const Color(0xFFC46A0A);
    final liveDot = refresh ? VisualRefreshColors.accent : AppColors.teal;
    final liveText =
        refresh ? VisualRefreshColors.accent : AppColors.tealDeep;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 12, refresh ? 14 : 16),
      decoration: _cardDecoration(refresh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEditGender,
                  child: ChildAvatar(
                    name: name,
                    gender: gender,
                    size: 52,
                    showEditBadge: !refresh,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: refresh
                          ? GoogleFonts.fraunces(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              height: 1.15,
                              color: VisualRefreshColors.textPrimary,
                            )
                          : const TextStyle(
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
                            color: stale ? staleDot : liveDot,
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
                              color: stale ? staleText : liveText,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!refresh) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onEditGender,
                        child: Text(
                          AppLocalizations.of(context).changeAvatarAction,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDeep,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Material(
                color: refresh
                    ? VisualRefreshColors.surface
                    : const Color(0xFFF3F5F7),
                shape: CircleBorder(
                  side: refresh
                      ? const BorderSide(
                          color: VisualRefreshColors.border,
                          width: 0.5,
                        )
                      : BorderSide.none,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onRefresh(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: refresh
                          ? VisualRefreshColors.textSecondary
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (banner != null) ...[
            const SizedBox(height: 12),
            _AlertPill(
              text: banner!,
              onTap: () => onRefresh(),
              refresh: refresh,
            ),
          ],
          const SizedBox(height: 14),
          _BatteryMeter(
            level: batteryLevel,
            charging: batteryCharging,
            refresh: refresh,
          ),
        ],
      ),
    );
  }
}

class _BatteryMeter extends StatelessWidget {
  const _BatteryMeter({
    required this.level,
    required this.charging,
    this.refresh = false,
  });

  final int? level;
  final bool charging;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = level;
    final known = value != null;
    final low = known && value <= 15 && !charging;
    final pct = known ? (value.clamp(0, 100) / 100.0) : 0.0;
    final color = low
        ? (refresh ? VisualRefreshColors.danger : AppColors.coral)
        : (refresh ? VisualRefreshColors.accent : AppColors.teal);
    final track = refresh
        ? VisualRefreshColors.tagMuted
        : const Color(0xFFE8ECF0);

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
                l10n.batteryMetricLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: low
                      ? (refresh ? VisualRefreshColors.danger : AppColors.coral)
                      : (refresh
                          ? VisualRefreshColors.textPrimary
                          : AppColors.ink),
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ),
            if (known)
              Text(
                charging
                    ? '$value%${l10n.chargingShortSuffix}'
                    : '$value%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: color,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              )
            else
              Text(
                l10n.batteryUnknown,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
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
            backgroundColor: track,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AlertPill extends StatelessWidget {
  const _AlertPill({
    required this.text,
    required this.onTap,
    this.refresh = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final bg = refresh
        ? VisualRefreshColors.routeTint
        : const Color(0xFFFFF3E6);
    final fg = refresh
        ? VisualRefreshColors.routeText
        : const Color(0xFF9A5B00);
    final icon = refresh
        ? VisualRefreshColors.routeText
        : const Color(0xFFD97706);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(refresh ? AppRadius.vrChip : 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrChip : 14),
        child: Container(
          decoration: refresh
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.vrChip),
                  border: Border.all(
                    color: VisualRefreshColors.routeText.withValues(alpha: 0.28),
                    width: 0.5,
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    fontSize: 13,
                    color: fg,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
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

class _FeatureSummaryCard extends StatelessWidget {
  const _FeatureSummaryCard({
    required this.title,
    required this.body,
    required this.onOpen,
    this.detail,
    this.progress,
    this.progressCaption,
    this.chips = const [],
    this.linkLabel,
    this.refresh = false,
  });

  final String title;
  final String body;
  final String? detail;
  final VoidCallback onOpen;
  final double? progress;
  final String? progressCaption;
  final List<Widget> chips;
  final String? linkLabel;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seeAll = linkLabel ?? l10n.homeBySeeAll;

    if (refresh) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: VisualRefreshColors.textTertiary,
                      ),
                    ),
                  ),
                  Text(
                    seeAll,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: VisualRefreshColors.accent,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: VisualRefreshColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(AppRadius.vrCard),
              child: Ink(
                width: double.infinity,
                decoration: _cardDecoration(true),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: _featureBody(
                    body: body,
                    detail: detail,
                    progress: progress,
                    progressCaption: progressCaption,
                    chips: chips,
                    refresh: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: _cardDecoration(false).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      seeAll,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.tealDeep.withValues(alpha: 0.95),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.tealDeep.withValues(alpha: 0.95),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _featureBody(
                  body: body,
                  detail: detail,
                  progress: progress,
                  progressCaption: progressCaption,
                  chips: chips,
                  refresh: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _featureBody({
  required String body,
  required String? detail,
  required double? progress,
  required String? progressCaption,
  required List<Widget> chips,
  required bool refresh,
}) {
  final track = refresh
      ? VisualRefreshColors.tagMuted
      : const Color(0xFFE8ECF0);
  final fill = refresh
      ? ((progress ?? 0) >= 1.0
          ? VisualRefreshColors.danger
          : VisualRefreshColors.accent)
      : ((progress ?? 0) >= 1.0 ? AppColors.coral : AppColors.teal);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          height: 1.25,
          color: refresh ? VisualRefreshColors.textPrimary : AppColors.ink,
          fontFamily:
              refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
        ),
      ),
      if (detail != null && detail.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            color: refresh
                ? VisualRefreshColors.textSecondary
                : AppColors.inkSoft,
            fontFamily:
                refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
          ),
        ),
      ],
      if (progress != null) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: track,
            color: fill,
          ),
        ),
        if (progressCaption != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progressCaption,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : AppColors.inkSoft,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
          ),
        ],
      ],
      if (chips.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: chips,
        ),
      ],
    ],
  );
}

class _MiniZoneChip extends StatelessWidget {
  const _MiniZoneChip({
    required this.label,
    this.active = false,
    this.refresh = false,
  });

  final String label;
  final bool active;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    if (refresh) {
      bg = active ? VisualRefreshColors.accentTint : VisualRefreshColors.surface;
      border =
          active ? VisualRefreshColors.accent : VisualRefreshColors.border;
      fg = active
          ? VisualRefreshColors.accent
          : VisualRefreshColors.textSecondary;
    } else {
      bg = active
          ? AppColors.teal.withValues(alpha: 0.12)
          : const Color(0xFFF3F5F7);
      border = active ? AppColors.teal : const Color(0xFFE2E6EA);
      fg = active ? AppColors.tealDeep : AppColors.inkSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrChip : 8),
        border: Border.all(color: border, width: refresh ? 0.5 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: fg,
          fontFamily:
              refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
        ),
      ),
    );
  }
}

class _ActivitySummaryRow extends StatelessWidget {
  const _ActivitySummaryRow({
    required this.summary,
    this.refresh = false,
  });

  final Map<String, dynamic> summary;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            label: l10n.placesCountLabel,
            refresh: refresh,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryStat(
            value: distLabel,
            label: l10n.tripGenericLabel,
            refresh: refresh,
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
    this.refresh = false,
  });

  final String value;
  final String label;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _cardDecoration(refresh),
      child: Column(
        crossAxisAlignment: refresh
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: refresh ? TextAlign.center : TextAlign.start,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontWeight: FontWeight.w600,
                    fontSize: 28,
                    height: 1.05,
                    letterSpacing: -0.8,
                    color: VisualRefreshColors.textPrimary,
                  )
                : const TextStyle(
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
            textAlign: refresh ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: refresh
                  ? VisualRefreshColors.textSecondary
                  : AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily:
                  refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
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
    this.refresh = false,
  });

  final Map<String, dynamic> event;
  final bool showConnector;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = event['placeType'] as String? ?? 'custom';
    final name = _friendlyPlaceName(l10n, event['placeName'] as String?, type);
    final start =
        DateTime.tryParse(event['startAt'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(event['endAt'] as String? ?? '')?.toLocal();
    final dur = (event['durationSeconds'] as num?)?.toInt() ?? 0;
    final icon = type == 'home'
        ? Icons.home_rounded
        : type == 'school'
            ? Icons.school_rounded
            : Icons.place_rounded;
    final accent =
        refresh ? VisualRefreshColors.accent : AppColors.teal;
    final iconBg =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;

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
                      color: accent.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: (refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft)
                            .withValues(alpha: 0.22),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                decoration: _cardDecoration(refresh),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(
                          refresh ? AppRadius.vrChip : 12,
                        ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: refresh
                                  ? VisualRefreshColors.textPrimary
                                  : null,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_fmtClock(start)} — ${_fmtClock(end)}',
                            style: TextStyle(
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtDuration(dur),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: accent,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
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
  const _TripCard({required this.event, this.refresh = false});

  final Map<String, dynamic> event;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final start = DateTime.tryParse(event['startAt'] as String? ?? '')?.toLocal();
    final end = DateTime.tryParse(event['endAt'] as String? ?? '')?.toLocal();
    final dur = (event['durationSeconds'] as num?)?.toInt() ?? 0;
    final startLabel = _friendlyPlaceName(
      l10n,
      event['startLabel'] as String?,
      null,
    );
    final endLabel = _friendlyPlaceName(
      l10n,
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
    final lineColor =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;

    return Container(
      decoration: _cardDecoration(refresh),
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
                    color: lineColor,
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
              color: refresh
                  ? VisualRefreshColors.accentTint
                  : AppColors.mint.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                l10n.tripGenericLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: refresh ? VisualRefreshColors.accent : null,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: refresh
                              ? VisualRefreshColors.textPrimary
                              : null,
                          fontFamily: refresh
                              ? GoogleFonts.plusJakartaSans().fontFamily
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      _fmtDuration(dur),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: refresh
                            ? VisualRefreshColors.accent
                            : AppColors.tealDeep,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TripEndpoint(
                  color: refresh
                      ? VisualRefreshColors.accent
                      : AppColors.success,
                  label: startLabel,
                  refresh: refresh,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: (refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft)
                        .withValues(alpha: 0.35),
                  ),
                ),
                _TripEndpoint(
                  color: refresh
                      ? VisualRefreshColors.danger
                      : AppColors.coral,
                  label: endLabel,
                  refresh: refresh,
                ),
                if (inaccurate) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).weakSignalRoute,
                    style: TextStyle(
                      color: refresh
                          ? VisualRefreshColors.textSecondary
                          : AppColors.inkSoft,
                      fontSize: 12,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
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
  const _TripEndpoint({
    required this.color,
    required this.label,
    this.refresh = false,
  });

  final Color color;
  final String label;
  final bool refresh;

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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: refresh ? VisualRefreshColors.textPrimary : null,
              fontFamily:
                  refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
            ),
          ),
        ),
      ],
    );
  }
}

String _friendlyPlaceName(
  AppLocalizations l10n,
  String? raw,
  String? type,
) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty || RegExp(r'^\d{4,}$').hasMatch(name)) {
    if (type == 'home') return l10n.homeZone;
    if (type == 'school') return l10n.schoolZone;
    if (name == 'Berangkat' || name == 'Dalam perjalanan' || name == 'Tiba') {
      return name;
    }
    return type == 'custom'
        ? l10n.safePlaceLabel
        : (name.isEmpty ? l10n.zoneGenericLabel : name);
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
