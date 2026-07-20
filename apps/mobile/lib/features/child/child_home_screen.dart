import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/offline_queue.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_channel.dart';
import 'panic_tap_counter.dart';

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
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
  final ScreenTimeChannel _screenTimeChannel = ScreenTimeChannel();

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
    }
  }

  Future<void> _setupScreenTimeAndRewards() => _refreshScreenTimeAndRewards();

  Future<void> _refreshScreenTimeAndRewards() async {
    await _syncScreenTimePermissions();
    await _loadRewards();
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
      setState(() => _status = 'Izin lokasi ditolak');
      return;
    }
    setState(() {
      _tracking = true;
      _status = AppStrings.trackingOn;
    });
    _scheduleTick();
  }

  void _scheduleTick() {
    _timer?.cancel();
    final interval = _panicMode
        ? const Duration(seconds: 3)
        : const Duration(seconds: 10);
    _timer = Timer.periodic(interval, (_) => _pushLocation());
  }

  Future<void> _pushLocation() async {
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
        setState(() => _status = AppStrings.offlineQueued);
        return;
      }

      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/location', body: body);
      setState(() => _status = AppStrings.trackingOn);
      await _flushQueue();
    } catch (e) {
      setState(() => _status = 'Gagal kirim lokasi');
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
    _scheduleTick();

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

  Future<void> _smsFallback() async {
    final uri = Uri.parse(
      'sms:?body=${Uri.encodeComponent('PulangAman PANIK — butuh bantuan sekarang.')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.brand} · ${auth.name ?? ''}'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Hai, ${auth.name ?? 'Sahabat'}!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const Text('Tetap aman, kumpulkan poin, dan beri kabar keluarga.'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PaStatusPill(
                label: _tracking ? 'Lokasi aktif' : 'Lokasi mati',
                icon: _tracking ? Icons.location_on : Icons.location_off,
                color: _tracking ? AppColors.success : AppColors.danger,
              ),
              PaStatusPill(
                label: '$_points poin · $_streak hari',
                icon: Icons.star,
                color: AppColors.coral,
              ),
              PaStatusPill(
                label: _usageAccess && _accessibility ? 'Aturan layar aktif' : 'Izin layar belum lengkap',
                icon: Icons.hourglass_bottom,
                color: AppColors.lavender,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PaSectionCard(
            color: AppColors.coral.withValues(alpha: 0.12),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: FilledButton(
                    onPressed: (_panicInFlight || _panicTapCounter.isOnCooldown)
                        ? null
                        : _onPanicTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      AppStrings.panicButton,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
                const Text(AppStrings.panicConfirm, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(_status ?? '', textAlign: TextAlign.center),
              ],
            ),
          ),
          if (!_usageAccess || !_accessibility) ...[
            const SizedBox(height: AppSpacing.md),
            PaSectionCard(
              color: AppColors.lavender.withValues(alpha: 0.16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Aktifkan perlindungan waktu layar',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('PulangAman, Telepon, dan Pesan tidak pernah diblokir.'),
                  const SizedBox(height: 10),
                  if (!_usageAccess)
                    OutlinedButton(
                      onPressed: () =>
                          _screenTimeChannel.openUsageAccessSettings(),
                      child: const Text('Izinkan akses pemakaian'),
                    ),
                  if (!_accessibility)
                    OutlinedButton(
                      onPressed: () =>
                          _screenTimeChannel.openAccessibilitySettings(),
                      child: const Text('Aktifkan pemblokiran aplikasi'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
