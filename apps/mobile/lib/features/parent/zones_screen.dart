import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/ws_client.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'trip_route_card.dart';
import 'vr_sheet_chrome.dart';

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
  const PlacesEntryScreen({
    super.key,
    this.lockedChild,
    this.readOnly = false,
  });

  final ChildSummary? lockedChild;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlacesHubScreen(
      lockedChild: lockedChild,
      readOnly: readOnly,
      showBack: lockedChild != null || readOnly,
    );
  }
}

/// Detail lokasi untuk satu anak (dari child detail).
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key, required this.child, this.readOnly = false});

  final ChildSummary child;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlacesHubScreen(
      lockedChild: child,
      showBack: true,
      readOnly: readOnly || child.isViewOnlyAccess,
    );
  }
}

class PlacesHubScreen extends ConsumerStatefulWidget {
  const PlacesHubScreen({
    super.key,
    this.lockedChild,
    this.showBack = false,
    this.readOnly = false,
  });

  final ChildSummary? lockedChild;
  final bool showBack;
  final bool readOnly;

  @override
  ConsumerState<PlacesHubScreen> createState() => _PlacesHubScreenState();
}

class _PlacesHubScreenState extends ConsumerState<PlacesHubScreen> {
  String? _selectedChildId;
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;
  Map<String, dynamic>? _trip;
  bool _tripLoading = false;
  bool _editMode = false;
  final _searchCtrl = TextEditingController();
  final _ws = WsClient();
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

  /// View-tier guardians never mutate zones, even if [readOnly] was omitted.
  bool get _effectiveReadOnly =>
      widget.readOnly || (_selected?.isViewOnlyAccess ?? false);

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
      await _connectWs();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  Future<void> _connectWs() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      final child = _selected;
      if (child != null) _ws.subscribe('child:${child.id}');
    } catch (_) {}
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    final child = _selected;
    if (child == null) return;
    if (payload['childId'] != child.id) return;
    if (event == 'parent:trip_progress' ||
        event == 'parent:trip_started' ||
        event == 'parent:trip_planned' ||
        event == 'parent:trip_arrived' ||
        event == 'parent:trip_cancelled') {
      if (event == 'parent:trip_cancelled' || event == 'parent:trip_arrived') {
        setState(() => _trip = event == 'parent:trip_arrived' ? payload : null);
        if (event == 'parent:trip_arrived') {
          // Keep arrived card briefly then refresh.
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) unawaited(_loadTrip());
          });
        } else {
          unawaited(_loadTrip());
        }
      } else {
        setState(() => _trip = payload);
      }
    }
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
        _trip = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _trip = null;
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
      await _loadTrip();
      _ws.subscribe('child:${child.id}');
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
      _trip = null;
    });
    unawaited(_reloadForSelected());
  }

  Map<String, dynamic>? _zoneOf(String type) {
    for (final z in _zones) {
      if (z['type'] == type) return z;
    }
    return null;
  }

  List<Map<String, dynamic>> _orderedPlaces(AppLocalizations l10n) {
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
      final label = _displayTitle(z, l10n).toLowerCase();
      final sub = _displaySubtitle(z, l10n).toLowerCase();
      return label.contains(_query) || sub.contains(_query);
    }).toList();
  }

  String _rawName(Map<String, dynamic> z) {
    final name = z['name']?.toString().trim() ?? '';
    return name;
  }

  String _displayTitle(Map<String, dynamic> z, AppLocalizations l10n) {
    final type = z['type']?.toString();
    if (type == 'home') return l10n.homeZone;
    if (type == 'school') return l10n.schoolZone;
    final name = _rawName(z);
    if (name.isEmpty) return l10n.safePlaceLabel;
    final parts = name.split(' · ');
    return parts.first.trim().isEmpty ? name : parts.first.trim();
  }

  String _displaySubtitle(Map<String, dynamic> z, AppLocalizations l10n) {
    final name = _rawName(z);
    final type = z['type']?.toString();
    if (type == 'home' || type == 'school') {
      if (name.isEmpty) return l10n.noAddressYet;
      return name;
    }
    if (name.contains(' · ')) {
      return name.split(' · ').skip(1).join(' · ');
    }
    return l10n.extraSafePlace;
  }

  String _tripPlaceLabel(Map<String, dynamic> zone, AppLocalizations l10n) {
    final title = _displayTitle(zone, l10n);
    final subtitle = _displaySubtitle(zone, l10n);
    if (subtitle.isEmpty ||
        subtitle == l10n.noAddressYet ||
        subtitle == l10n.extraSafePlace) {
      return title;
    }
    return '$title — $subtitle';
  }

  Future<void> _addBySearch(
    String type, {
    String? customLabel,
  }) async {
    final child = _selected;
    if (child == null) return;
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final selected = refresh
        ? await showVrModalBottomSheet<PlaceHit>(
            context: context,
            builder: (ctx) => PlaceSearchSheet(
              title: type == 'home'
                  ? l10n.searchHomeAddress
                  : type == 'school'
                      ? l10n.searchSchoolName
                      : l10n.searchCustomPlace(
                          customLabel ?? l10n.otherPlaceLabel),
              hint: type == 'home'
                  ? l10n.homeSearchHint
                  : type == 'school'
                      ? l10n.schoolSearchHint
                      : l10n.customSearchHint,
            ),
          )
        : await showModalBottomSheet<PlaceHit>(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => PlaceSearchSheet(
              title: type == 'home'
                  ? l10n.searchHomeAddress
                  : type == 'school'
                      ? l10n.searchSchoolName
                      : l10n.searchCustomPlace(
                          customLabel ?? l10n.otherPlaceLabel),
              hint: type == 'home'
                  ? l10n.homeSearchHint
                  : type == 'school'
                      ? l10n.schoolSearchHint
                      : l10n.customSearchHint,
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
        SnackBar(content: Text(l10n.placeSavedSnack(displayName))),
      );
      await _reloadForSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedSavePlace('$e'))),
      );
    }
  }

  /// Single add-place entry (replaces the short Home/School/Other list).
  /// Offers missing home/school chips plus custom presets, then address search.
  Future<void> _showAddMenu() async {
    if (_effectiveReadOnly) return;
    final child = _selected;
    if (child == null) return;
    await _openAddPlaceSheet();
  }

  Future<void> _openAddPlaceSheet() async {
    final refresh = visualRefreshOf(context);
    final missingHome = _zoneOf('home') == null;
    final missingSchool = _zoneOf('school') == null;

    // Sheet owns its TextEditingController so it is not disposed while the
    // modal route is still animating out (that caused a red-screen assert).
    final Future<_AddPlaceChoice?> sheet = refresh
        ? showVrModalBottomSheet<_AddPlaceChoice>(
            context: context,
            builder: (ctx) => _AddPlaceSheet(
              missingHome: missingHome,
              missingSchool: missingSchool,
            ),
          )
        : showModalBottomSheet<_AddPlaceChoice>(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => _AddPlaceSheet(
              missingHome: missingHome,
              missingSchool: missingSchool,
            ),
          );

    final chosen = await sheet;
    if (chosen == null || !mounted) return;
    if (chosen.type == 'custom') {
      await _addBySearch('custom', customLabel: chosen.customLabel);
    } else {
      await _addBySearch(chosen.type);
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final id = zone['id']?.toString();
    if (id == null) return;
    final l10n = AppLocalizations.of(context);
    final placeName = _displayTitle(zone, l10n);
    final refresh = visualRefreshOf(context);
    final bool? ok;
    if (refresh) {
      ok = await showDialog<bool>(
        context: context,
        barrierColor: VisualRefreshColors.anchor.withValues(alpha: 0.45),
        builder: (ctx) => Dialog(
          backgroundColor: VisualRefreshColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.deletePlaceTitle,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    height: 1.25,
                    color: VisualRefreshColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: VisualRefreshColors.textSecondary,
                    ),
                    children: [
                      TextSpan(text: '${l10n.delete} "'),
                      TextSpan(
                        text: placeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: VisualRefreshColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: '"? ${l10n.deletePlaceCascadeNote}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: VisualRefreshColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: VisualRefreshColors.danger,
                        foregroundColor: VisualRefreshColors.background,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        l10n.delete,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deletePlaceTitle),
          content: Text(l10n.deletePlaceConfirm(placeName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
    }
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/api/v1/zones/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placeDeletedSnack)),
      );
      await _reloadForSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedDeletePlace('$e'))),
      );
    }
  }

  Future<void> _loadTrip() async {
    final child = _selected;
    if (child == null) return;
    setState(() => _tripLoading = true);
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/trips/active',
        query: {'childId': child.id},
      );
      if (!mounted) return;
      setState(() {
        _trip = data['trip'] as Map<String, dynamic>?;
        _tripLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trip = null;
        _tripLoading = false;
      });
    }
  }

  Future<void> _createTrip({
    required String fromZoneId,
    required String toZoneId,
    bool startImmediately = false,
  }) async {
    final child = _selected;
    if (child == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _tripLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).ensureFreshToken();
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/trips',
        body: {
          'childId': child.id,
          'fromZoneId': fromZoneId,
          'toZoneId': toZoneId,
          'mode': 'walking',
          'startImmediately': startImmediately,
        },
      );
      if (!mounted) return;
      setState(() {
        _trip = data['trip'] as Map<String, dynamic>?;
        _tripLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tripCreated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _tripLoading = false);
      final message = e is ApiException && e.isUnauthorized
          ? 'Sesi berakhir. Keluar lalu masuk ulang, lalu coba lagi.'
          : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _startTrip() async {
    final id = _trip?['id'] as String?;
    if (id == null) return;
    try {
      final data = await ref.read(apiClientProvider).post('/api/v1/trips/$id/start');
      if (!mounted) return;
      setState(() => _trip = data['trip'] as Map<String, dynamic>?);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancelTrip() async {
    final id = _trip?['id'] as String?;
    if (id == null) return;
    try {
      await ref.read(apiClientProvider).post('/api/v1/trips/$id/cancel');
      if (!mounted) return;
      setState(() => _trip = null);
    } catch (_) {}
  }

  Future<void> _suggestSchoolHome() async {
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    if (home == null || school == null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tripNeedTwoPlaces)),
      );
      return;
    }
    await _createTrip(
      fromZoneId: school['id'] as String,
      toZoneId: home['id'] as String,
      startImmediately: false,
    );
  }

  Future<void> _openCreateTripSheet() async {
    final l10n = AppLocalizations.of(context);
    if (_zones.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tripNeedTwoPlaces)),
      );
      return;
    }
    String? fromId =
        _zoneOf('school')?['id'] as String? ?? _zones.first['id'] as String?;
    String? toId = _zoneOf('home')?['id'] as String?;
    if (toId == fromId) {
      for (final z in _zones) {
        final id = z['id'] as String?;
        if (id != null && id != fromId) {
          toId = id;
          break;
        }
      }
    }

    final refresh = visualRefreshOf(context);

    Widget buildSheet(BuildContext ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final body = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refresh) ...[
                const VrSheetDragHandle(),
                const SizedBox(height: 16),
                VrSheetTitle(l10n.tripCreateCta),
              ] else
                Text(
                  l10n.tripCreateCta,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.tripPickFrom.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: refresh
                      ? VisualRefreshColors.textTertiary
                      : AppColors.inkSoft,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              _TripZoneDropdown(
                value: fromId,
                zones: _zones,
                labelOf: (z) => _tripPlaceLabel(z, l10n),
                onChanged: (v) => setSheet(() => fromId = v),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.tripPickTo.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: refresh
                      ? VisualRefreshColors.textTertiary
                      : AppColors.inkSoft,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              _TripZoneDropdown(
                value: toId,
                zones: _zones,
                labelOf: (z) => _tripPlaceLabel(z, l10n),
                onChanged: (v) => setSheet(() => toId = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: refresh ? 52 : null,
                child: FilledButton(
                  onPressed: () async {
                    if (fromId == null || toId == null) return;
                    if (fromId == toId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.tripNeedDistinct)),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    await _createTrip(
                      fromZoneId: fromId!,
                      toZoneId: toId!,
                    );
                  },
                  style: refresh
                      ? FilledButton.styleFrom(
                          backgroundColor: VisualRefreshColors.anchor,
                          foregroundColor: VisualRefreshColors.background,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        )
                      : null,
                  child: Text(
                    l10n.tripCreate,
                    style: refresh
                        ? GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          )
                        : null,
                  ),
                ),
              ),
              if (_zoneOf('home') != null && _zoneOf('school') != null) ...[
                const SizedBox(height: 10),
                if (refresh)
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _suggestSchoolHome();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VisualRefreshColors.textPrimary,
                      side: const BorderSide(color: VisualRefreshColors.border),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l10n.tripSuggestSchoolHome,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _suggestSchoolHome();
                    },
                    child: Text(l10n.tripSuggestSchoolHome),
                  ),
              ],
            ],
          );

          if (refresh) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: VrSheetShell(child: body),
            );
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: body,
          );
        },
      );
    }

    if (refresh) {
      await showVrModalBottomSheet<void>(
        context: context,
        builder: buildSheet,
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: buildSheet,
      );
    }
  }

  String _tripDistanceLabel() {
    final m = (_trip?['distanceM'] as num?)?.toDouble() ?? 0;
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  String _tripEtaLabel(AppLocalizations l10n) {
    final sec = (_trip?['durationSec'] as num?)?.toInt();
    if (sec != null && sec > 0) {
      final minutes = (sec / 60).round().clamp(1, 180);
      return l10n.estimateMinutes(minutes);
    }
    final m = (_trip?['distanceM'] as num?)?.toDouble() ?? 0;
    final minutes = (m / 83.33).round().clamp(1, 180);
    return l10n.estimateMinutes(minutes);
  }

  String _tripMeta(AppLocalizations l10n) {
    final status = _trip?['status'] as String?;
    final base = l10n.tripProgressMeta(_tripDistanceLabel(), _tripEtaLabel(l10n));
    if (status == 'planned') return '${l10n.tripPlanned} · $base';
    if (status == 'arrived') return '${l10n.tripArrived} · $base';
    if (status == 'active') return '${l10n.tripActive} · $base';
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider);
    final items = children.items;
    final refresh = visualRefreshOf(context);

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
    final places = _orderedPlaces(l10n);
    final home = _zoneOf('home');
    final school = _zoneOf('school');
    final missingSlots = <String>[
      if (home == null) 'home',
      if (school == null) 'school',
    ];

    final sectionTitleStyle = refresh
        ? GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: VisualRefreshColors.textPrimary,
          )
        : const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          );

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          onRefresh: _reloadForSelected,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              PaScreenHeader(
                title: l10n.zonesHubTitle,
                subtitle: l10n.zonesHubSubtitle,
                showBack: widget.showBack,
                padding: EdgeInsets.zero,
                crossAxisAlignment: CrossAxisAlignment.start,
                titleStyle: refresh
                    ? GoogleFonts.fraunces(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                subtitleStyle: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
                trailing: _effectiveReadOnly
                    ? null
                    : Material(
                        color: refresh
                            ? VisualRefreshColors.accentTint
                            : const Color(0xFFD8F5E8),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: selected == null ? null : _showAddMenu,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.add_rounded,
                              color: refresh
                                  ? VisualRefreshColors.accent
                                  : AppColors.tealDeep,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.searchPlaceHint,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : null,
                  ),
                  filled: true,
                  fillColor:
                      refresh ? VisualRefreshColors.surface : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: refresh
                        ? const BorderSide(
                            color: VisualRefreshColors.border,
                            width: 0.5,
                          )
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: refresh
                        ? const BorderSide(
                            color: VisualRefreshColors.border,
                            width: 0.5,
                          )
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.accent
                          : AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  l10n.noChildren,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
                  ),
                ),
              ] else ...[
                if (widget.lockedChild == null) ...[
                  const SizedBox(height: 18),
                  Text(
                    l10n.pickChildTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: refresh
                          ? VisualRefreshColors.textTertiary
                          : AppColors.inkSoft,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
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
                            ? l10n.zoneGenericLabel
                            : l10n.placesForChildLabel(selected.name),
                        style: sectionTitleStyle,
                      ),
                    ),
                    if (!_effectiveReadOnly)
                      TextButton(
                        onPressed: () =>
                            setState(() => _editMode = !_editMode),
                        style: TextButton.styleFrom(
                          foregroundColor: refresh
                              ? VisualRefreshColors.accent
                              : AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _editMode ? l10n.doneAction : l10n.editChevron,
                          style: TextStyle(
                            fontWeight: refresh
                                ? FontWeight.w600
                                : FontWeight.w800,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
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
                      decoration: _cardDecoration(context),
                      child: Text(
                        _query.isEmpty
                            ? l10n.noPlacesYetAddHomeSchool
                            : l10n.noPlacesMatch,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: refresh
                              ? VisualRefreshColors.textSecondary
                              : AppColors.inkSoft,
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
                          title: _displayTitle(z, l10n),
                          subtitle: _displaySubtitle(z, l10n),
                          type: type,
                          editMode: !_effectiveReadOnly && _editMode,
                          onTap: () {
                            if (_effectiveReadOnly) return;
                            if (_editMode) {
                              _deleteZone(z);
                            } else if (type == 'home' || type == 'school') {
                              _addBySearch(type);
                            }
                          },
                          onDelete: (!_effectiveReadOnly && _editMode)
                              ? () => _deleteZone(z)
                              : null,
                        ),
                      );
                    }),
                    if (!_effectiveReadOnly && !_editMode)
                      ...missingSlots.map((slot) {
                        final isHome = slot == 'home';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlaceListCard(
                            title: isHome
                                ? l10n.homePlaceLabel
                                : l10n.schoolPlaceLabel,
                            subtitle: l10n.notConfiguredTapSearch,
                            type: slot,
                            empty: true,
                            onTap: () => _addBySearch(slot),
                          ),
                        );
                      }),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    l10n.tripSectionTitle,
                    style: sectionTitleStyle,
                  ),
                  const SizedBox(height: 10),
                  if (_tripLoading)
                    Container(
                      height: 96,
                      alignment: Alignment.center,
                      decoration: _cardDecoration(context),
                      child: const CircularProgressIndicator(),
                    )
                  else if (_trip != null)
                    TripRouteCard(
                      fromLabel:
                          _trip!['fromLabel'] as String? ?? l10n.tripPickFrom,
                      toLabel:
                          _trip!['toLabel'] as String? ?? l10n.tripPickTo,
                      meta: _tripMeta(l10n),
                      progress:
                          (_trip!['progress'] as num?)?.toDouble() ?? 0,
                      status: _trip!['status'] as String?,
                      onStart: (!_effectiveReadOnly &&
                              _trip!['status'] == 'planned')
                          ? () => unawaited(_startTrip())
                          : null,
                      onCancel: _effectiveReadOnly
                          ? null
                          : () => unawaited(_cancelTrip()),
                    )
                  else if (!_effectiveReadOnly)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openCreateTripSheet,
                        borderRadius: BorderRadius.circular(
                          refresh ? AppRadius.vrCard : 20,
                        ),
                        child: Ink(
                          decoration: _cardDecoration(context),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.route_rounded,
                                  color: refresh
                                      ? VisualRefreshColors.accent
                                      : AppColors.teal,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.tripCreateCta,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: refresh
                                          ? VisualRefreshColors.textPrimary
                                          : null,
                                      fontFamily: refresh
                                          ? GoogleFonts.plusJakartaSans()
                                              .fontFamily
                                          : null,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                if (!_effectiveReadOnly)
                  _DashedAddButton(
                    label: l10n.addNewPlaceLabel,
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

BoxDecoration _cardDecoration(BuildContext context) {
  final refresh = visualRefreshOf(context);
  if (refresh) {
    return BoxDecoration(
      color: VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      border: Border.all(color: VisualRefreshColors.border, width: 0.5),
    );
  }
  return BoxDecoration(
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
}

class _AddPlaceChoice {
  const _AddPlaceChoice({required this.type, this.customLabel});

  final String type;
  final String? customLabel;
}

/// Owns the label [TextEditingController] for the add-place sheet lifetime.
class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet({
    required this.missingHome,
    required this.missingSchool,
  });

  final bool missingHome;
  final bool missingSchool;

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _labelCtrl = TextEditingController();
  String? _selectedPreset;
  String? _selectedSlot; // 'home' | 'school' | null (custom)

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(String p) {
    setState(() {
      _selectedPreset = p;
      _selectedSlot = null;
      _labelCtrl.text = p;
      _labelCtrl.selection = TextSelection.collapsed(offset: p.length);
    });
  }

  void _selectSlot(String slot, String label) {
    setState(() {
      _selectedSlot = slot;
      _selectedPreset = null;
      _labelCtrl.text = label;
      _labelCtrl.selection = TextSelection.collapsed(offset: label.length);
    });
  }

  void _continue(AppLocalizations l10n) {
    if (_selectedSlot == 'home' || _selectedSlot == 'school') {
      Navigator.pop(context, _AddPlaceChoice(type: _selectedSlot!));
      return;
    }
    final t = _labelCtrl.text.trim();
    Navigator.pop(
      context,
      _AddPlaceChoice(
        type: 'custom',
        customLabel: t.isEmpty ? l10n.otherPlaceLabel : t,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final customPresets = <String>[
      l10n.placeLessonSuggestion,
      l10n.placeGrandmaSuggestion,
      l10n.placeFriendSuggestion,
      l10n.placeMallSuggestion,
      l10n.newPlaceDefault,
    ];

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (refresh) ...[
          const VrSheetDragHandle(),
          const SizedBox(height: 16),
          VrSheetTitle(l10n.addSafePlaceTitle),
          const SizedBox(height: 6),
          VrSheetBody(l10n.customPlaceDialogHint),
        ] else ...[
          Text(
            l10n.addSafePlaceTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.customPlaceDialogHint,
            style: const TextStyle(
              color: AppColors.inkSoft,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.missingHome)
              _AddPlacePresetChip(
                label: l10n.homeZone,
                selected: _selectedSlot == 'home',
                onTap: () => _selectSlot('home', l10n.homeZone),
              ),
            if (widget.missingSchool)
              _AddPlacePresetChip(
                label: l10n.schoolZone,
                selected: _selectedSlot == 'school',
                onTap: () => _selectSlot('school', l10n.schoolZone),
              ),
            for (final p in customPresets)
              _AddPlacePresetChip(
                label: p,
                selected: _selectedPreset == p && _selectedSlot == null,
                onTap: () => _selectPreset(p),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _labelCtrl,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            setState(() {
              _selectedPreset = null;
              _selectedSlot = null;
            });
          },
          decoration: InputDecoration(
            labelText: l10n.orTypeOwnNameLabel,
            hintText: l10n.customPlaceHint,
            filled: refresh,
            fillColor: refresh ? VisualRefreshColors.surface : null,
            enabledBorder: refresh
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.border,
                    ),
                  )
                : null,
            focusedBorder: refresh
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.accent,
                      width: 1.5,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: refresh ? 52 : null,
          child: FilledButton(
            onPressed: () => _continue(l10n),
            style: FilledButton.styleFrom(
              backgroundColor:
                  refresh ? VisualRefreshColors.anchor : AppColors.teal,
              foregroundColor:
                  refresh ? VisualRefreshColors.background : null,
              elevation: 0,
              shape: refresh ? const StadiumBorder() : null,
            ),
            child: Text(
              l10n.continueSearchAddress,
              style: refresh
                  ? GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );

    if (refresh) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VrSheetShell(child: content),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: content,
    );
  }
}

class _AddPlacePresetChip extends StatelessWidget {
  const _AddPlacePresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    if (!refresh) {
      return ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected ? AppColors.mint : null,
      );
    }
    return Material(
      color: selected
          ? VisualRefreshColors.accentTint
          : VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? VisualRefreshColors.accent
                  : VisualRefreshColors.border,
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected
                  ? VisualRefreshColors.accent
                  : VisualRefreshColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripZoneDropdown extends StatelessWidget {
  const _TripZoneDropdown({
    required this.value,
    required this.zones,
    required this.labelOf,
    required this.onChanged,
  });

  final String? value;
  final List<Map<String, dynamic>> zones;
  final String Function(Map<String, dynamic>) labelOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final dropdown = DropdownButton<String>(
      isExpanded: true,
      value: value,
      underline: refresh ? const SizedBox.shrink() : null,
      icon: Icon(
        Icons.expand_more_rounded,
        color: refresh
            ? VisualRefreshColors.textSecondary
            : AppColors.inkSoft,
      ),
      items: [
        for (final z in zones)
          DropdownMenuItem(
            value: z['id'] as String,
            child: Text(
              labelOf(z),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: refresh
                  ? GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
            ),
          ),
      ],
      onChanged: onChanged,
    );
    if (!refresh) return dropdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: VisualRefreshColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VisualRefreshColors.border, width: 0.5),
      ),
      child: dropdown,
    );
  }
}

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
    final refresh = visualRefreshOf(context);
    final selectedFill =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;
    final selectedFg =
        refresh ? VisualRefreshColors.background : Colors.white;
    final unselectedFg =
        refresh ? VisualRefreshColors.anchor : AppColors.ink;
    return Material(
      color: selected
          ? selectedFill
          : (refresh ? VisualRefreshColors.surface : Colors.white),
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
                : Border.all(
                    color: refresh
                        ? VisualRefreshColors.border
                        : const Color(0xFFE2E6EA),
                    width: refresh ? 0.5 : 1,
                  ),
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
                  color: selected ? selectedFg : unselectedFg,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
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

  Color _iconBg(bool refresh) {
    if (refresh) {
      switch (type) {
        case 'home':
          return VisualRefreshColors.accentTint;
        case 'school':
          return VisualRefreshColors.tagMuted;
        default:
          return VisualRefreshColors.routeTint;
      }
    }
    switch (type) {
      case 'home':
        return const Color(0xFFD8F5E8);
      case 'school':
        return const Color(0xFFDCEBFF);
      default:
        return const Color(0xFFFFF0DC);
    }
  }

  Color _iconFg(bool refresh) {
    if (refresh) {
      switch (type) {
        case 'home':
          return VisualRefreshColors.accent;
        case 'school':
          return VisualRefreshColors.anchor;
        default:
          return VisualRefreshColors.routeText;
      }
    }
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
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final radius = refresh ? AppRadius.vrCard : 18.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: _cardDecoration(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _iconBg(refresh),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: _iconFg(refresh), size: 26),
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
                          color: empty
                              ? (refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft)
                              : (refresh
                                  ? VisualRefreshColors.textPrimary
                                  : AppColors.ink),
                          fontFamily: refresh
                              ? GoogleFonts.plusJakartaSans().fontFamily
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                if (editMode && onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: refresh
                          ? VisualRefreshColors.danger
                          : AppColors.coral,
                    ),
                  )
                else if (!empty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isRouteTag
                          ? (refresh
                              ? VisualRefreshColors.routeTint
                              : const Color(0xFFFFE8C8))
                          : (refresh
                              ? VisualRefreshColors.accentTint
                              : const Color(0xFFD8F5E8)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isRouteTag
                          ? l10n.routeBadge
                          : l10n.safeLegendLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: _isRouteTag
                            ? (refresh
                                ? VisualRefreshColors.routeText
                                : const Color(0xFFB45309))
                            : (refresh
                                ? VisualRefreshColors.accent
                                : AppColors.tealDeep),
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
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

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final fill = refresh
        ? VisualRefreshColors.accentTint
        : const Color(0xFFE8F6F1);
    final dash = refresh
        ? VisualRefreshColors.dashedAction
        : AppColors.teal.withValues(alpha: 0.55);
    final fg = refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;
    final radius = refresh ? AppRadius.pill : 16.0;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: dash,
            radius: radius,
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: fg,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
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

class PlaceSearchSheet extends ConsumerStatefulWidget {
  const PlaceSearchSheet({
    super.key,
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  ConsumerState<PlaceSearchSheet> createState() => PlaceSearchSheetState();
}

class PlaceSearchSheetState extends ConsumerState<PlaceSearchSheet> {
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
      final l10n = AppLocalizations.of(context);
      final raw = e.toString();
      String msg =
          'Pencarian gagal. Key Google Maps di server belum bisa dipakai untuk cari lokasi.';
      if (raw.contains('maps_key_missing')) {
        msg = 'GOOGLE_MAPS_API_KEY belum diisi di Render.';
      } else if (raw.contains('maps_key_restricted') ||
          raw.contains('not authorized') ||
          raw.contains('REQUEST_DENIED')) {
        msg =
            'Key Maps di server diblokir Google (biasanya key khusus Android). '
            '${l10n.placesApiKeyHint}';
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
    final refresh = visualRefreshOf(context);
    final sheet = SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 10),
          if (refresh)
            const VrSheetDragHandle()
          else
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              refresh ? 24 : 16,
              refresh ? 16 : 16,
              refresh ? 24 : 16,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: refresh
                  ? VrSheetTitle(widget.title)
                  : Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: refresh ? 24 : 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: Icon(
                  Icons.search,
                  color: refresh ? VisualRefreshColors.accent : null,
                ),
                filled: refresh,
                fillColor: refresh ? VisualRefreshColors.surface : null,
                border: refresh
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: VisualRefreshColors.border,
                        ),
                      )
                    : const OutlineInputBorder(),
                enabledBorder: refresh
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: VisualRefreshColors.border,
                        ),
                      )
                    : null,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(refresh ? 14 : 4),
                  borderSide: BorderSide(
                    color: refresh
                        ? VisualRefreshColors.accent
                        : AppColors.teal,
                    width: 1.5,
                  ),
                ),
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
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: _hits.length,
              separatorBuilder: (_, __) => refresh
                  ? const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 24,
                      endIndent: 24,
                      color: VisualRefreshColors.border,
                    )
                  : const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final hit = _hits[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: refresh ? 24 : 16,
                  ),
                  leading: Icon(
                    Icons.place_outlined,
                    color: refresh
                        ? VisualRefreshColors.accent
                        : AppColors.teal,
                  ),
                  title: Text(
                    hit.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: refresh
                          ? VisualRefreshColors.textPrimary
                          : null,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    hit.address,
                    style: TextStyle(
                      color: refresh
                          ? VisualRefreshColors.textSecondary
                          : null,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, hit),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (refresh) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: VisualRefreshColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [VisualRefreshColors.dialogShadow],
          ),
          child: sheet,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: sheet,
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
