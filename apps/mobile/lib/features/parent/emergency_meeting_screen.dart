import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';
import 'zones_screen.dart';

class EmergencyMeetingScreen extends ConsumerStatefulWidget {
  const EmergencyMeetingScreen({super.key, this.lockedChild});

  final ChildSummary? lockedChild;

  @override
  ConsumerState<EmergencyMeetingScreen> createState() =>
      _EmergencyMeetingScreenState();
}

class _EmergencyMeetingScreenState
    extends ConsumerState<EmergencyMeetingScreen> {
  String? _childId;
  Map<String, dynamic>? _primary;
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _activating = false;
  bool _householdHasPoint = false;
  String? _lastSummary;

  bool get _locked => widget.lockedChild != null;

  @override
  void initState() {
    super.initState();
    _childId = widget.lockedChild?.id;
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      if (_childId == null) {
        final items = ref.read(childrenControllerProvider).items;
        if (items.isNotEmpty) _childId = items.first.id;
      }
      await _reload();
    });
  }

  Future<bool> _probeHouseholdHasPoint() async {
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) return false;
    final api = ref.read(apiClientProvider);
    for (final c in children) {
      try {
        final list = await api.get(
          '/api/v1/emergency-meeting-points',
          query: {'childId': c.id},
        );
        final points = list['points'] as List<dynamic>? ?? [];
        if (points.isNotEmpty) return true;
      } catch (_) {
        // Keep probing other children.
      }
    }
    return false;
  }

  Future<void> _reload() async {
    final id = _childId;
    if (id == null) {
      setState(() {
        _primary = null;
        _status = null;
        _householdHasPoint = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final list = await api.get(
        '/api/v1/emergency-meeting-points',
        query: {'childId': id},
      );
      final status =
          await api.get('/api/v1/emergency-meeting-points/$id/status');
      final points = (list['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      Map<String, dynamic>? primary;
      for (final p in points) {
        if (p['isPrimary'] == true) {
          primary = p;
          break;
        }
      }
      primary ??= points.isEmpty ? null : points.first;
      final householdHasPoint =
          primary != null || await _probeHouseholdHasPoint();
      if (!mounted) return;
      setState(() {
        _primary = primary;
        _status = status;
        _householdHasPoint = householdHasPoint;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _selectChild(String id) {
    if (_locked || _childId == id) return;
    setState(() {
      _childId = id;
      _lastSummary = null;
    });
    unawaited(_reload());
  }

  Future<void> _pickAndSavePrimary() async {
    final childId = _childId;
    if (childId == null) return;
    final l10n = AppLocalizations.of(context);
    final children = ref.read(childrenControllerProvider).items;
    final siblings = children.where((c) => c.id != childId).toList();

    final hit = await showModalBottomSheet<PlaceHit>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => PlaceSearchSheet(
        title: l10n.empPickPlace,
        hint: 'Cari tempat...',
      ),
    );
    if (hit == null || !mounted) return;

    final nameCtrl = TextEditingController(text: hit.name);
    final noteCtrl = TextEditingController();
    final applyToOthers = ValueNotifier<bool>(siblings.isNotEmpty);
    final selectedTargets = <String>{for (final c in siblings) c.id};

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _primary == null ? l10n.empAdd : l10n.empEdit,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.empNameHint),
              ),
              const SizedBox(height: 8),
              Text(
                hit.address,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(hintText: l10n.empInstructionsHint),
              ),
              if (siblings.isNotEmpty) ...[
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: applyToOthers,
                  builder: (context, apply, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: apply,
                          title: Text(l10n.empApplyToOthers),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => applyToOthers.value = v == true,
                        ),
                        if (apply)
                          StatefulBuilder(
                            builder: (context, setLocal) {
                              return Column(
                                children: [
                                  for (final c in siblings)
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: selectedTargets.contains(c.id),
                                      title: Text(c.name),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: (v) {
                                        setLocal(() {
                                          if (v == true) {
                                            selectedTargets.add(c.id);
                                          } else {
                                            selectedTargets.remove(c.id);
                                          }
                                        });
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.empActivateCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.empSave),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final note = noteCtrl.text.trim();
    final shouldApply = applyToOthers.value;
    final targets = selectedTargets.toList();
    nameCtrl.dispose();
    noteCtrl.dispose();
    applyToOthers.dispose();
    if (saved != true || name.isEmpty) return;

    final instructions = note.isNotEmpty ? note : hit.address;

    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points',
        body: {
          'childId': childId,
          'name': name,
          'lat': hit.lat,
          'lng': hit.lng,
          'instructions': instructions,
          'isPrimary': true,
        },
      );
      if (shouldApply && targets.isNotEmpty) {
        await ref.read(apiClientProvider).post(
          '/api/v1/emergency-meeting-points/apply-to-all',
          body: {
            'sourceChildId': childId,
            'targetChildIds': targets,
          },
        );
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Always parent-scoped — chip selection must not affect this call.
  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.empActivate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.empActivateConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(hintText: l10n.empActivateNoteHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.empActivateCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.empActivateContinue),
          ),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true) return;

    setState(() => _activating = true);
    try {
      await ref.read(authControllerProvider.notifier).ensureFreshToken();
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points/activate',
        body: {if (note.isNotEmpty) 'note': note},
      );
      if (!mounted) return;
      final targets = (data['targets'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final sent = targets.where((t) => t['notified'] == true).length;
      final skipped = targets
          .where((t) => t['notified'] != true)
          .map((t) => t['childName'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final msg = StringBuffer(l10n.empSummarySent(sent));
      for (final name in skipped) {
        msg.write(' ${l10n.empSummarySkipped(name)}');
      }
      setState(() => _lastSummary = msg.toString());
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException && e.statusCode == 429
          ? l10n.empRateLimited
          : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  String _namesCaption(List<ChildSummary> children) {
    if (children.isEmpty) return '';
    if (children.length == 1) return children.first.name;
    if (children.length == 2) {
      return '${children[0].name} dan ${children[1].name}';
    }
    final head = children
        .take(children.length - 1)
        .map((c) => c.name)
        .join(', ');
    return '$head, dan ${children.last.name}';
  }

  LatLng? _pointLatLng() {
    final p = _primary;
    if (p == null) return null;
    final lat = p['lat'];
    final lng = p['lng'];
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    final statusPoint = _status?['point'];
    if (statusPoint is Map<String, dynamic>) {
      final slat = statusPoint['lat'];
      final slng = statusPoint['lng'];
      if (slat is num && slng is num) {
        return LatLng(slat.toDouble(), slng.toDouble());
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider).items;
    String? selectedName = widget.lockedChild?.name;
    if (selectedName == null) {
      for (final c in children) {
        if (c.id == _childId) {
          selectedName = c.name;
          break;
        }
      }
    }
    final distanceLabel = _status?['distanceLabel'] as String?;
    final captionNames = _namesCaption(
      children.isNotEmpty
          ? children
          : (widget.lockedChild != null
              ? [widget.lockedChild!]
              : <ChildSummary>[]),
    );
    final showChips =
        !_locked && _householdHasPoint && children.length > 1;
    final showActivate = _householdHasPoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(title: l10n.empTitle),
            if (showChips)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = children[i];
                    final selected = c.id == _childId;
                    final initial = c.name.trim().isEmpty
                        ? '?'
                        : c.name.trim()[0].toUpperCase();
                    return ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.teal.withValues(alpha: 0.15),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: selected ? Colors.white : AppColors.tealDeep,
                          ),
                        ),
                      ),
                      label: Text(c.name),
                      selected: selected,
                      onSelected: (_) => _selectChild(c.id),
                      selectedColor: AppColors.tealDeep,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _childId == null
                      ? Center(child: Text(l10n.empNoChildren))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            if (_primary == null)
                              _EmptyCard(
                                childName: showChips ? (selectedName ?? '') : null,
                                onAdd: () => unawaited(_pickAndSavePrimary()),
                              )
                            else
                              _PrimaryCard(
                                point: _primary!,
                                mapPosition: _pointLatLng(),
                                childName: selectedName ?? '',
                                distanceLabel: distanceLabel,
                                onEdit: () =>
                                    unawaited(_pickAndSavePrimary()),
                              ),
                            if (showActivate) ...[
                              const SizedBox(height: 20),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              if (captionNames.isNotEmpty)
                                Text(
                                  l10n.empActivateCaption(captionNames),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                key: const Key('emp_activate_button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _activating
                                    ? null
                                    : () => unawaited(_activate()),
                                icon: const Icon(Icons.warning_amber_rounded),
                                label: Text(
                                  _activating ? '...' : l10n.empActivate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (_lastSummary != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E6EA),
                                    ),
                                  ),
                                  child: Text(
                                    _lastSummary!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd, this.childName});

  /// When null, shows the generic empty copy (first-time setup, no chips yet).
  final String? childName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emptyText = (childName == null || childName!.isEmpty)
        ? l10n.empEmptyGeneric
        : l10n.empEmpty(childName!);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.place_outlined,
            size: 40,
            color: AppColors.inkSoft.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAdd,
            child: Text(l10n.empAdd),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.point,
    required this.childName,
    required this.onEdit,
    this.mapPosition,
    this.distanceLabel,
  });

  final Map<String, dynamic> point;
  final String childName;
  final LatLng? mapPosition;
  final String? distanceLabel;
  final VoidCallback onEdit;

  static bool get _inWidgetTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = point['name'] as String? ?? '';
    final subtitle = (point['instructions'] as String?)?.trim() ?? '';
    final pos = mapPosition;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.empPrimaryLabel,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: pos == null || _inWidgetTest
                  ? Container(
                      color: const Color(0xFFEEF1F4),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.tealDeep.withValues(alpha: 0.85),
                        size: 32,
                      ),
                    )
                  : GoogleMap(
                      key: ValueKey(
                        '${pos.latitude.toStringAsFixed(5)}-'
                        '${pos.longitude.toStringAsFixed(5)}',
                      ),
                      initialCameraPosition: CameraPosition(
                        target: pos,
                        zoom: 15,
                      ),
                      liteModeEnabled: true,
                      markers: {
                        Marker(
                          markerId: const MarkerId('emp_primary'),
                          position: pos,
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 18,
                color: AppColors.tealDeep,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (distanceLabel == null || distanceLabel!.isEmpty)
                      ? l10n.empDistanceUnknown
                      : l10n.empDistanceLive(childName, distanceLabel!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.empEdit),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: Color(0xFFD5DBE0)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
