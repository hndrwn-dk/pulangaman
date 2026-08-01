import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/locale_controller.dart';
import '../../core/network/ws_client.dart';
import '../../core/parse_coord.dart';
import '../../core/storage/offline_queue.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/emergency_meeting_alert_screen.dart';
import '../parent/visual_refresh_flag.dart';
import '../reminders/reminder_templates.dart';
import '../rewards/rewards_screen.dart';
import '../screentime/screen_time_channel.dart';
import 'child_beranda_tab.dart';
import 'child_kabar_tab.dart';
import 'child_layar_tab.dart';
import 'child_usage_utils.dart';
import 'background_location_disclosure_screen.dart';
import 'location_tracking_channel.dart';
import 'panic_tap_counter.dart';
import 'reminder_channel.dart';
import '../../core/storage/session_store.dart';

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _ws = WsClient();
  bool _tracking = false;
  bool _panicMode = false;
  bool _panicInFlight = false;
  final PanicTapCounter _panicTapCounter = PanicTapCounter();
  String? _status;
  int _points = 0;
  int _streak = 0;
  bool _usageAccess = false;
  bool _accessibility = false;
  int _todayUsageSeconds = 0;
  int _tabIndex = 0;
  UsagePeriod _usagePeriod = UsagePeriod.today;
  List<UsageAppEntry> _usageApps = [];
  bool _usageLoading = false;
  String? _sendingPresetId;
  int _reminderCount = 0;
  List<Map<String, dynamic>> _reminders = [];
  bool _exactAlarmOk = true;
  final ScreenTimeChannel _screenTimeChannel = ScreenTimeChannel();
  final LocationTrackingChannel _locationChannel = LocationTrackingChannel();
  final ReminderChannel _reminderChannel = ReminderChannel();
  Timer? _panicCooldownTimer;
  Timer? _panicStatusPoll;
  Timer? _homeByPoll;
  Timer? _tripPoll;
  Timer? _empPoll;
  String? _homeByStatus;
  bool _homeByAcked = false;
  bool _homeByPreviewShown = false;
  Map<String, dynamic>? _trip;
  Timer? _tripArrivedClear;
  Map<String, dynamic>? _empActive;
  Map<String, dynamic>? _empPoint;
  String? _empAlertOpenedId;
  bool _empScreenOpen = false;
  /// Activations the child already stood down — ignore late WS/FCM/poll echoes.
  final Set<String> _empResolvedIds = {};
  String? _streakCelebrationShownId;
  bool _streakCelebrationInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_startTracking);
    Future.microtask(_setupScreenTimeAndRewards);
    Future.microtask(_syncReminders);
    Future.microtask(_connectReminderWs);
    Future.microtask(_pollPanicStatus);
    Future.microtask(_pollHomeByStatus);
    Future.microtask(_pollTrip);
    Future.microtask(_pollEmergencyMeeting);
    Future.microtask(_pollEmpPoint);
    Future.microtask(_checkPendingStreakCelebration);
    _panicStatusPoll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollPanicStatus()),
    );
    _homeByPoll = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_pollHomeByStatus()),
    );
    _tripPoll = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_pollTrip()),
    );
    _empPoll = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        unawaited(_pollEmergencyMeeting());
        unawaited(_pollEmpPoint());
      },
    );
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((_) => _flushQueue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshScreenTimeAndRewards());
      unawaited(_ensureNativeTracking());
      unawaited(_syncZoneGeofences());
      unawaited(_syncReminders());
      unawaited(_connectReminderWs(force: true));
      unawaited(_pollPanicStatus());
      // Refresh status only — do not force-open the alert on every resume
      // (closing the native fullscreen also resumes the app).
      unawaited(_pollEmergencyMeeting());
      unawaited(_pollEmpPoint());
      unawaited(_checkPendingStreakCelebration());
    }
  }

  Future<void> _setupScreenTimeAndRewards() => _refreshScreenTimeAndRewards();

  Future<void> _refreshScreenTimeAndRewards() async {
    await _ensureNativeTracking();
    await _pushLocationOnce();
    await _syncScreenTimePermissions();
    await _loadRewards();
    await _loadUsageStats(_usagePeriod);
  }

  Future<void> _loadUsageStats(UsagePeriod period) async {
    if (!_usageAccess) {
      if (!mounted) return;
      setState(() {
        _usageApps = [];
        _todayUsageSeconds = 0;
      });
      return;
    }

    setState(() => _usageLoading = true);
    try {
      final raw = await _screenTimeChannel.getUsageStats(period.apiValue);
      final apps = raw.map(UsageAppEntry.fromJson).toList()
        ..sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
      final total = apps.fold(0, (sum, app) => sum + app.durationSeconds);
      if (!mounted) return;
      setState(() {
        _usageApps = apps;
        if (period == UsagePeriod.today) {
          _todayUsageSeconds = total;
        }
      });
      if (period == UsagePeriod.today) {
        final ok = await _uploadUsageTelemetry(apps);
        unawaited(_uploadHourlyUsageTelemetry());
        if (!ok && mounted) {
          // Keep silent on auto-load; refresh button reports status.
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _usageApps = []);
    } finally {
      if (mounted) setState(() => _usageLoading = false);
    }
  }

  Future<void> _connectReminderWs({bool force = false}) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    final userId = auth.userId;
    if (token == null || userId == null) return;
    try {
      if (force || !_ws.isConnected) {
        _ws.addHandler(_onReminderWs);
        await _ws.connect(token);
      }
      _ws.subscribe('child:$userId');
    } catch (_) {}
  }

  void _onReminderWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:reminders_updated') {
      unawaited(_syncReminders());
      return;
    }
    if (event == 'parent:emergency_meeting_alert') {
      unawaited(_onEmergencyMeetingAlert(payload));
      return;
    }
    if (event == 'parent:emergency_meeting_resolved') {
      _onEmergencyMeetingResolved(payload);
      return;
    }
    if (event == 'parent:home_by_status' || event == 'parent:home_by_ack') {
      unawaited(_pollHomeByStatus());
      return;
    }
    if (event == 'parent:trip_progress' ||
        event == 'parent:trip_started' ||
        event == 'parent:trip_planned' ||
        event == 'parent:trip_arrived' ||
        event == 'parent:trip_cancelled') {
      if (event == 'parent:trip_cancelled') {
        _tripArrivedClear?.cancel();
        if (mounted) setState(() => _trip = null);
      } else if (event == 'parent:trip_arrived') {
        _showTripArrived(payload);
      } else {
        if (mounted) setState(() => _trip = payload);
      }
      return;
    }
    if (event == 'child:panic_acked' || event == 'child:panic_resolved') {
      final l10n = AppLocalizations.of(context);
      unawaited(_clearPanicState(
        message: event == 'child:panic_acked'
            ? l10n.panicAckedByParent
            : l10n.panicResolvedSafe,
      ));
      return;
    }
    if (event == 'streak:celebration' || event == 'reward:earned') {
      if (event == 'streak:celebration') {
        unawaited(_showStreakCelebrationFromPayload(payload));
      } else {
        unawaited(_loadRewards());
      }
    }
  }

  Future<void> _onEmergencyMeetingAlert(Map<String, dynamic> payload) async {
    final activationId = payload['activationId'] as String?;
    if (activationId != null && _empResolvedIds.contains(activationId)) {
      return;
    }
    // Late FCM/WS can arrive after the parent already turned the alert off.
    try {
      final live = await ref
          .read(apiClientProvider)
          .get('/api/v1/emergency-meeting-points/active');
      final alert = live['alert'];
      if (alert is! Map<String, dynamic>) {
        if (activationId != null) _empResolvedIds.add(activationId);
        return;
      }
      final liveId = alert['activationId'] as String?;
      if (liveId != null && _empResolvedIds.contains(liveId)) return;
    } catch (_) {
      // Fall through and show from the push payload if the poll failed.
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final name = payload['meetingPointName'] as String? ?? l10n.empDefaultPlaceName;
    final lat = parseCoord(payload['lat']);
    final lng = parseCoord(payload['lng']);
    if (lat == null || lng == null || !mounted) return;
    final note = payload['note'] as String?;
    final instructions = payload['instructions'] as String?;
    setState(() {
      _empActive = {
        'activationId': activationId,
        'meetingPointName': name,
        'lat': lat,
        'lng': lng,
        'note': note,
        'instructions': instructions,
      };
    });
    try {
      await _reminderChannel.previewNow(
        title: l10n.empAlertTitle,
        body: note != null && note.isNotEmpty
            ? l10n.empAlertBodyWithNote(note, name)
            : l10n.empAlertBodyPlain(name),
        style: 'fullscreen',
        visualRefresh: ref.read(visualRefreshEnabledProvider),
      );
    } catch (_) {}
    if (!mounted) return;
    await _openEmergencyMeetingScreen(
      placeName: name,
      lat: lat,
      lng: lng,
      instructions: instructions,
      note: note,
      activationId: activationId,
    );
  }

  void _onEmergencyMeetingResolved([Map<String, dynamic>? payload]) {
    final activationId = payload?['activationId'] as String?;
    if (activationId != null) _empResolvedIds.add(activationId);
    unawaited(_clearEmergencyMeetingUi());
  }

  Future<void> _clearEmergencyMeetingUi() async {
    try {
      await _reminderChannel.dismissFullScreen();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _empActive = null);
    if (_empScreenOpen) {
      _empScreenOpen = false;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).empDeactivated)),
    );
  }

  Future<void> _pollEmpPoint() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/emergency-meeting-points');
      final points = (data['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      Map<String, dynamic>? primary;
      for (final p in points) {
        if (p['isPrimary'] == true) {
          primary = p;
          break;
        }
      }
      primary ??= points.isEmpty ? null : points.first;
      if (!mounted) return;
      setState(() => _empPoint = primary);
    } catch (_) {}
  }

  Future<void> _pollEmergencyMeeting({bool openAlert = false}) async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/emergency-meeting-points/active');
      final alert = data['alert'];
      if (alert is! Map<String, dynamic>) {
        final hadActive = _empActive != null || _empScreenOpen;
        if (hadActive) {
          try {
            await _reminderChannel.dismissFullScreen();
          } catch (_) {}
          if (mounted) {
            setState(() => _empActive = null);
            if (_empScreenOpen) {
              _empScreenOpen = false;
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
        return;
      }
      final activationId = alert['activationId'] as String?;
      if (activationId != null && _empResolvedIds.contains(activationId)) {
        if (mounted && (_empActive != null || _empScreenOpen)) {
          try {
            await _reminderChannel.dismissFullScreen();
          } catch (_) {}
          if (mounted) {
            setState(() => _empActive = null);
            if (_empScreenOpen) {
              _empScreenOpen = false;
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
        return;
      }
      if (!mounted) return;
      setState(() => _empActive = alert);
      if (openAlert ||
          (activationId != null && activationId != _empAlertOpenedId)) {
        final lat = parseCoord(alert['lat']);
        final lng = parseCoord(alert['lng']);
        final name = alert['meetingPointName'] as String? ??
            AppLocalizations.of(context).empDefaultPlaceName;
        if (lat != null && lng != null) {
          await _openEmergencyMeetingScreen(
            placeName: name,
            lat: lat,
            lng: lng,
            instructions: alert['instructions'] as String?,
            note: alert['note'] as String?,
            activationId: activationId,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _openEmergencyMeetingScreen({
    required String placeName,
    required double lat,
    required double lng,
    String? instructions,
    String? note,
    String? activationId,
  }) async {
    if (!mounted) return;
    if (activationId != null) {
      if (activationId == _empAlertOpenedId) return;
      _empAlertOpenedId = activationId;
    }
    _empScreenOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyMeetingAlertScreen(
          placeName: placeName,
          lat: lat,
          lng: lng,
          instructions: instructions,
          note: note,
        ),
      ),
    );
    _empScreenOpen = false;
  }

  Future<void> _pollHomeByStatus() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null || !mounted) return;
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/home-by/$userId/today');
      final today = data['today'] as Map<String, dynamic>?;
      final status = today?['status'] as String?;
      final ackAt = today?['childAckAt'];
      final acked = ackAt != null;
      if (!mounted) return;

      final shouldPreview = status == 'pre_notified' && !_homeByPreviewShown;
      setState(() {
        _homeByStatus = status;
        _homeByAcked = acked;
      });

      if (shouldPreview) {
        _homeByPreviewShown = true;
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        final name = ref.read(authControllerProvider).name ?? l10n.homeByDefaultChildName;
        try {
          await _reminderChannel.previewNow(
            title: l10n.homeByPreviewTitle,
            body: l10n.homeByPreviewBody(name),
            style: 'fullscreen',
            visualRefresh: ref.read(visualRefreshEnabledProvider),
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _openHomeByAckSheet() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    final l10n = AppLocalizations.of(context);
    final reasons = <({String id, String label})>[
      (id: 'in_transit', label: l10n.homeByChildAckReasonInTransit),
      (id: 'stopped_by', label: l10n.homeByChildAckReasonStoppedBy),
      (id: 'school_activity', label: l10n.homeByChildAckReasonSchool),
      (id: 'other', label: l10n.homeByChildAckReasonOther),
    ];
    String selected = 'in_transit';
    final noteCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.homeByChildAckTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in reasons)
                        ChoiceChip(
                          label: Text(r.label),
                          selected: selected == r.id,
                          onSelected: (_) => setModal(() => selected = r.id),
                        ),
                    ],
                  ),
                  if (selected == 'other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLength: 140,
                      decoration: InputDecoration(
                        hintText: l10n.homeByChildAckNoteHint,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.homeByChildAckSubmit),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || !mounted) {
      noteCtrl.dispose();
      return;
    }
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/home-by/$userId/ack',
        body: {
          'reason': selected,
          if (selected == 'other' && noteCtrl.text.trim().isNotEmpty)
            'note': noteCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() => _homeByAcked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeByChildAckSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _pollTrip() async {
    if (!mounted) return;
    // Keep the "Tiba" celebration visible; /active returns null after arrive.
    if (_trip?['status'] == 'arrived') return;
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/trips/active');
      if (!mounted) return;
      setState(() => _trip = data['trip'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  void _showTripArrived(Map<String, dynamic> payload) {
    _tripArrivedClear?.cancel();
    if (!mounted) return;
    setState(() {
      _trip = {
        ...payload,
        'status': 'arrived',
        'progress': 1,
      };
    });
    _tripArrivedClear = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      setState(() => _trip = null);
    });
    final l10n = AppLocalizations.of(context);
    final destination =
        payload['toLabel'] as String? ?? l10n.destinationFallback;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.tripArrivedNotified(destination))),
    );
  }

  Future<void> _markTripArrived() async {
    final id = _trip?['id'] as String?;
    if (id == null) return;
    try {
      final data =
          await ref.read(apiClientProvider).post('/api/v1/trips/$id/arrive');
      final trip = data['trip'];
      if (!mounted) return;
      if (trip is Map<String, dynamic>) {
        _showTripArrived(trip);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _cancelActiveTrip() async {
    final id = _trip?['id'] as String?;
    if (id == null) return;
    try {
      await ref.read(apiClientProvider).post('/api/v1/trips/$id/cancel');
      if (!mounted) return;
      _tripArrivedClear?.cancel();
      setState(() => _trip = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _startPlannedTrip() async {
    final id = _trip?['id'] as String?;
    if (id == null) return;
    try {
      final data =
          await ref.read(apiClientProvider).post('/api/v1/trips/$id/start');
      if (!mounted) return;
      setState(() => _trip = data['trip'] as Map<String, dynamic>?);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _openStartTripSheet() async {
    List<Map<String, dynamic>> zones = [];
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/zones');
      zones = (data['zones'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {}
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (zones.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tripNotEnoughPlaces)),
      );
      return;
    }

    String zoneLabel(Map<String, dynamic> z) {
      final name = (z['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
      final type = z['type'] as String?;
      if (type == 'home') return l10n.homeZone;
      if (type == 'school') return l10n.schoolZone;
      return l10n.zoneGenericLabel;
    }

    Map<String, dynamic>? fromZone;
    for (final z in zones) {
      if (z['type'] == 'home') {
        fromZone = z;
        break;
      }
    }
    fromZone ??= zones.first;
    final fromZoneId = fromZone['id'];
    Map<String, dynamic>? toZone;
    for (final z in zones) {
      if (z['id'] != fromZoneId && z['type'] != 'home') {
        toZone = z;
        break;
      }
    }
    toZone ??= zones.firstWhere(
      (z) => z['id'] != fromZoneId,
      orElse: () => zones.last,
    );

    String? fromId = fromZone['id'] as String?;
    String? toId = toZone['id'] as String?;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tripChildStart,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.tripPickFrom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: fromId,
                    items: [
                      for (final z in zones)
                        DropdownMenuItem(
                          value: z['id'] as String,
                          child: Text(zoneLabel(z)),
                        ),
                    ],
                    onChanged: (v) => setSheet(() => fromId = v),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.tripPickTo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: toId,
                    items: [
                      for (final z in zones)
                        DropdownMenuItem(
                          value: z['id'] as String,
                          child: Text(zoneLabel(z)),
                        ),
                    ],
                    onChanged: (v) => setSheet(() => toId = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (fromId == null || toId == null || fromId == toId) {
                        return;
                      }
                      Navigator.of(ctx).pop(true);
                    },
                    child: Text(l10n.startAction),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true || fromId == null || toId == null || !mounted) return;
    try {
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/trips',
        body: {
          'fromZoneId': fromId,
          'toZoneId': toId,
          'mode': 'walking',
          'startImmediately': true,
        },
      );
      if (!mounted) return;
      setState(() => _trip = data['trip'] as Map<String, dynamic>?);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _pollPanicStatus() async {
    if (!mounted) return;
    // Always poll while panic UI is on; also once after resume to recover.
    if (!_panicMode && !_panicTapCounter.isOnCooldown) return;
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/panic/me/active');
      final active = data['active'] == true;
      final waitingParent = data['waitingParent'] == true;
      final resolved = data['resolved'] == true;
      if (active) return;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (waitingParent) {
        await _clearPanicState(message: l10n.panicAckedByParent);
        return;
      }
      if (resolved || data['status'] == null) {
        await _clearPanicState(message: l10n.panicResolvedSafe);
      }
    } catch (_) {}
  }

  Future<void> _clearPanicState({String? message}) async {
    _panicCooldownTimer?.cancel();
    _panicTapCounter.reset();
    _panicInFlight = false;
    if (_panicMode) {
      await _setPanicMode(false);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _panicMode = false;
      _status = _tracking ? l10n.trackingOn : _status;
    });
    if (message != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _schedulePanicCooldownRefresh() {
    _panicCooldownTimer?.cancel();
    final until = _panicTapCounter.cooldownUntil;
    if (until == null) return;
    final wait = until.difference(DateTime.now()) + const Duration(milliseconds: 200);
    if (wait.isNegative) {
      if (mounted) setState(() {});
      return;
    }
    _panicCooldownTimer = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _syncReminders() async {
    await Permission.notification.request();
    try {
      final canExact = await _reminderChannel.canScheduleExactAlarms();
      if (!mounted) return;
      setState(() => _exactAlarmOk = canExact);
      if (!canExact) {
        // Soft prompt once via status chip; user can tap later.
      }

      final l10n = AppLocalizations.of(context);
      final data = await ref.read(apiClientProvider).get('/api/v1/reminders/me');
      final list = (data['reminders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((r) {
            final title = r['title'] as String? ?? '';
            final body = r['body'] as String? ?? '';
            final templateKey = ReminderTemplates.normalizeKey(
              r['templateKey'] as String?,
            );
            return {
              'id': r['id'],
              'title': ReminderTemplates.displayTitle(
                l10n,
                templateKey: templateKey,
                title: title,
                body: body,
              ),
              'body': ReminderTemplates.displayBody(
                l10n,
                templateKey: templateKey,
                title: title,
                body: body,
              ),
              'hour': r['hour'],
              'minute': r['minute'],
              'daysOfWeek': r['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7],
              'style': r['style'] ?? 'fullscreen',
              'enabled': r['enabled'] != false,
            };
          })
          .toList();
      await _reminderChannel.syncReminders(list);
      if (!mounted) return;
      setState(() {
        _reminders = list;
        _reminderCount = list.length;
      });
      if (!_exactAlarmOk && list.isNotEmpty) {
        final alarmL10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alarmL10n.allowExactAlarmMessage),
            action: SnackBarAction(
              label: alarmL10n.openAction,
              onPressed: _openReminderPermissions,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reminders = [];
        _reminderCount = 0;
      });
    }
  }

  Future<void> _showLanguagePicker() async {
    final locale = ref.read(localeControllerProvider);
    final refresh = visualRefreshOf(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          refresh ? VisualRefreshColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetL10n.settingsLanguage,
                  style: TextStyle(
                    fontSize: refresh ? 20 : 18,
                    fontWeight: FontWeight.w900,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sheetL10n.settingsLanguageHint,
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                _ChildLanguageOption(
                  label: sheetL10n.settingsLanguageId,
                  selected: locale.languageCode == 'id',
                  refresh: refresh,
                  onTap: () => Navigator.pop(ctx, 'id'),
                ),
                const SizedBox(height: 8),
                _ChildLanguageOption(
                  label: sheetL10n.settingsLanguageEn,
                  selected: locale.languageCode == 'en',
                  refresh: refresh,
                  onTap: () => Navigator.pop(ctx, 'en'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    await ref
        .read(localeControllerProvider.notifier)
        .setLocale(Locale(chosen));
    if (!mounted) return;
    unawaited(_syncReminders());
  }

  Future<void> _openReminderPermissions() async {
    final canExact = await _reminderChannel.canScheduleExactAlarms();
    if (!canExact) {
      await _reminderChannel.openExactAlarmSettings();
      return;
    }
    await _reminderChannel.openFullScreenIntentSettings();
  }

  void _openScreenTab() {
    setState(() => _tabIndex = 1);
    unawaited(_loadUsageStats(_usagePeriod));
  }

  Future<void> _openRewards() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RewardsScreen(selfChildId: userId),
      ),
    );
    unawaited(_loadRewards());
  }

  List<Map<String, dynamic>> _todaysReminders() {
    final weekday = DateTime.now().weekday; // 1=Mon ... 7=Sun
    final today = <Map<String, dynamic>>[];
    for (final r in _reminders) {
      if (r['enabled'] == false) continue;
      final rawDays = r['daysOfWeek'];
      final days = rawDays is List
          ? rawDays
              .map((d) => d is int ? d : int.tryParse('$d'))
              .whereType<int>()
              .toList()
          : const [1, 2, 3, 4, 5, 6, 7];
      if (days.isEmpty || days.contains(weekday)) {
        today.add(r);
      }
    }
    today.sort((a, b) {
      final ah = (a['hour'] as num?)?.toInt() ?? 0;
      final am = (a['minute'] as num?)?.toInt() ?? 0;
      final bh = (b['hour'] as num?)?.toInt() ?? 0;
      final bm = (b['minute'] as num?)?.toInt() ?? 0;
      return (ah * 60 + am).compareTo(bh * 60 + bm);
    });
    return today;
  }

  String _formatReminderTime(Map<String, dynamic> r) {
    final hour = (r['hour'] as num?)?.toInt() ?? 0;
    final minute = (r['minute'] as num?)?.toInt() ?? 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openRemindersSheet() async {
    if (!mounted) return;
    final refresh = visualRefreshOf(context);
    final today = _todaysReminders();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: refresh ? VisualRefreshColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetL10n.todaysRemindersTitle,
                  style: TextStyle(
                    fontSize: refresh ? 20 : 18,
                    fontWeight: FontWeight.w900,
                    color: refresh ? VisualRefreshColors.textPrimary : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (today.isEmpty)
                  Text(
                    sheetL10n.todaysRemindersEmpty,
                    style: TextStyle(
                      color: refresh
                          ? VisualRefreshColors.textSecondary
                          : AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  for (final r in today) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alarm_rounded,
                            size: 20,
                            color: refresh
                                ? VisualRefreshColors.accent
                                : AppColors.teal,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r['title'] as String? ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: refresh
                                    ? VisualRefreshColors.textPrimary
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            _formatReminderTime(r),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openScreenPermissionSetup() async {
    if (!mounted) return;
    final refresh = visualRefreshOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: refresh ? VisualRefreshColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetL10n.enableScreenProtectionTitle,
                  style: TextStyle(
                    fontSize: refresh ? 20 : 18,
                    fontWeight: FontWeight.w900,
                    color: refresh ? VisualRefreshColors.textPrimary : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sheetL10n.neverBlockedAppsNote,
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                if (!_usageAccess)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(_screenTimeChannel.openUsageAccessSettings());
                    },
                    child: Text(sheetL10n.allowUsageAccess),
                  ),
                if (!_accessibility) ...[
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(
                        _screenTimeChannel.openAccessibilitySettings(),
                      );
                    },
                    child: Text(sheetL10n.enableAppBlocking),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sheetL10n.restrictedSettingsHelp,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: refresh
                          ? VisualRefreshColors.textSecondary
                          : AppColors.inkSoft,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(_screenTimeChannel.openAppInfoSettings());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: refresh
                          ? VisualRefreshColors.accent
                          : AppColors.tealDeep,
                    ),
                    child: Text(
                      sheetL10n.openAppInfo,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncScreenTimePermissions() async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId;
    if (userId == null) return;

    try {
      final usage = await _screenTimeChannel.hasUsageAccess();
      final accessibility = await _screenTimeChannel.isAccessibilityEnabled();
      if (!mounted) return;
      setState(() {
        _usageAccess = usage;
        _accessibility = accessibility;
      });

      final installationId = 'android-$userId';
      await ref.read(apiClientProvider).post('/api/v1/policies/device', body: {
        'installationId': installationId,
        'deviceName': 'Android child device',
        'appVersion': '0.3.0',
        'usageAccessGranted': usage,
        'accessibilityEnabled': accessibility,
      });

      if (!usage || !accessibility) return;

      final policyData =
          await ref.read(apiClientProvider).get('/api/v1/policies/current/me');
      final policy = policyData['policy'] as Map<String, dynamic>?;
      if (policy == null) return;

      await _screenTimeChannel.applyPolicy(policy);
      await _screenTimeChannel.startEnforcement();
      await ref.read(apiClientProvider).post('/api/v1/policies/ack', body: {
        'installationId': installationId,
        'policyId': policy['id'],
        'version': policy['version'],
      });
    } catch (_) {
      // Native screen-time APIs are Android-only.
    }
  }

  Future<void> _loadRewards() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/rewards/$userId');
      final balance = data['balance'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _points = (balance['points'] as num?)?.toInt() ?? 0;
        _streak = (balance['current_streak'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _checkPendingStreakCelebration() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/rewards/$userId/streak-celebration/pending');
      final celebration = data['celebration'];
      if (celebration is Map<String, dynamic>) {
        await _presentStreakCelebration(celebration);
      }
    } catch (_) {}
  }

  Future<void> _showStreakCelebrationFromPayload(
    Map<String, dynamic> payload,
  ) async {
    final celebration = <String, dynamic>{
      'id': payload['celebrationId'] ?? payload['id'],
      'milestoneDays': payload['milestoneDays'],
      'pointsAwarded': payload['pointsAwarded'],
      'accent': payload['accent'],
      'titleId': payload['titleId'],
      'bodyId': payload['bodyId'],
      'titleEn': payload['titleEn'],
      'bodyEn': payload['bodyEn'],
    };
    await _presentStreakCelebration(celebration);
    unawaited(_loadRewards());
  }

  Future<void> _presentStreakCelebration(Map<String, dynamic> celebration) async {
    if (!mounted || _streakCelebrationInFlight) return;
    final id = celebration['id'] as String?;
    if (id == null || id == _streakCelebrationShownId) return;
    // Don't stack on an active EMP full-screen moment.
    if (_empActive != null || _empScreenOpen) return;

    final days = (celebration['milestoneDays'] as num?)?.toInt() ?? 0;
    final points = (celebration['pointsAwarded'] as num?)?.toInt() ?? 0;
    if (days <= 0) return;

    final locale = ref.read(localeControllerProvider).languageCode;
    final isEn = locale == 'en';
    final l10n = AppLocalizations.of(context);
    final title = (isEn
            ? celebration['titleEn'] as String?
            : celebration['titleId'] as String?) ??
        l10n.streakCelebrationTitle(days);
    // Prefer API body when present; fall back to local copy without points
    // (points are shown in the gold badge, not duplicated in body).
    final apiBody = isEn
        ? celebration['bodyEn'] as String?
        : celebration['bodyId'] as String?;
    final rawBody = (apiBody != null && apiBody.trim().isNotEmpty)
        ? apiBody
        : l10n.streakCelebrationBody(days);
    // Badge carries the points amount; strip legacy "+N poin" suffix from body.
    final body = rawBody.replaceFirst(
      RegExp(r'\s*\+\d+\s*(poin|points)\s*$', caseSensitive: false),
      '',
    );

    final mood = switch (days) {
      30 || 14 => 'streak_medal',
      7 => 'streak_trophy',
      _ => 'streak_star',
    };
    // Bedtime-style gold for every milestone (not study green / EMP terracotta).
    const accent = 'gold';

    _streakCelebrationInFlight = true;
    _streakCelebrationShownId = id;
    try {
      final action = await _reminderChannel.previewNow(
        title: title,
        body: body,
        style: 'fullscreen',
        visualRefresh: true,
        mood: mood,
        accent: accent,
        pointsBadge: l10n.streakPointsBadge(points > 0 ? points : _fallbackPoints(days)),
        primaryCta: l10n.viewPointsCta,
        secondaryCta: l10n.understood,
      );
      await ref.read(apiClientProvider).post(
            '/api/v1/rewards/${ref.read(authControllerProvider).userId}/streak-celebration/$id/ack',
          );
      unawaited(_loadRewards());
      if (!mounted) return;
      if (action == 'view_points') {
        final userId = ref.read(authControllerProvider).userId;
        if (userId != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RewardsScreen(selfChildId: userId),
            ),
          );
        }
      }
    } catch (_) {
      _streakCelebrationShownId = null;
    } finally {
      _streakCelebrationInFlight = false;
    }
  }

  int _fallbackPoints(int days) {
    return switch (days) {
      30 => 25,
      14 => 15,
      7 => 10,
      _ => 5,
    };
  }

  Future<void> _startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() =>
          _status = AppLocalizations.of(context).locationPermissionDenied);
      return;
    }

    // Play/App Store: disclose why "Allow all the time" is needed before the OS dialog.
    var always = await Permission.locationAlways.status;
    if (!always.isGranted) {
      if (!mounted) return;
      final proceed = await showBackgroundLocationDisclosure(context);
      if (!proceed) {
        // Continue with when-in-use only; do not open the Always dialog.
        always = PermissionStatus.denied;
      } else {
        final store = ref.read(sessionStoreProvider);
        await store.saveBgLocationDisclosureAcked();
        if (!mounted) return;
        always = await Permission.locationAlways.request();
      }
    }

    await Permission.notification.request();

    final token = ref.read(authControllerProvider).token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _status = AppLocalizations.of(context).sessionNotReady);
      return;
    }

    try {
      await _locationChannel.start(
        token: token,
        apiBaseUrl: AppConfig.apiBaseUrl,
        panic: _panicMode,
      );
      // One immediate foreground push so parent sees a point right away.
      await _pushLocationOnce();
      unawaited(_syncZoneGeofences());
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _status = always.isGranted
            ? AppLocalizations.of(context).trackingOn
            : AppLocalizations.of(context).trackingOnNeedsAlways;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = AppLocalizations.of(context).locationSendFailed);
    }
  }

  Future<void> _syncZoneGeofences() async {
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/zones');
      final zones = (data['zones'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((z) {
            final id = z['id']?.toString() ?? '';
            final lat = parseCoord(z['lat']);
            final lng = parseCoord(z['lng']);
            final radius = (z['radius_m'] as num?)?.toDouble() ??
                (z['radiusM'] as num?)?.toDouble();
            if (id.isEmpty || lat == null || lng == null || radius == null) {
              return null;
            }
            return <String, dynamic>{
              'id': id,
              'lat': lat,
              'lng': lng,
              'radiusM': radius,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      await _locationChannel.syncZoneGeofences(zones);
    } catch (_) {
      // Geofence sync is best-effort; live tracking still works via FGS.
    }
  }

  Future<void> _ensureNativeTracking() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      final running = await _locationChannel.isRunning();
      if (!running) {
        await _locationChannel.start(
          token: token,
          apiBaseUrl: AppConfig.apiBaseUrl,
          panic: _panicMode,
        );
      } else {
        await _locationChannel.update(
          token: token,
          apiBaseUrl: AppConfig.apiBaseUrl,
          panic: _panicMode,
        );
      }
      if (mounted) setState(() => _tracking = true);
    } catch (_) {}
  }

  Future<bool> _uploadUsageTelemetry(List<UsageAppEntry> apps) async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null || apps.isEmpty) return false;
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final now = DateTime.now().toUtc().toIso8601String();
    final installationId = 'android-$userId';
    final events = apps
        .where((app) => app.packageName.isNotEmpty && app.durationSeconds > 0)
        .take(80)
        .map(
          (app) => {
            'clientEventId': 'usage-$day-${app.packageName}',
            'kind': 'usage',
            'packageName': app.packageName,
            'durationSeconds': app.durationSeconds,
            'recordedAt': now,
            'payload': {
              'appLabel': friendlyAppName(
                app.packageName,
                appLabel: app.appLabel,
              ),
            },
          },
        )
        .toList();
    if (events.isEmpty) return false;
    try {
      await ref.read(apiClientProvider).post('/api/v1/policies/device', body: {
        'installationId': installationId,
        'deviceName': 'Android child device',
        'appVersion': '0.3.0',
        'usageAccessGranted': _usageAccess,
        'accessibilityEnabled': _accessibility,
      });
      final result = await ref.read(apiClientProvider).post('/api/v1/telemetry/batch', body: {
        'installationId': installationId,
        'events': events,
      });
      final celebration = result['streakCelebration'];
      if (celebration is Map<String, dynamic>) {
        unawaited(_presentStreakCelebration(celebration));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _uploadHourlyUsageTelemetry() async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null || !_usageAccess) return;
    try {
      final raw = await _screenTimeChannel.getHourlyUsage(days: 7);
      if (raw.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      final installationId = 'android-$userId';
      final events = raw
          .where((row) {
            final pkg = row['packageName'] as String? ?? '';
            final secs = (row['durationSeconds'] as num?)?.toInt() ?? 0;
            final hour = (row['hour'] as num?)?.toInt();
            final day = row['day'] as String? ?? '';
            return pkg.isNotEmpty && secs > 0 && hour != null && day.length == 10;
          })
          .take(400)
          .map((row) {
            final pkg = row['packageName'] as String;
            final day = row['day'] as String;
            final hour = (row['hour'] as num).toInt();
            final secs = (row['durationSeconds'] as num).toInt();
            final label = row['appLabel'] as String?;
            return {
              'clientEventId': 'usage-hourly-$day-$hour-$pkg',
              'kind': 'usage_hourly',
              'packageName': pkg,
              'durationSeconds': secs,
              'recordedAt': now,
              'payload': {
                'appLabel': friendlyAppName(pkg, appLabel: label),
                'hour': hour,
                'day': day,
              },
            };
          })
          .toList();
      if (events.isEmpty) return;
      await ref.read(apiClientProvider).post('/api/v1/telemetry/batch', body: {
        'installationId': installationId,
        'events': events,
      });
    } catch (_) {
      // Hourly upload is best-effort; daily totals still power the main UI.
    }
  }

  Future<void> _setPanicMode(bool enabled) async {
    _panicMode = enabled;
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      await _locationChannel.update(
        token: token,
        apiBaseUrl: AppConfig.apiBaseUrl,
        panic: enabled,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _batteryFields() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      return {
        'batteryLevel': level.clamp(0, 100),
        'batteryCharging':
            state == BatteryState.charging || state == BatteryState.full,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _pushLocationOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final body = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracyM': pos.accuracy,
        'source': _panicMode ? 'panic' : 'active',
        ...await _batteryFields(),
      };

      final online = await _isOnline();
      if (!online) {
        await ref.read(offlineQueueProvider).enqueue('location', body);
        if (mounted) {
          setState(() => _status = AppLocalizations.of(context).offlineQueued);
        }
        return;
      }

      await ref.read(apiClientProvider).post('/api/v1/location', body: body);
      if (mounted) {
        setState(() => _status = AppLocalizations.of(context).trackingOn);
      }
      await _flushQueue();
    } catch (_) {
      if (mounted) {
        setState(() => _status = AppLocalizations.of(context).locationSendFailed);
      }
    }
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> _flushQueue() async {
    if (!await _isOnline()) return;
    final queue = ref.read(offlineQueueProvider);
    final api = ref.read(apiClientProvider);
    final items = await queue.peekAll();
    for (final item in items) {
      try {
        if (item.kind == 'location') {
          await api.post('/api/v1/location', body: item.payload);
        } else if (item.kind == 'panic') {
          await api.post('/api/v1/panic/trigger', body: item.payload);
        }
        await queue.remove(item.id);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _onPanicTap() async {
    if (_panicInFlight || _panicTapCounter.isOnCooldown) {
      return;
    }

    final tapResult = _panicTapCounter.registerTap();
    if (tapResult == 0) {
      return;
    }
    if (tapResult > 0) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.panicConfirmCount(tapResult)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    await _firePanicAlert();
  }

  /// Visual Refresh press-and-hold completion — same cascade as triple-tap.
  Future<void> _onPanicHoldComplete() async {
    if (_panicInFlight || _panicTapCounter.isOnCooldown) {
      return;
    }
    await _firePanicAlert();
  }

  Future<void> _firePanicAlert() async {
    _panicInFlight = true;
    _panicTapCounter.markTriggered();
    _schedulePanicCooldownRefresh();
    if (mounted) {
      setState(() => _panicMode = true);
    }
    await _setPanicMode(true);

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}

    final body = {
      'lat': pos?.latitude ?? -6.2,
      'lng': pos?.longitude ?? 106.8,
    };

    final online = await _isOnline();
    if (!online) {
      await ref.read(offlineQueueProvider).enqueue('panic', body);
      await _smsFallback();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).offlineQueued)),
        );
      }
      _panicInFlight = false;
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/panic/trigger', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).panicSent),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      await ref.read(offlineQueueProvider).enqueue('panic', body);
      await _smsFallback();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).panicSendFailedRetrying),
          ),
        );
      }
    } finally {
      _panicInFlight = false;
    }
  }

  Future<void> _sendMessagePreset(ChildMessagePreset preset) async {
    setState(() => _sendingPresetId = preset.id);
    try {
      await ref.read(apiClientProvider).post('/api/v1/messages', body: {
        'text': preset.text,
        'preset': preset.id,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).childMessageSentWithLabel(preset.label),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).childMessageFailed)),
      );
    } finally {
      if (mounted) setState(() => _sendingPresetId = null);
    }
  }

  Future<void> _smsFallback() async {
    if (!mounted) return;
    final body = AppLocalizations.of(context).smsFallbackPanicBody;
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _onUsagePeriodChanged(UsagePeriod period) {
    setState(() => _usagePeriod = period);
    unawaited(_loadUsageStats(period));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _panicCooldownTimer?.cancel();
    _panicStatusPoll?.cancel();
    _homeByPoll?.cancel();
    _tripPoll?.cancel();
    _tripArrivedClear?.cancel();
    _empPoll?.cancel();
    _ws.removeHandler(_onReminderWs);
    unawaited(_ws.disconnect());
    // Keep native FGS running after Flutter dispose so background tracking continues.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);
    final childName = auth.name ?? l10n.greetingDefaultName;
    final refresh = visualRefreshOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: l10n.settingsLanguage,
            onPressed: () => unawaited(_showLanguagePicker()),
            icon: Icon(
              refresh ? Icons.language_outlined : Icons.language_rounded,
            ),
          ),
          IconButton(
            tooltip: l10n.refreshTooltip,
            onPressed: () async {
              await _refreshScreenTimeAndRewards();
              await _syncReminders();
              if (!context.mounted) return;
              final sent = _usageApps.isNotEmpty;
              final refreshL10n = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    sent
                        ? refreshL10n.refreshSentWithApps
                        : refreshL10n.refreshSentNoApps,
                  ),
                ),
              );
            },
            icon: Icon(
              refresh ? Icons.refresh_outlined : Icons.refresh,
            ),
          ),
          IconButton(
            tooltip: l10n.logout,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final dialogRefresh = visualRefreshOf(ctx);
                  return AlertDialog(
                    title: Text(l10n.logoutConfirmTitle),
                    content: Text(l10n.logoutConfirmBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: dialogRefresh
                              ? VisualRefreshColors.danger
                              : AppColors.coral,
                        ),
                        child: Text(l10n.logout),
                      ),
                    ],
                  );
                },
              );
              if (ok != true) return;
              try {
                await _locationChannel.stop();
              } catch (_) {}
              try {
                await _locationChannel.clearZoneGeofences();
              } catch (_) {}
              await ref.read(authControllerProvider.notifier).logout();
            },
            icon: Icon(
              refresh ? Icons.logout_outlined : Icons.logout,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ChildBerandaTab(
            childName: childName,
            tracking: _tracking,
            points: _points,
            streak: _streak,
            usageAccess: _usageAccess,
            accessibility: _accessibility,
            todayUsageSeconds: _todayUsageSeconds,
            status: _status,
            panicInFlight: _panicInFlight,
            panicOnCooldown: _panicTapCounter.isOnCooldown,
            panicActive: _panicMode,
            reminderCount: _reminderCount,
            exactAlarmOk: _exactAlarmOk,
            onPanicTap: () => unawaited(_onPanicTap()),
            onPanicHoldComplete: () => unawaited(_onPanicHoldComplete()),
            onOpenUsageSettings: _screenTimeChannel.openUsageAccessSettings,
            onOpenAccessibilitySettings:
                _screenTimeChannel.openAccessibilitySettings,
            onOpenAppInfo: _screenTimeChannel.openAppInfoSettings,
            onOpenReminderPermissions: _openReminderPermissions,
            onOpenScreenTab: _openScreenTab,
            onOpenRewards: () => unawaited(_openRewards()),
            onOpenRemindersSheet: () => unawaited(_openRemindersSheet()),
            onOpenScreenPermissionSetup: () =>
                unawaited(_openScreenPermissionSetup()),
            homeByAckVisible: (_homeByStatus == 'pre_notified' ||
                    _homeByStatus == 'target_notified') &&
                !_homeByAcked,
            homeByAckSent: _homeByAcked &&
                (_homeByStatus == 'pre_notified' ||
                    _homeByStatus == 'target_notified' ||
                    _homeByStatus == 'grace_notified'),
            onHomeByAck: () => unawaited(_openHomeByAckSheet()),
            tripActive: _trip != null &&
                (_trip!['status'] == 'active' || _trip!['status'] == 'planned'),
            tripArrived: _trip?['status'] == 'arrived',
            tripToLabel: _trip?['toLabel'] as String?,
            tripProgress: (_trip?['progress'] as num?)?.toDouble() ?? 0,
            onStartTrip: _trip == null
                ? () => unawaited(_openStartTripSheet())
                : _trip!['status'] == 'planned'
                    ? () => unawaited(_startPlannedTrip())
                    : null,
            onCancelTrip: _trip != null &&
                    (_trip!['status'] == 'active' ||
                        _trip!['status'] == 'planned')
                ? () => unawaited(_cancelActiveTrip())
                : null,
            onArriveTrip: _trip != null && _trip!['status'] == 'active'
                ? () => unawaited(_markTripArrived())
                : null,
            empConfigured: _empPoint != null || _empActive != null,
            empActive: _empActive != null,
            empPlaceName: (_empActive?['meetingPointName'] as String?) ??
                (_empPoint?['name'] as String?),
            empNote: (_empActive?['note'] as String?) ??
                (_empPoint?['instructions'] as String?),
            onOpenEmp: (_empPoint == null && _empActive == null)
                ? null
                : () {
                    final fromActive = _empActive;
                    final lat = parseCoord(
                      fromActive?['lat'] ?? _empPoint?['lat'],
                    );
                    final lng = parseCoord(
                      fromActive?['lng'] ?? _empPoint?['lng'],
                    );
                    final name = (fromActive?['meetingPointName'] as String?) ??
                        (_empPoint?['name'] as String?) ??
                        l10n.empDefaultPlaceName;
                    if (lat == null || lng == null) return;
                    _empAlertOpenedId = null;
                    unawaited(
                      _openEmergencyMeetingScreen(
                        placeName: name,
                        lat: lat,
                        lng: lng,
                        instructions: (fromActive?['instructions'] as String?) ??
                            (_empPoint?['instructions'] as String?),
                        note: fromActive?['note'] as String?,
                        activationId: fromActive?['activationId'] as String?,
                      ),
                    );
                  },
          ),
          ChildLayarTab(
            usageAccess: _usageAccess,
            period: _usagePeriod,
            apps: _usageApps,
            loading: _usageLoading,
            onPeriodChanged: _onUsagePeriodChanged,
            onRefresh: () => _loadUsageStats(_usagePeriod),
            onOpenUsageSettings: _screenTimeChannel.openUsageAccessSettings,
          ),
          ChildKabarTab(
            sendingPresetId: _sendingPresetId,
            onSendPreset: _sendMessagePreset,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 1) {
            unawaited(_loadUsageStats(_usagePeriod));
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.childTabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.hourglass_empty_outlined),
            selectedIcon: const Icon(Icons.hourglass_bottom),
            label: l10n.childTabScreen,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.childTabMessages,
          ),
        ],
      ),
    );
  }
}

class _ChildLanguageOption extends StatelessWidget {
  const _ChildLanguageOption({
    required this.label,
    required this.selected,
    required this.refresh,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool refresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (refresh
              ? VisualRefreshColors.accentTint
              : AppColors.teal.withValues(alpha: 0.12))
          : (refresh ? VisualRefreshColors.warmTint : const Color(0xFFF3F5F7)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: refresh ? VisualRefreshColors.textPrimary : null,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected
                    ? (refresh ? VisualRefreshColors.accent : AppColors.teal)
                    : (refresh
                        ? VisualRefreshColors.textTertiary
                        : AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
