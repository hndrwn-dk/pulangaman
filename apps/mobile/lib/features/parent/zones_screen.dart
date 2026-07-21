import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
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

/// Tab Zona: hub Zona Aman (bottom nav tetap di ParentShell).
class PlacesEntryScreen extends ConsumerWidget {
  const PlacesEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlacesHubScreen();
  }
}

/// Detail tempat untuk satu anak (dari child detail).
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlacesHubScreen(lockedChild: child, showBack: true);
  }
}

class PlacesHubScreen extends ConsumerStatefulWidget {
  const PlacesHubScreen({
    super.key,
    this.lockedChild,
    this.showBack = false,
  });

  final ChildSummary? lockedChild;
  final bool showBack;

  @override
  ConsumerState<PlacesHubScreen> createState() => _PlacesHubScreenState();
}

class _PlacesHubScreenState extends ConsumerState<PlacesHubScreen> {
  String? _selectedChildId;
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;
  Map<String, dynamic>? _route;
  bool _routeLoading = false;
  bool _editMode = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Map<String, ChildGender> _genders = {};

  ChildSummary? get _selected {
    final locked = widget.lockedChild;
    if (locked != null) return locked;
    final items = ref.read(childrenControllerProvider).items;
    if (items.isEmpty) return null;
    return items.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => items.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.lockedChild?.id;
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      await _reloadForSelected();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGenders() async {
    final children = ref.read(childrenControllerProvider).items;
    final map = <String, ChildGender>{};
    for (final c in children) {
      var g = await ChildGenderStore.instance.get(c.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(c.name);
      }
      map[c.id] = g;
    }
    if (!mounted) return;
    setState(() {
      _genders
        ..clear()
        ..addAll(map);
    });
  }

  Future<void> _reloadForSelected() async {
    final child = _selected;
    if (child == null) {
      setState(() {
        _zones = [];
        _route = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _route = null;
    });
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/zones',
        query: {'childId': child.id},
      );
      if (!mounted) return;
      setState(() {
        _zones = (data['zones'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
      unawaited(_maybePlanRoute());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _selectChild(String id) {
    if (widget.lockedChild != null) return;
    if (_selectedChildId == id) return;
    setState(() {
      _selectedChildId = id;
      _editMode = false;
      _route = null;
    });
    unawaited(_reloadForSelected());
  }

  Map<String, dynamic>? _zoneOf(String type) {
    for (final z in _zones) {
      if (z['type'] == type) return z;
    }
    return null;
  }

  List<Map<String, dynamic>> get _orderedPlaces {
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    final customs =
        _zones.where((z) => z['type'] == 'custom').toList(growable: false);
    final list = <Map<String, dynamic>>[
      if (home != null) home,
      if (school != null) school,
      ...customs,
    ];
    if (_query.isEmpty) return list;
    return list.where((z) {
      final label = _displayTitle(z).toLowerCase();
      final sub = _displaySubtitle(z).toLowerCase();
      return label.contains(_query) || sub.contains(_query);
    }).toList();
  }

  String _rawName(Map<String, dynamic> z) {
    final name = z['name']?.toString().trim() ?? '';
    return name;
  }

  String _displayTitle(Map<String, dynamic> z) {
    final type = z['type']?.toString();
    if (type == 'home') return 'Rumah';
    if (type == 'school') return 'Sekolah';
    final name = _rawName(z);
    if (name.isEmpty) return 'Tempat aman';
    final parts = name.split(' · ');
    return parts.first.trim().isEmpty ? name : parts.first.trim();
  }

  String _displaySubtitle(Map<String, dynamic> z) {
    final name = _rawName(z);
    final type = z['type']?.toString();
    if (type == 'home' || type == 'school') {
      if (name.isEmpty) return 'Belum ada alamat';
      return name;
    }
    if (name.contains(' · ')) {
      return name.split(' · ').skip(1).join(' · ');
    }
    return 'Tempat aman tambahan';
  }

  Future<void> _addBySearch(
    String type, {
    String? customLabel,
  }) async {
    final child = _selected;
    if (child == null) return;
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
        'childId': child.id,
        'type': type,
        'lat': selected.lat,
        'lng': selected.lng,
        'radiusM': radius,
        'name': displayName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disimpan: $displayName')),
      );
      await _reloadForSelected();
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

  Future<void> _showAddMenu() async {
    final child = _selected;
    if (child == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppColors.teal),
              title: const Text('Rumah'),
              onTap: () => Navigator.pop(ctx, 'home'),
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded, color: Color(0xFF3B82F6)),
              title: const Text('Sekolah'),
              onTap: () => Navigator.pop(ctx, 'school'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.place_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Tempat lain'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'custom') {
      await _addCustomPlace();
    } else {
      await _addBySearch(choice);
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final id = zone['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus tempat?'),
        content: Text('Hapus "${_displayTitle(zone)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
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
      await _reloadForSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

  Future<void> _maybePlanRoute() async {
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    if (home == null || school == null) return;
    setState(() => _routeLoading = true);
    try {
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/routes/safe',
        body: {
          'originLat': (school['lat'] as num).toDouble(),
          'originLng': (school['lng'] as num).toDouble(),
          'destLat': (home['lat'] as num).toDouble(),
          'destLng': (home['lng'] as num).toDouble(),
          'mode': 'walking',
        },
      );
      if (!mounted) return;
      setState(() {
        _route = data;
        _routeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _routeLoading = false;
      });
    }
  }

  Future<void> _planRouteManual() async {
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
    await _maybePlanRoute();
  }

  String _routeDistanceLabel() {
    final m = (_route?['distanceM'] as num?)?.toDouble() ?? 0;
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  String _routeEtaLabel() {
    final m = (_route?['distanceM'] as num?)?.toDouble() ?? 0;
    final minutes = (m / 83.33).round().clamp(1, 180);
    return 'Estimasi $minutes menit';
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final items = children.items;

    if (widget.lockedChild == null && items.isNotEmpty) {
      final ids = items.map((c) => c.id).toSet();
      if (_selectedChildId == null || !ids.contains(_selectedChildId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedChildId = items.first.id);
          unawaited(_reloadForSelected());
        });
      }
    }

    final selected = _selected;
    final places = _orderedPlaces;
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    final missingSlots = <String>[
      if (home == null) 'home',
      if (school == null) 'school',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _reloadForSelected,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zona Aman',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rumah, sekolah, dan tempat sering dikunjungi',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFD8F5E8),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: selected == null ? null : _showAddMenu,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari tempat...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                  ),
                ),
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  AppStrings.noChildren,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ] else ...[
                if (widget.lockedChild == null) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'PILIH ANAK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = items[i];
                        final selectedChip = c.id == selected?.id;
                        return _ChildChip(
                          name: c.name,
                          selected: selectedChip,
                          gender: _genders[c.id] ??
                              ChildGenderStore.guessFromName(c.name),
                          onTap: () => _selectChild(c.id),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected == null
                            ? 'Tempat'
                            : 'Tempat ${selected.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _editMode = !_editMode),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _editMode ? 'Selesai' : 'Edit ›',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (places.isEmpty && missingSlots.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration,
                      child: Text(
                        _query.isEmpty
                            ? 'Belum ada tempat. Tambah rumah atau sekolah.'
                            : 'Tidak ada tempat yang cocok.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else ...[
                    ...places.map((z) {
                      final type = z['type']?.toString() ?? 'custom';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlaceListCard(
                          title: _displayTitle(z),
                          subtitle: _displaySubtitle(z),
                          type: type,
                          editMode: _editMode,
                          onTap: () {
                            if (_editMode) {
                              _deleteZone(z);
                            } else if (type == 'home' || type == 'school') {
                              _addBySearch(type);
                            }
                          },
                          onDelete:
                              _editMode ? () => _deleteZone(z) : null,
                        ),
                      );
                    }),
                    if (!_editMode)
                      ...missingSlots.map((slot) {
                        final isHome = slot == 'home';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlaceListCard(
                            title: isHome ? 'Rumah' : 'Sekolah',
                            subtitle: isHome
                                ? 'Belum diatur — ketuk untuk cari'
                                : 'Belum diatur — ketuk untuk cari',
                            type: slot,
                            empty: true,
                            onTap: () => _addBySearch(slot),
                          ),
                        );
                      }),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Rute Pulang',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_routeLoading)
                    Container(
                      height: 96,
                      alignment: Alignment.center,
                      decoration: _cardDecoration,
                      child: const CircularProgressIndicator(),
                    )
                  else if (_route != null && home != null && school != null)
                    _RouteCard(
                      fromLabel: 'Sekolah',
                      toLabel: 'Rumah',
                      meta: '${_routeDistanceLabel()} · ${_routeEtaLabel()}',
                      onTap: _planRouteManual,
                    )
                  else
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _planRouteManual,
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          decoration: _cardDecoration,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.route_rounded, color: AppColors.teal),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Buat rute Sekolah → Rumah',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                _DashedAddButton(
                  label: 'Tambah tempat baru',
                  onTap: selected == null ? () {} : _showAddMenu,
                ),
              ],
            ],
          ),
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
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
);

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.gender,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final ChildGender gender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealDeep : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: const Color(0xFFE2E6EA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildAvatar(name: name, gender: gender, size: 30),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceListCard extends StatelessWidget {
  const _PlaceListCard({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.onTap,
    this.editMode = false,
    this.empty = false,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final String type;
  final VoidCallback onTap;
  final bool editMode;
  final bool empty;
  final VoidCallback? onDelete;

  Color get _iconBg {
    switch (type) {
      case 'home':
        return const Color(0xFFD8F5E8);
      case 'school':
        return const Color(0xFFDCEBFF);
      default:
        return const Color(0xFFFFF0DC);
    }
  }

  Color get _iconFg {
    switch (type) {
      case 'home':
        return AppColors.tealDeep;
      case 'school':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFD97706);
    }
  }

  IconData get _icon {
    switch (type) {
      case 'home':
        return Icons.home_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  bool get _isRouteTag => type == 'custom';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: _cardDecoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: _iconFg, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: empty ? AppColors.inkSoft : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (editMode && onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.coral),
                  )
                else if (!empty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isRouteTag
                          ? const Color(0xFFFFE8C8)
                          : const Color(0xFFD8F5E8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isRouteTag ? 'RUTE' : 'AMAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: _isRouteTag
                            ? const Color(0xFFB45309)
                            : AppColors.tealDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkSoft,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.fromLabel,
    required this.toLabel,
    required this.meta,
    required this.onTap,
  });

  final String fromLabel;
  final String toLabel;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: _cardDecoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        color: AppColors.tealDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromLabel → $toLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.inkSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _RouteDot(label: fromLabel),
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    _RouteDot(label: toLabel),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F6F1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.teal.withValues(alpha: 0.55),
            radius: 16,
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppColors.tealDeep),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.tealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _hits.length,
                itemBuilder: (context, index) {
                  final hit = _hits[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.teal,
                    ),
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
