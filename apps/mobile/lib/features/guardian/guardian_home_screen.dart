import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/ws_client.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class GuardianHomeScreen extends ConsumerStatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  ConsumerState<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends ConsumerState<GuardianHomeScreen> {
  final _ws = WsClient();
  List<Map<String, dynamic>> _invites = [];
  String? _alertId;
  String? _childId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _loadInvites();
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    final userId = auth.userId;
    if (token != null && userId != null) {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      _ws.subscribe('guardian:$userId');
    }
    await ref.read(apiClientProvider).post('/api/v1/guardians/presence', body: {
      'status': 'ONLINE',
    });
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'guardian:alert_notify') {
      setState(() {
        _alertId = payload['alertId'] as String?;
        _childId = payload['childId'] as String?;
      });
    }
  }

  Future<void> _loadInvites() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians/invites');
      setState(() {
        _invites = (data['invites'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _accept(String childId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/accept', body: {'childId': childId});
    await _loadInvites();
  }

  Future<void> _ack() async {
    if (_alertId == null) return;
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/guardian-ack');
  }

  Future<void> _shareLocation() async {
    if (_alertId == null) return;
    final pos = await Geolocator.getCurrentPosition();
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/share-location', body: {
      'alertId': _alertId,
      'lat': pos.latitude,
      'lng': pos.longitude,
    });
  }

  Future<void> _needBackup() async {
    if (_alertId == null) return;
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/need-backup', body: {
      'notes': 'Memerlukan bantuan tambahan',
    });
  }

  @override
  void dispose() {
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppStrings.guardianGuidance,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.activeAlerts,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_alertId == null)
            const Text('Tidak ada peringatan aktif')
          else ...[
            Card(
              color: const Color(0xFFFEE4E2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Peringatan $_alertId'),
                    if (_childId != null) Text('Anak: $_childId'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _ack,
                      child: const Text(AppStrings.ackAlert),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _shareLocation,
                      child: const Text(AppStrings.shareLocation),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _needBackup,
                      child: const Text(AppStrings.needBackup),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Undangan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_invites.isEmpty)
            const Text(AppStrings.noInvites)
          else
            ..._invites.map(
              (invite) => ListTile(
                title: Text('${invite['child_name']}'),
                subtitle: Text('Dari ${invite['parent_name']}'),
                trailing: FilledButton(
                  onPressed: () => _accept(invite['child_id'] as String),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  child: const Text(AppStrings.acceptInvite),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
