import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/vr_sheet_chrome.dart';
import '../parent/zones_screen.dart';

enum _ReportFilter { all, verified, active }

/// ~111m grid — reduces stored/displayed GPS precision for privacy.
double _snapCoord(double v) => (v * 1000).roundToDouble() / 1000;

String _placeKey(double lat, double lng) =>
    '${_snapCoord(lat).toStringAsFixed(3)},${_snapCoord(lng).toStringAsFixed(3)}';

String _shortPlace(String label) {
  final first = label.split(',').first.trim();
  if (first.isEmpty) return label;
  return first.length > 42 ? '${first.substring(0, 40)}…' : first;
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  _ReportFilter _filter = _ReportFilter.all;
  final Map<String, String> _placeLabels = {};
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _load();
      unawaited(_loadUserPos());
    });
  }

  Future<void> _loadUserPos() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPos = pos);
    } catch (_) {}
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
      unawaited(_resolvePlaceLabels());
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _resolvePlaceLabels() async {
    final api = ref.read(apiClientProvider);
    for (final r in _reports) {
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final key = _placeKey(lat, lng);
      if (_placeLabels.containsKey(key)) continue;
      try {
        final data = await api.get(
          '/api/v1/places/reverse',
          query: {
            'lat': _snapCoord(lat).toString(),
            'lng': _snapCoord(lng).toString(),
          },
        );
        final label = data['label'] as String?;
        if (!mounted || label == null || label.isEmpty) continue;
        setState(() => _placeLabels[key] = label);
      } catch (_) {}
    }
  }

  Future<String?> _reverseLabel(double lat, double lng) async {
    final key = _placeKey(lat, lng);
    final cached = _placeLabels[key];
    if (cached != null) return cached;
    try {
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/places/reverse',
        query: {
          'lat': _snapCoord(lat).toString(),
          'lng': _snapCoord(lng).toString(),
        },
      );
      final label = data['label'] as String?;
      if (label != null && label.isNotEmpty) {
        _placeLabels[key] = label;
        return label;
      }
    } catch (_) {}
    return null;
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

  String _categoryTitle(AppLocalizations l10n, Map<String, dynamic> r) {
    final note = (r['note'] as String?)?.trim();
    if (note != null && note.isNotEmpty) return note;
    switch (r['category']?.toString()) {
      case 'hazard':
        return l10n.categoryHazardTitle;
      case 'traffic':
        return l10n.categoryTrafficTitle;
      case 'crowd':
        return l10n.categoryCrowdTitle;
      default:
        return l10n.categoryOtherTitle;
    }
  }

  String _categoryLabel(AppLocalizations l10n, String? raw) {
    switch (raw) {
      case 'hazard':
        return l10n.categoryHazardShort;
      case 'traffic':
        return l10n.categoryTrafficShort;
      case 'crowd':
        return l10n.categoryCrowdShort;
      default:
        return l10n.categoryOtherShort;
    }
  }

  String _fmtExpiry(BuildContext context, String? raw, {required bool refresh}) {
    final at = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (at == null) return '—';
    if (refresh) {
      final locale = Localizations.localeOf(context).toString();
      return DateFormat('d MMM, HH:mm', locale).format(at);
    }
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

  String _locationSubtitle(
    AppLocalizations l10n,
    Map<String, dynamic> r, {
    required bool refresh,
  }) {
    final cat = _categoryLabel(l10n, r['category']?.toString());
    if (!refresh) {
      final lat = (r['lat'] as num?)?.toDouble();
      return '$cat · ${lat == null ? l10n.noCoordinatesLabel : l10n.coordinatesAvailableLabel}';
    }
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return '$cat · ${l10n.locationUnknown}';
    final label = _placeLabels[_placeKey(lat, lng)];
    if (label == null) return '$cat · ${l10n.resolvingLocation}';
    return '$cat · ${l10n.nearPlaceLabel(_shortPlace(label))}';
  }

  String _locationRow(
    AppLocalizations l10n,
    Map<String, dynamic> r, {
    required bool refresh,
  }) {
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return refresh ? l10n.locationUnknown : l10n.noCoordinatesLabel;
    }
    if (!refresh) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
    final label = _placeLabels[_placeKey(lat, lng)];
    final place = label == null ? l10n.resolvingLocation : _shortPlace(label);
    final user = _userPos;
    if (user != null && label != null) {
      final meters = Geolocator.distanceBetween(
        user.latitude,
        user.longitude,
        lat,
        lng,
      ).round();
      if (meters < 5000) {
        return l10n.approxMetersFromPlace(meters < 10 ? 10 : meters, place);
      }
    }
    return label == null ? place : l10n.nearPlaceLabel(place);
  }

  Future<void> _addReport() async {
    final refresh = visualRefreshOf(context);
    if (refresh) {
      await _addReportVr();
      return;
    }
    await _addReportClassic();
  }

  Future<void> _addReportClassic() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

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
                  Text(
                    l10n.addPinTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(labelText: l10n.reportTypeLabel),
                    items: [
                      DropdownMenuItem(
                        value: 'hazard',
                        child: Text(l10n.reportTypeHazard),
                      ),
                      DropdownMenuItem(
                        value: 'traffic',
                        child: Text(l10n.categoryTrafficShort),
                      ),
                      DropdownMenuItem(
                        value: 'crowd',
                        child: Text(l10n.categoryCrowdShort),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(l10n.categoryOtherShort),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? 'hazard'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.reportNoteLabel,
                      hintText: l10n.reportNoteHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pos == null
                        ? l10n.reportLocationDefault
                        : l10n.reportLocationCoords(
                            pos.latitude.toStringAsFixed(5),
                            pos.longitude.toStringAsFixed(5),
                          ),
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
                    child: Text(l10n.savePinAction),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    await _submitPin(
      category: category,
      note: noteCtrl.text.trim(),
      lat: pos?.latitude ?? -6.2,
      lng: pos?.longitude ?? 106.816,
    );
    noteCtrl.dispose();
  }

  Future<void> _addReportVr() async {
    Position? pos = _userPos;
    pos ??= await () async {
      try {
        return await Geolocator.getCurrentPosition();
      } catch (_) {
        return null;
      }
    }();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    double lat = _snapCoord(pos?.latitude ?? -6.2);
    double lng = _snapCoord(pos?.longitude ?? 106.816);
    var usingCurrent = pos != null;
    var placeLabel = l10n.resolvingLocation;
    if (pos != null) {
      final resolved = await _reverseLabel(lat, lng);
      if (!mounted) return;
      placeLabel = resolved == null
          ? l10n.locationUnknown
          : _shortPlace(resolved);
    } else {
      placeLabel = l10n.locationUnknown;
    }

    final noteCtrl = TextEditingController();
    String category = 'hazard';

    final ok = await showVrModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: VrSheetShell(
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                Future<void> changeLocation() async {
                  final hit = await showVrModalBottomSheet<PlaceHit>(
                    context: ctx,
                    builder: (_) => PlaceSearchSheet(
                      title: l10n.pickPinLocationTitle,
                      hint: l10n.searchPlaceHint,
                    ),
                  );
                  if (hit == null) return;
                  setLocal(() {
                    lat = _snapCoord(hit.lat);
                    lng = _snapCoord(hit.lng);
                    usingCurrent = false;
                    placeLabel = _shortPlace(
                      hit.name.isNotEmpty ? hit.name : hit.address,
                    );
                  });
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const VrSheetDragHandle(),
                      const SizedBox(height: 16),
                      VrSheetTitle(l10n.addPinTitle),
                      const SizedBox(height: 20),
                      Text(
                        l10n.pinLocationLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: VisualRefreshColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: VisualRefreshColors.warmTint,
                        borderRadius: BorderRadius.circular(AppRadius.vrCard),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppRadius.vrCard),
                          onTap: changeLocation,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: VisualRefreshColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: VisualRefreshColors.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    color: VisualRefreshColors.accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        usingCurrent
                                            ? l10n.usingCurrentLocation
                                            : placeLabel,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: VisualRefreshColors.textPrimary,
                                        ),
                                      ),
                                      if (usingCurrent) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          placeLabel,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12.5,
                                            color: VisualRefreshColors
                                                .textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '${l10n.changeLocationAction} >',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: VisualRefreshColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.whatAreYouReporting,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: VisualRefreshColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._vrCategories(l10n).map((opt) {
                        final selected = category == opt.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? VisualRefreshColors.accentTint
                                : VisualRefreshColors.warmTint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.vrCard),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.vrCard),
                              onTap: () =>
                                  setLocal(() => category = opt.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.vrCard),
                                  border: Border.all(
                                    color: selected
                                        ? VisualRefreshColors.accent
                                        : VisualRefreshColors.border,
                                    width: selected ? 1.2 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: opt.tint,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        opt.icon,
                                        color: opt.iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        opt.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color:
                                              VisualRefreshColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Text(
                        l10n.shortNoteOptional,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: VisualRefreshColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: VisualRefreshColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.reportNoteHintVr,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w500,
                            color: VisualRefreshColors.textTertiary,
                          ),
                          filled: true,
                          fillColor: VisualRefreshColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: VisualRefreshColors.border,
                              width: 0.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: VisualRefreshColors.border,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: VisualRefreshColors.accent,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: VisualRefreshColors.anchor,
                            foregroundColor: VisualRefreshColors.background,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l10n.savePinAction,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) {
      noteCtrl.dispose();
      return;
    }
    await _submitPin(
      category: category,
      note: noteCtrl.text.trim(),
      lat: lat,
      lng: lng,
    );
    noteCtrl.dispose();
  }

  Future<void> _submitPin({
    required String category,
    required String note,
    required double lat,
    required double lng,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/reports', body: {
        'category': category,
        'note': note,
        'lat': _snapCoord(lat),
        'lng': _snapCoord(lng),
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pinAddedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _verify(String id) async {
    final l10n = AppLocalizations.of(context);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/reports/$id/verify');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportVerifiedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.verifyFailed('$e'))),
      );
    }
  }

  Future<void> _markStillThere(Map<String, dynamic> r) async {
    if (r['status'] == 'verified') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).alreadyVerifiedThanks)),
      );
      return;
    }
    await _verify(r['id'] as String);
  }

  void _markFixed(Map<String, dynamic> r) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).fixedSuggestionNoted),
      ),
    );
  }

  Set<Marker> _markers(AppLocalizations l10n) {
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
          infoWindow: InfoWindow(title: _categoryTitle(l10n, r)),
        ),
      );
    }
    return out;
  }

  LatLng _mapCenter(Set<Marker> markers) {
    if (markers.isEmpty) return const LatLng(-6.2, 106.816);
    return markers.first.position;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final verified =
        _reports.where((r) => r['status'] == 'verified').length;
    final expired = _reports.where((r) {
      final status = r['status']?.toString();
      if (status == 'expired') return true;
      final at = DateTime.tryParse(r['expires_at']?.toString() ?? '');
      return status == 'active' && at != null && at.isBefore(DateTime.now());
    }).length;
    final list = _filtered;
    final markers = _markers(l10n);

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      floatingActionButton: refresh
          ? null
          : FloatingActionButton.extended(
              onPressed: _addReport,
              backgroundColor: AppColors.tealDeep,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: Text(
                l10n.addPinTitle,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.communityReportsTitle,
              titleStyle: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
              padding: refresh
                  ? const EdgeInsets.fromLTRB(
                      PaScreenHeader.edgePad,
                      8,
                      16,
                      4,
                    )
                  : const EdgeInsets.fromLTRB(
                      PaScreenHeader.edgePad,
                      8,
                      16,
                      PaScreenHeader.contentGap,
                    ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: refresh
                          ? VisualRefreshColors.accent
                          : AppColors.teal,
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          refresh ? 8 : 8,
                          16,
                          refresh ? 24 : 100,
                        ),
                        children: [
                          _InfoBanner(refresh: refresh, text: l10n.reportsInfoBanner),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _StatMini(
                                  value: '${_reports.length}',
                                  label: l10n.totalReportsLabel,
                                  valueColor: refresh
                                      ? VisualRefreshColors.textPrimary
                                      : AppColors.ink,
                                  refresh: refresh,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatMini(
                                  value: '$verified',
                                  label: l10n.verifiedLabel,
                                  valueColor: refresh
                                      ? VisualRefreshColors.accent
                                      : AppColors.teal,
                                  refresh: refresh,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatMini(
                                  value: '$expired',
                                  label: l10n.expiredLabel,
                                  valueColor: refresh
                                      ? VisualRefreshColors.danger
                                      : AppColors.coral,
                                  refresh: refresh,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.areaMapTitle,
                            style: refresh
                                ? GoogleFonts.fraunces(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: VisualRefreshColors.textPrimary,
                                  )
                                : const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              refresh ? AppRadius.vrCard : 18,
                            ),
                            child: SizedBox(
                              height: 180,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _mapCenter(markers),
                                  zoom: markers.isEmpty ? 12 : 14,
                                ),
                                markers: markers,
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
                              Expanded(
                                child: Text(
                                  l10n.reportsListTitle,
                                  style: refresh
                                      ? GoogleFonts.fraunces(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              VisualRefreshColors.textPrimary,
                                        )
                                      : const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                ),
                              ),
                              _FilterButton(
                                filter: _filter,
                                refresh: refresh,
                                onSelected: (v) =>
                                    setState(() => _filter = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (list.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: _cardDecoration(refresh),
                              child: Text(
                                l10n.noActiveReports,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: refresh
                                      ? GoogleFonts.plusJakartaSans().fontFamily
                                      : null,
                                ),
                              ),
                            )
                          else
                            ...list.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ReportCard(
                                  refresh: refresh,
                                  title: _categoryTitle(l10n, r),
                                  subtitle: _locationSubtitle(
                                    l10n,
                                    r,
                                    refresh: refresh,
                                  ),
                                  locationRow: _locationRow(
                                    l10n,
                                    r,
                                    refresh: refresh,
                                  ),
                                  expiry: l10n.expiresAtLabel(
                                    _fmtExpiry(
                                      context,
                                      r['expires_at']?.toString(),
                                      refresh: refresh,
                                    ),
                                  ),
                                  verified: r['status'] == 'verified',
                                  category: r['category']?.toString(),
                                  onStillThere: () => _markStillThere(r),
                                  onFixed: () => _markFixed(r),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (refresh) _AddPinFooter(onPressed: _addReport),
          ],
        ),
      ),
    );
  }
}

List<_VrCategoryOpt> _vrCategories(AppLocalizations l10n) => [
      _VrCategoryOpt(
        id: 'hazard',
        label: l10n.reportTypeHazard,
        icon: Icons.warning_amber_rounded,
        tint: const Color(0xFFF6E4DE),
        iconColor: const Color(0xFFC45A3A),
      ),
      _VrCategoryOpt(
        id: 'traffic',
        label: l10n.categoryTrafficShort,
        icon: Icons.traffic_rounded,
        tint: VisualRefreshColors.routeTint,
        iconColor: VisualRefreshColors.routeText,
      ),
      _VrCategoryOpt(
        id: 'crowd',
        label: l10n.categoryCrowdShort,
        icon: Icons.groups_rounded,
        tint: const Color(0xFFEAE4F5),
        iconColor: const Color(0xFF6B5B95),
      ),
      _VrCategoryOpt(
        id: 'other',
        label: l10n.categoryOtherShort,
        icon: Icons.more_horiz_rounded,
        tint: VisualRefreshColors.tagMuted,
        iconColor: VisualRefreshColors.textSecondary,
      ),
    ];

class _VrCategoryOpt {
  const _VrCategoryOpt({
    required this.id,
    required this.label,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color tint;
  final Color iconColor;
}

BoxDecoration _cardDecoration(bool refresh) {
  if (refresh) {
    return BoxDecoration(
      color: VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      border: Border.all(
        color: VisualRefreshColors.border,
        width: 0.5,
      ),
    );
  }
  return BoxDecoration(
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
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.refresh, required this.text});

  final bool refresh;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.routeTint
            : const Color(0xFFFFF0DC),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            color: refresh
                ? VisualRefreshColors.routeText
                : const Color(0xFFE85A7A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.routeText
                    : const Color(0xFF9A5B00),
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontSize: 13.5,
                fontFamily: refresh
                    ? GoogleFonts.plusJakartaSans().fontFamily
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.refresh,
    required this.onSelected,
  });

  final _ReportFilter filter;
  final bool refresh;
  final ValueChanged<_ReportFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_ReportFilter>(
      initialValue: filter,
      onSelected: onSelected,
      color: refresh ? VisualRefreshColors.surface : null,
      elevation: refresh ? 12 : 8,
      shape: refresh
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: VisualRefreshColors.border,
                width: 0.5,
              ),
            )
          : null,
      shadowColor: refresh ? const Color(0x29141E19) : null,
      itemBuilder: (_) => [
        _filterItem(
          value: _ReportFilter.all,
          label: l10n.allFilterLabel,
          selected: filter == _ReportFilter.all,
          refresh: refresh,
        ),
        _filterItem(
          value: _ReportFilter.verified,
          label: l10n.verifiedLabel,
          selected: filter == _ReportFilter.verified,
          refresh: refresh,
        ),
        _filterItem(
          value: _ReportFilter.active,
          label: l10n.activeLabel,
          selected: filter == _ReportFilter.active,
          refresh: refresh,
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.filterLabel,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )
                : const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
          ),
          Icon(
            Icons.expand_more_rounded,
            color: refresh ? VisualRefreshColors.accent : AppColors.teal,
            size: 20,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_ReportFilter> _filterItem({
    required _ReportFilter value,
    required String label,
    required bool selected,
    required bool refresh,
  }) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: refresh
            ? GoogleFonts.plusJakartaSans(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? VisualRefreshColors.accent
                    : VisualRefreshColors.textPrimary,
              )
            : null,
      ),
    );
  }
}

class _AddPinFooter extends StatelessWidget {
  const _AddPinFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: VisualRefreshColors.background,
        border: Border(
          top: BorderSide(color: VisualRefreshColors.border, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.place_rounded, size: 20),
          label: Text(
            l10n.addPinTitle,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: VisualRefreshColors.anchor,
            foregroundColor: VisualRefreshColors.background,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.refresh,
    required this.title,
    required this.subtitle,
    required this.locationRow,
    required this.expiry,
    required this.verified,
    required this.category,
    required this.onStillThere,
    required this.onFixed,
  });

  final bool refresh;
  final String title;
  final String subtitle;
  final String locationRow;
  final String expiry;
  final bool verified;
  final String? category;
  final VoidCallback onStillThere;
  final VoidCallback onFixed;

  _IconStyle get _iconStyle {
    switch (category) {
      case 'traffic':
        return const _IconStyle(
          Icons.traffic_rounded,
          VisualRefreshColors.routeTint,
          VisualRefreshColors.routeText,
        );
      case 'crowd':
        return const _IconStyle(
          Icons.groups_rounded,
          Color(0xFFEAE4F5),
          Color(0xFF6B5B95),
        );
      case 'other':
        return const _IconStyle(
          Icons.more_horiz_rounded,
          VisualRefreshColors.tagMuted,
          VisualRefreshColors.textSecondary,
        );
      default:
        return refresh
            ? const _IconStyle(
                Icons.warning_amber_rounded,
                VisualRefreshColors.routeTint,
                VisualRefreshColors.routeText,
              )
            : const _IconStyle(
                Icons.warning_amber_rounded,
                Color(0xFFFFE8E6),
                Color(0xFFE8913A),
              );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = _iconStyle;
    final metaColor = refresh
        ? VisualRefreshColors.routeText
        : AppColors.coral;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(refresh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, color: style.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: refresh
                                ? GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: VisualRefreshColors.textPrimary,
                                  )
                                : const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                  ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: refresh
                                  ? VisualRefreshColors.accentTint
                                  : const Color(0xFFD8F5E8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              refresh ? l10n.verifiedBadge : 'VERIFIED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: refresh
                                    ? VisualRefreshColors.accent
                                    : AppColors.tealDeep,
                                fontFamily: refresh
                                    ? GoogleFonts.plusJakartaSans().fontFamily
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: refresh
                          ? GoogleFonts.plusJakartaSans(
                              color: VisualRefreshColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                            )
                          : const TextStyle(
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
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.place_rounded,
                size: 16,
                color: metaColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationRow,
                  style: refresh
                      ? GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: metaColor,
                        )
                      : const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: refresh
                    ? VisualRefreshColors.routeText
                    : const Color(0xFFE85A7A),
              ),
              const SizedBox(width: 6),
              Text(
                expiry,
                style: refresh
                    ? GoogleFonts.plusJakartaSans(
                        color: VisualRefreshColors.routeText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      )
                    : const TextStyle(
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
                  onPressed: onStillThere,
                  icon: Icon(
                    Icons.front_hand_outlined,
                    size: 18,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : null,
                  ),
                  label: Text(
                    l10n.stillThereAction,
                    style: refresh
                        ? GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          )
                        : null,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: refresh
                        ? VisualRefreshColors.textPrimary
                        : AppColors.ink,
                    side: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.border
                          : const Color(0xFFE2E6EA),
                    ),
                    backgroundColor: refresh
                        ? VisualRefreshColors.surface
                        : const Color(0xFFF3F5F7),
                    shape: refresh
                        ? const StadiumBorder()
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFixed,
                  icon: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : AppColors.teal,
                  ),
                  label: Text(
                    l10n.fixedAction,
                    style: refresh
                        ? GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          )
                        : null,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: refresh
                        ? VisualRefreshColors.textPrimary
                        : AppColors.ink,
                    side: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.border
                          : const Color(0xFFE2E6EA),
                    ),
                    backgroundColor: refresh
                        ? VisualRefreshColors.surface
                        : const Color(0xFFF3F5F7),
                    shape: refresh
                        ? const StadiumBorder()
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconStyle {
  const _IconStyle(this.icon, this.tint, this.iconColor);

  final IconData icon;
  final Color tint;
  final Color iconColor;
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.refresh,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: _cardDecoration(refresh),
      child: Column(
        children: [
          Text(
            value,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  )
                : TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textSecondary,
                  )
                : const TextStyle(
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
