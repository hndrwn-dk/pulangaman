import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class SafeRouteScreen extends ConsumerStatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  ConsumerState<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends ConsumerState<SafeRouteScreen> {
  final _destLat = TextEditingController(text: '-6.175');
  final _destLng = TextEditingController(text: '106.827');
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _destLat.dispose();
    _destLng.dispose();
    super.dispose();
  }

  Future<void> _plan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}

      final api = ref.read(apiClientProvider);
      final data = await api.post('/api/v1/routes/safe', body: {
        'originLat': pos?.latitude ?? -6.2,
        'originLng': pos?.longitude ?? 106.816,
        'destLat': double.parse(_destLat.text),
        'destLng': double.parse(_destLng.text),
        'mode': 'walking',
      });
      setState(() {
        _result = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rute aman')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Rute v1 memakai Directions (jika kunci tersedia) dan menghindari pin laporan. Tanpa ML.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destLat,
            decoration: const InputDecoration(
              labelText: 'Tujuan latitude',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _destLng,
            decoration: const InputDecoration(
              labelText: 'Tujuan longitude',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _plan,
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text(_loading ? 'Menghitung…' : 'Rencanakan rute'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Text(
              _result!['note']?.toString() ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Provider: ${_result!['provider']}'),
            Text('Jarak: ${_result!['distanceM']} m'),
            Text('Hindari laporan: ${_result!['avoidsReports']}'),
            Text('Pin dipertimbangkan: ${_result!['reportsConsidered']}'),
            if (_result!['detourApplied'] == true)
              const Text('Detour sederhana diterapkan'),
            const SizedBox(height: 8),
            Text(
              'Titik jalur: ${(_result!['path'] as List?)?.length ?? 0}',
            ),
          ],
        ],
      ),
    );
  }
}
