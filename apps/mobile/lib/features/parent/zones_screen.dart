import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';

class PlaceHit {
  PlaceHit({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;

  factory PlaceHit.fromJson(Map<String, dynamic> json) {
    return PlaceHit(
      placeId: json['placeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// Satu layar untuk Rumah / Sekolah / tempat lain + rute rumah→sekolah.
class PlacesEntryScreen extends ConsumerWidget {
  const PlacesEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tempat aman')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PaSectionCard(
            child: Text(
              'Atur rumah, sekolah, dan tempat lain (les, tempat sering dikunjungi). '
              'Cari dengan nama tempat — bukan angka koordinat. '
              'Kamu dapat notifikasi saat anak sampai di tempat itu.',
              style: TextStyle(color: AppColors.inkSoft, height: 1.4, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          if (children.items.isEmpty)
            const Text(AppStrings.noChildren)
          else
            ...children.items.map(
              (child) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(child: Icon(Icons.place)),
                  title: Text(
                    child.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  subtitle: const Text(
                    'Rumah, sekolah, tempat lain, dan rute',
                    style: TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 28),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlacesScreen(child: child),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;
  Map<String, dynamic>? _route;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/zones', query: {
        'childId': widget.child.id,
      });
      setState(() {
        _zones = (data['zones'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _zoneOf(String type) {
    for (final z in _zones) {
      if (z['type'] == type) return z;
    }
    return null;
  }

  List<Map<String, dynamic>> get _customZones =>
      _zones.where((z) => z['type'] == 'custom').toList();

  Future<void> _addBySearch(
    String type, {
    String? customLabel,
  }) async {
    final selected = await showModalBottomSheet<PlaceHit>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlaceSearchSheet(
        title: type == 'home'
            ? 'Cari alamat rumah'
            : type == 'school'
                ? 'Cari nama sekolah'
                : 'Cari tempat: ${customLabel ?? 'Tempat lain'}',
        hint: type == 'home'
            ? 'Contoh: Marine Parade, kode pos, nama kompleks'
            : type == 'school'
                ? 'Contoh: Tao Nan School, nama sekolah'
                : 'Contoh: nama les, mall, taman, alamat',
      ),
    );
    if (selected == null || !mounted) return;

    final radius = type == 'home'
        ? 120
        : type == 'school'
            ? 150
            : 120;
    final displayName = (customLabel != null && customLabel.trim().isNotEmpty)
        ? '${customLabel.trim()} · ${selected.name}'
        : selected.name;

    try {
      await ref.read(apiClientProvider).post('/api/v1/zones', body: {
        'childId': widget.child.id,
        'type': type,
        'lat': selected.lat,
        'lng': selected.lng,
        'radiusM': radius,
        'name': displayName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'home'
                ? 'Rumah disimpan: ${selected.name}'
                : type == 'school'
                    ? 'Sekolah disimpan: ${selected.name}'
                    : 'Tempat disimpan: $displayName',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan tempat: $e')),
      );
    }
  }

  Future<void> _addCustomPlace() async {
    final labelCtrl = TextEditingController();
    const presets = <String>[
      'Tempat les',
      'Rumah nenek',
      'Teman',
      'Mall / tempat main',
      'Tempat baru',
    ];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tambah tempat aman',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih jenis, atau tulis sendiri. Lalu cari alamatnya.',
                style: TextStyle(color: AppColors.inkSoft, height: 1.35),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in presets)
                    ActionChip(
                      label: Text(p),
                      onPressed: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Atau tulis nama sendiri',
                  hintText: 'Contoh: Les piano Blok M',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final t = labelCtrl.text.trim();
                  Navigator.pop(ctx, t.isEmpty ? 'Tempat lain' : t);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Lanjut cari alamat'),
              ),
            ],
          ),
        );
      },
    );

    if (chosen == null || !mounted) return;
    await _addBySearch('custom', customLabel: chosen);
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final id = zone['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus tempat?'),
        content: Text(
          'Hapus "${_zoneLabel(zone)}"? Notifikasi sampai di tempat ini akan berhenti.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/api/v1/zones/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tempat dihapus')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

  Future<void> _planRoute() async {
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    if (home == null || school == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi Rumah dan Sekolah dulu, baru rute bisa dibuat.'),
        ),
      );
      return;
    }
    setState(() {
      _routeLoading = true;
      _route = null;
    });
    try {
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/routes/safe',
        body: {
          'originLat': (home['lat'] as num).toDouble(),
          'originLng': (home['lng'] as num).toDouble(),
          'destLat': (school['lat'] as num).toDouble(),
          'destLng': (school['lng'] as num).toDouble(),
          'mode': 'walking',
        },
      );
      if (!mounted) return;
      setState(() {
        _route = data;
        _routeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _routeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal buat rute: $e')),
      );
    }
  }

  String _zoneLabel(Map<String, dynamic> z) {
    final name = z['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return '${z['type']}';
  }

  @override
  Widget build(BuildContext context) {
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    final customs = _customZones;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tempat · ${widget.child.name}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PlaceCard(
                  icon: Icons.home_rounded,
                  title: 'Rumah',
                  subtitle: home == null
                      ? 'Belum diatur — cari nama lokasi / alamat'
                      : _zoneLabel(home),
                  actionLabel: home == null ? 'Atur rumah' : 'Ganti rumah',
                  onPressed: () => _addBySearch('home'),
                ),
                const SizedBox(height: 10),
                _PlaceCard(
                  icon: Icons.school_rounded,
                  title: 'Sekolah',
                  subtitle: school == null
                      ? 'Belum diatur — cari nama sekolah'
                      : _zoneLabel(school),
                  actionLabel: school == null ? 'Atur sekolah' : 'Ganti sekolah',
                  onPressed: () => _addBySearch('school'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tempat lain',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Les, rumah nenek, mall, atau tempat baru yang anak akan kunjungi. '
                  'Saat anak sampai, kamu dapat notifikasi.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 10),
                if (customs.isEmpty)
                  PaSectionCard(
                    color: AppColors.sand.withValues(alpha: 0.45),
                    child: const Text(
                      'Belum ada tempat lain. Tambah di bawah.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                else
                  ...customs.map((z) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlaceCard(
                        icon: Icons.place_rounded,
                        title: _zoneLabel(z),
                        subtitle: 'Tempat aman tambahan',
                        actionLabel: 'Hapus',
                        onPressed: () => _deleteZone(z),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addCustomPlace,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Tambah tempat lain'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealDeep,
                    side: const BorderSide(color: AppColors.teal, width: 2),
                    minimumSize: const Size.fromHeight(52),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Rute aman rumah → sekolah',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Opsional. Pakai rumah dan sekolah di atas.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _routeLoading ? null : _planRoute,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  icon: _routeLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.route),
                  label: Text(
                    _routeLoading ? 'Menghitung rute...' : 'Buat rute aman',
                  ),
                ),
                if (_route != null) ...[
                  const SizedBox(height: 12),
                  PaSectionCard(
                    color: AppColors.mint.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rute siap',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jarak sekitar ${((_route!['distanceM'] as num?) ?? 0).round()} meter',
                        ),
                        Text(
                          _route!['avoidsReports'] == true
                              ? 'Menghindari area laporan komunitas'
                              : 'Rute standar',
                        ),
                        if (_route!['note'] != null)
                          Text(
                            '${_route!['note']}',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PaSectionCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            child: Icon(icon, color: AppColors.tealDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<PlaceHit> _hits = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_search(value.trim()));
    });
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() {
        _hits = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/places/search',
        query: {'q': q},
      );
      final hits = (data['places'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PlaceHit.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
        if (hits.isEmpty) {
          _error = 'Tidak ketemu. Coba nama lain atau kode pos.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      String msg =
          'Pencarian gagal. Key Google Maps di server belum bisa dipakai untuk cari tempat.';
      if (raw.contains('maps_key_missing')) {
        msg = 'GOOGLE_MAPS_API_KEY belum diisi di Render.';
      } else if (raw.contains('maps_key_restricted') ||
          raw.contains('not authorized') ||
          raw.contains('REQUEST_DENIED')) {
        msg =
            'Key Maps di server diblokir Google (biasanya key khusus Android). '
            'Perlu key server terpisah: aktifkan Places API + Geocoding.';
      }
      setState(() {
        _loading = false;
        _error = msg;
        _hits = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: AppColors.inkSoft)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _hits.length,
                itemBuilder: (context, index) {
                  final hit = _hits[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined, color: AppColors.teal),
                    title: Text(
                      hit.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(hit.address),
                    onTap: () => Navigator.pop(context, hit),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep old entry names working for navigation.
class ZonesEntryScreen extends PlacesEntryScreen {
  const ZonesEntryScreen({super.key});
}

class ZonesScreen extends PlacesScreen {
  const ZonesScreen({super.key, required super.child});
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earth * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180;
