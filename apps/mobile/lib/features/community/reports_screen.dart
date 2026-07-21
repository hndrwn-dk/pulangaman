import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';

enum _ReportFilter { all, verified, active }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  _ReportFilter _filter = _ReportFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/reports');
      setState(() {
        _reports = (data['reports'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _ReportFilter.verified:
        return _reports.where((r) => r['status'] == 'verified').toList();
      case _ReportFilter.active:
        return _reports.where((r) => r['status'] == 'active').toList();
      case _ReportFilter.all:
        return _reports;
    }
  }

  String _categoryTitle(Map<String, dynamic> r) {
    final note = (r['note'] as String?)?.trim();
    if (note != null && note.isNotEmpty) return note;
    switch (r['category']?.toString()) {
      case 'hazard':
        return 'Bahaya / Jalan Rusak';
      case 'traffic':
        return 'Lalu Lintas';
      case 'crowd':
        return 'Kerumunan';
      default:
        return 'Laporan Lain';
    }
  }

  String _categoryLabel(String? raw) {
    switch (raw) {
      case 'hazard':
        return 'Hazard';
      case 'traffic':
        return 'Lalu lintas';
      case 'crowd':
        return 'Kerumunan';
      default:
        return 'Lainnya';
    }
  }

  String _fmtExpiry(String? raw) {
    final at = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (at == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return '${at.day} ${months[at.month - 1]} ${at.year}, $hm';
  }

  Future<void> _addReport() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}
    if (!mounted) return;

    final noteCtrl = TextEditingController();
    String category = 'hazard';
    final ok = await showModalBottomSheet<bool>(
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
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tambah Pin',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Jenis'),
                    items: const [
                      DropdownMenuItem(
                        value: 'hazard',
                        child: Text('Bahaya / Jalan rusak'),
                      ),
                      DropdownMenuItem(
                        value: 'traffic',
                        child: Text('Lalu lintas'),
                      ),
                      DropdownMenuItem(
                        value: 'crowd',
                        child: Text('Kerumunan'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? 'hazard'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Contoh: Jalan rusak',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pos == null
                        ? 'Lokasi: memakai titik default (izin GPS belum ada)'
                        : 'Lokasi: ${pos.latitude.toStringAsFixed(5)}, '
                            '${pos.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.teal),
                    child: const Text('Simpan pin'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/reports', body: {
        'category': category,
        'note': noteCtrl.text.trim(),
        'lat': pos?.latitude ?? -6.2,
        'lng': pos?.longitude ?? 106.816,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin ditambahkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _verify(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/reports/$id/verify');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan diverifikasi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal verifikasi: $e')),
      );
    }
  }

  Future<void> _markStillThere(Map<String, dynamic> r) async {
    if (r['status'] == 'verified') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sudah terverifikasi. Terima kasih.')),
      );
      return;
    }
    await _verify(r['id'] as String);
  }

  void _markFixed(Map<String, dynamic> r) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Terima kasih. Saran “sudah diperbaiki” dicatat untuk ditinjau.',
        ),
      ),
    );
  }

  Set<Marker> get _markers {
    final out = <Marker>{};
    for (final r in _filtered) {
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final id = r['id']?.toString() ?? '$lat,$lng';
      out.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: _categoryTitle(r)),
        ),
      );
    }
    return out;
  }

  LatLng get _mapCenter {
    final m = _markers;
    if (m.isEmpty) return const LatLng(-6.2, 106.816);
    return m.first.position;
  }

  @override
  Widget build(BuildContext context) {
    final verified =
        _reports.where((r) => r['status'] == 'verified').length;
    final expired = _reports.where((r) {
      final status = r['status']?.toString();
      if (status == 'expired') return true;
      final at = DateTime.tryParse(r['expires_at']?.toString() ?? '');
      return status == 'active' && at != null && at.isBefore(DateTime.now());
    }).length;
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReport,
        backgroundColor: AppColors.tealDeep,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Tambah Pin',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Laporan Komunitas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0DC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.alarm_rounded,
                                  color: Color(0xFFE85A7A),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pin kadaluarsa 72 jam kecuali diverifikasi. '
                                    'Tidak ada marketplace orang asing.',
                                    style: TextStyle(
                                      color: Color(0xFF9A5B00),
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _StatMini(
                                  value: '${_reports.length}',
                                  label: 'Total Laporan',
                                  valueColor: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatMini(
                                  value: '$verified',
                                  label: 'Terverifikasi',
                                  valueColor: AppColors.teal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatMini(
                                  value: '$expired',
                                  label: 'Kadaluarsa',
                                  valueColor: AppColors.coral,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Peta Area',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              height: 180,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _mapCenter,
                                  zoom: _markers.isEmpty ? 12 : 14,
                                ),
                                markers: _markers,
                                liteModeEnabled: true,
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                                mapToolbarEnabled: false,
                                compassEnabled: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Daftar Laporan',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              PopupMenuButton<_ReportFilter>(
                                initialValue: _filter,
                                onSelected: (v) => setState(() => _filter = v),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: _ReportFilter.all,
                                    child: Text('Semua'),
                                  ),
                                  PopupMenuItem(
                                    value: _ReportFilter.verified,
                                    child: Text('Terverifikasi'),
                                  ),
                                  PopupMenuItem(
                                    value: _ReportFilter.active,
                                    child: Text('Aktif'),
                                  ),
                                ],
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Filter',
                                      style: TextStyle(
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      color: AppColors.teal,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (list.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: _cardDecoration,
                              child: const Text(
                                'Belum ada laporan aktif',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            ...list.map((r) {
                              final verifiedStatus = r['status'] == 'verified';
                              final lat = (r['lat'] as num?)?.toDouble();
                              final lng = (r['lng'] as num?)?.toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: _cardDecoration,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE8E6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Color(0xFFE8913A),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        _categoryTitle(r),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 15.5,
                                                        ),
                                                      ),
                                                    ),
                                                    if (verifiedStatus) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                            0xFFD8F5E8,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            999,
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          'VERIFIED',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: AppColors
                                                                .tealDeep,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_categoryLabel(r['category']?.toString())} · '
                                                  '${lat == null ? 'Tanpa koordinat' : 'Koordinat tersedia'}',
                                                  style: const TextStyle(
                                                    color: AppColors.inkSoft,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (lat != null && lng != null) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.place_rounded,
                                              size: 16,
                                              color: AppColors.coral,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.alarm_rounded,
                                            size: 16,
                                            color: Color(0xFFE85A7A),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Kadaluarsa: ${_fmtExpiry(r['expires_at']?.toString())}',
                                            style: const TextStyle(
                                              color: AppColors.coral,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _markStillThere(r),
                                              icon: const Icon(
                                                Icons.front_hand_outlined,
                                                size: 18,
                                              ),
                                              label: const Text('Masih Ada'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.ink,
                                                side: const BorderSide(
                                                  color: Color(0xFFE2E6EA),
                                                ),
                                                backgroundColor:
                                                    const Color(0xFFF3F5F7),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _markFixed(r),
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 18,
                                                color: AppColors.teal,
                                              ),
                                              label: const Text(
                                                'Sudah Diperbaiki',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.ink,
                                                side: const BorderSide(
                                                  color: Color(0xFFE2E6EA),
                                                ),
                                                backgroundColor:
                                                    const Color(0xFFF3F5F7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ],
);

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
