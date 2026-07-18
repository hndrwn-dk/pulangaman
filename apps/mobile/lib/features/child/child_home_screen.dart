import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/offline_queue.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _tracking = false;
  bool _panicMode = false;
  int _panicTaps = 0;
  DateTime? _lastTapAt;
  String? _status;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startTracking);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((_) => _flushQueue());
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
    final now = DateTime.now();
    if (_lastTapAt == null ||
        now.difference(_lastTapAt!) > const Duration(seconds: 2)) {
      _panicTaps = 0;
    }
    _lastTapAt = now;
    _panicTaps += 1;
    setState(() {});

    if (_panicTaps < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.panicConfirm} ($_panicTaps/3)')),
      );
      return;
    }

    _panicTaps = 0;
    setState(() => _panicMode = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.offlineQueued)),
        );
      }
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/panic/trigger', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.panicSent)),
        );
      }
    } catch (_) {
      await ref.read(offlineQueueProvider).enqueue('panic', body);
      await _smsFallback();
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tracking ? AppStrings.trackingOn : AppStrings.trackingOff,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_status ?? ''),
            const Spacer(),
            SizedBox(
              height: 180,
              child: FilledButton(
                onPressed: _onPanicTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: const CircleBorder(),
                ),
                child: Text(
                  AppStrings.panicButton,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.panicConfirm,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
