import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/storage/offline_queue.dart';
import '../../core/strings.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_channel.dart';
import 'child_beranda_tab.dart';
import 'child_kabar_tab.dart';
import 'child_layar_tab.dart';
import 'child_usage_utils.dart';
import 'location_tracking_channel.dart';
import 'panic_tap_counter.dart';

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
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
  final ScreenTimeChannel _screenTimeChannel = ScreenTimeChannel();
  final LocationTrackingChannel _locationChannel = LocationTrackingChannel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_startTracking);
    Future.microtask(_setupScreenTimeAndRewards);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((_) => _flushQueue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshScreenTimeAndRewards());
      unawaited(_ensureNativeTracking());
    }
  }

  Future<void> _setupScreenTimeAndRewards() => _refreshScreenTimeAndRewards();

  Future<void> _refreshScreenTimeAndRewards() async {
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _usageApps = []);
    } finally {
      if (mounted) setState(() => _usageLoading = false);
    }
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

  Future<void> _startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _status = 'Izin lokasi ditolak');
      return;
    }

    // Android 10+: request "Allow all the time" so tracking survives background.
    final always = await Permission.locationAlways.request();
    await Permission.notification.request();

    final token = ref.read(authControllerProvider).token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _status = 'Sesi belum siap');
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
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _status = always.isGranted
            ? AppStrings.trackingOn
            : 'Lokasi aktif — izinkan "Selalu" agar tetap jalan di background';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _status = AppStrings.trackingOn;
      });
      unawaited(_pushLocationOnce());
    }
  }

  Future<void> _ensureNativeTracking() async {
    if (!_tracking) return;
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
    } catch (_) {}
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

  Future<void> _pushLocationOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final body = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracyM': pos.accuracy,
        'source': _panicMode ? 'panic' : 'active',
      };

      final online = await _isOnline();
      if (!online) {
        await ref.read(offlineQueueProvider).enqueue('location', body);
        if (mounted) setState(() => _status = AppStrings.offlineQueued);
        return;
      }

      await ref.read(apiClientProvider).post('/api/v1/location', body: body);
      if (mounted) setState(() => _status = AppStrings.trackingOn);
      await _flushQueue();
    } catch (_) {
      if (mounted) setState(() => _status = 'Gagal kirim lokasi');
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.panicConfirm} ($tapResult/3)'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _panicInFlight = true;
    _panicTapCounter.markTriggered();
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
          const SnackBar(content: Text(AppStrings.offlineQueued)),
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
          const SnackBar(
            content: Text(AppStrings.panicSent),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      await ref.read(offlineQueueProvider).enqueue('panic', body);
      await _smsFallback();
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
        SnackBar(content: Text('Kabar terkirim: ${preset.label}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim kabar. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _sendingPresetId = null);
    }
  }

  Future<void> _smsFallback() async {
    final uri = Uri.parse(
      'sms:?body=${Uri.encodeComponent('PulangAman PANIK — butuh bantuan sekarang.')}',
    );
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
    // Keep native FGS running after Flutter dispose so background tracking continues.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final childName = auth.name ?? 'Sahabat';

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.brand} · $childName'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await _locationChannel.stop();
              } catch (_) {}
              await ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
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
            onPanicTap: _onPanicTap,
            onOpenUsageSettings: _screenTimeChannel.openUsageAccessSettings,
            onOpenAccessibilitySettings:
                _screenTimeChannel.openAccessibilitySettings,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_empty_outlined),
            selectedIcon: Icon(Icons.hourglass_bottom),
            label: 'Layar',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Kabar',
          ),
        ],
      ),
    );
  }
}
