import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'children_controller.dart';
import 'zones_screen.dart';

class EmergencyMeetingScreen extends ConsumerStatefulWidget {
  const EmergencyMeetingScreen({
    super.key,
    this.lockedChild,
    this.readOnly = false,
  });

  final ChildSummary? lockedChild;
  final bool readOnly;

  @override
  ConsumerState<EmergencyMeetingScreen> createState() =>
      _EmergencyMeetingScreenState();
}

class _ChildEmpCache {
  const _ChildEmpCache({this.primary, this.status});

  final Map<String, dynamic>? primary;
  final Map<String, dynamic>? status;
}

class _EmergencyMeetingScreenState
    extends ConsumerState<EmergencyMeetingScreen> {
  String? _childId;
  bool _loading = true;
  bool _activating = false;
  bool _householdHasPoint = false;
  String? _lastSummary;
  String? _loadError;
  Map<String, dynamic>? _activation;
  bool _deactivating = false;
  Timer? _activationPoll;
  final Map<String, _ChildEmpCache> _cache = {};
  final Set<String> _fetching = {};

  static const _empTimeout = Duration(seconds: 12);
  static const _activationPollInterval = Duration(seconds: 20);

  bool get _locked => widget.lockedChild != null;

  Map<String, dynamic>? get _primary =>
      _childId == null ? null : _cache[_childId!]?.primary;

  Map<String, dynamic>? get _status =>
      _childId == null ? null : _cache[_childId!]?.status;

  @override
  void initState() {
    super.initState();
    _childId = widget.lockedChild?.id;
    Future.microtask(_bootstrap);
    unawaited(_pollActivation());
    _activationPoll = Timer.periodic(
      _activationPollInterval,
      (_) => unawaited(_pollActivation()),
    );
  }

  @override
  void dispose() {
    _activationPoll?.cancel();
    super.dispose();
  }

  /// Live arrival tracking for the currently open activation (parent-scoped).
  Future<void> _pollActivation() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get(
            '/api/v1/emergency-meeting-points/activation',
            timeout: _empTimeout,
          );
      if (!mounted) return;
      final activation = data['activation'];
      setState(() {
        _activation =
            activation is Map<String, dynamic> ? activation : null;
      });
    } catch (_) {
      // Keep the last known activation; the next tick retries.
    }
  }

  Future<void> _deactivate() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: refresh
          ? VisualRefreshColors.anchor.withValues(alpha: 0.45)
          : null,
      builder: (ctx) => refresh
          ? _EmpConfirmDialog(
              title: l10n.empDeactivate,
              body: l10n.empDeactivateConfirm,
              confirmLabel: l10n.empDeactivate,
              confirmKey: const Key('emp_deactivate_confirm'),
              confirmColor: VisualRefreshColors.anchor,
              cancelLabel: l10n.empActivateCancel,
            )
          : AlertDialog(
              title: Text(l10n.empDeactivate),
              content: Text(l10n.empDeactivateConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.empActivateCancel),
                ),
                FilledButton(
                  key: const Key('emp_deactivate_confirm'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.empDeactivate),
                ),
              ],
            ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deactivating = true);
    try {
      // Clear every open activation for this household (not just the visible one).
      await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points/deactivate',
        body: {},
      );
      if (!mounted) return;
      setState(() {
        _activation = null;
        _lastSummary = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.empDeactivated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _deactivating = false);
    }
  }

  Future<void> _bootstrap() async {
    // Prefer already-loaded children — never block EMP on a full children refresh.
    var items = ref.read(childrenControllerProvider).items;
    if (items.isEmpty) {
      try {
        await ref
            .read(childrenControllerProvider.notifier)
            .bootstrap()
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Fall through with whatever is in the provider.
      }
      if (!mounted) return;
      items = ref.read(childrenControllerProvider).items;
    }
    if (_childId == null && items.isNotEmpty) {
      _childId = items.first.id;
    }
    final id = _childId;
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _householdHasPoint = false;
      });
      return;
    }

    // Show selected child ASAP — sibling prefetch is background-only.
    await _refreshChild(id, forceSpinner: true);
    if (!mounted) return;
    unawaited(_prefetchSiblings(except: id));
  }

  bool _computeHouseholdHasPoint() {
    for (final entry in _cache.values) {
      if (entry.primary != null) return true;
    }
    return false;
  }

  Future<_ChildEmpCache> _fetchChild(String childId) async {
    final api = ref.read(apiClientProvider);
    final list = await api.get(
      '/api/v1/emergency-meeting-points',
      query: {'childId': childId},
      timeout: _empTimeout,
    );
    Map<String, dynamic>? status;
    try {
      status = await api.get(
        '/api/v1/emergency-meeting-points/$childId/status',
        timeout: _empTimeout,
      );
    } catch (_) {
      // Distance is optional; still render the meeting point card.
    }
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
    return _ChildEmpCache(primary: primary, status: status);
  }

  Future<void> _prefetchSiblings({required String except}) async {
    final children = ref.read(childrenControllerProvider).items;
    final ids = _locked
        ? <String>[]
        : children.map((c) => c.id).where((id) => id != except).toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      try {
        final data = await _fetchChild(id);
        if (!mounted) return;
        setState(() {
          _cache[id] = data;
          _householdHasPoint = _computeHouseholdHasPoint();
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _cache.putIfAbsent(id, () => const _ChildEmpCache());
        });
      }
    }
  }

  Future<void> _prefetchAll({bool showSpinner = false}) async {
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) {
      if (!mounted) return;
      setState(() {
        _cache.clear();
        _householdHasPoint = false;
        _loading = false;
        _loadError = null;
      });
      return;
    }

    final ids = _locked && widget.lockedChild != null
        ? [widget.lockedChild!.id]
        : children.map((c) => c.id).toList();

    if (showSpinner && mounted && _cache.isEmpty) {
      setState(() => _loading = true);
    }

    for (final id in ids) {
      try {
        final data = await _fetchChild(id);
        if (!mounted) return;
        setState(() {
          _cache[id] = data;
          _householdHasPoint = _computeHouseholdHasPoint();
          _loading = false;
          _loadError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _cache.putIfAbsent(id, () => const _ChildEmpCache());
          _loading = false;
        });
      }
    }
  }

  /// Soft refresh one child without blanking the UI when cache exists.
  Future<void> _refreshChild(String childId, {bool forceSpinner = false}) async {
    if (_fetching.contains(childId)) return;
    _fetching.add(childId);
    final hadCache = _cache.containsKey(childId);
    if ((forceSpinner || !hadCache) && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _fetchChild(childId).timeout(_empTimeout);
      if (!mounted) return;
      setState(() {
        _cache[childId] = data;
        _householdHasPoint = _computeHouseholdHasPoint();
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cache.putIfAbsent(childId, () => const _ChildEmpCache());
        _loading = false;
        if (!hadCache) {
          _loadError = 'load_failed';
        }
      });
    } finally {
      _fetching.remove(childId);
    }
  }

  void _selectChild(String id) {
    if (_locked || _childId == id) return;
    setState(() {
      _childId = id;
      _lastSummary = null;
      _loadError = null;
      _loading = false;
      // Seed empty cache so the body never blanks while fetching.
      _cache.putIfAbsent(id, () => const _ChildEmpCache());
    });
    unawaited(_refreshChild(id));
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
        hint: l10n.searchPlaceHint,
      ),
    );
    if (hit == null || !mounted) return;

    final result = await showDialog<_EmpSaveResult>(
      context: context,
      builder: (ctx) => _EmpSaveDialog(
        hit: hit,
        isEditing: _primary != null,
        siblings: siblings,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points',
        body: {
          'childId': childId,
          'name': result.name,
          'lat': hit.lat,
          'lng': hit.lng,
          'instructions': result.instructions,
          'isPrimary': true,
        },
      );
      if (result.applyToTargets.isNotEmpty) {
        await ref.read(apiClientProvider).post(
          '/api/v1/emergency-meeting-points/apply-to-all',
          body: {
            'sourceChildId': childId,
            'targetChildIds': result.applyToTargets,
          },
        );
      }
      if (!mounted) return;
      await _prefetchAll(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deletePrimary() async {
    if (_primary == null) return;
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: refresh
          ? VisualRefreshColors.anchor.withValues(alpha: 0.45)
          : null,
      builder: (ctx) => refresh
          ? _EmpConfirmDialog(
              title: l10n.empDelete,
              body: l10n.empDeleteConfirm,
              confirmLabel: l10n.empDelete,
              confirmColor: VisualRefreshColors.danger,
              cancelLabel: l10n.empActivateCancel,
            )
          : AlertDialog(
              title: Text(l10n.empDelete),
              content: Text(l10n.empDeleteConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.empActivateCancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.empDelete),
                ),
              ],
            ),
    );
    if (confirmed != true) return;
    try {
      // Family-scoped: remove copies on every child (same as activate / apply-to-all).
      await ref.read(apiClientProvider).delete(
            '/api/v1/emergency-meeting-points/clear-all',
          );
      if (!mounted) return;
      final children = ref.read(childrenControllerProvider).items;
      setState(() {
        _lastSummary = null;
        _cache.clear();
        for (final c in children) {
          _cache[c.id] = const _ChildEmpCache();
        }
        _householdHasPoint = false;
        _loading = false;
      });
      unawaited(_prefetchAll(showSpinner: false));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Always parent-scoped — chip selection must not affect this call.
  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final note = await showDialog<String>(
      context: context,
      barrierColor: refresh
          ? VisualRefreshColors.anchor.withValues(alpha: 0.45)
          : null,
      builder: (ctx) => const _EmpActivateDialog(),
    );
    if (note == null || !mounted) return;

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
      unawaited(_pollActivation());
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

  String _namesCaption(List<ChildSummary> children, AppLocalizations l10n) {
    if (children.isEmpty) return '';
    if (children.length == 1) return children.first.name;
    final and = l10n.listAnd;
    if (children.length == 2) {
      return '${children[0].name} $and ${children[1].name}';
    }
    final head = children
        .take(children.length - 1)
        .map((c) => c.name)
        .join(', ');
    return '$head, $and ${children.last.name}';
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
    final refresh = visualRefreshOf(context);
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
      l10n,
    );
    final showChips =
        !_locked && _householdHasPoint && children.length > 1;
    final showActivate = _householdHasPoint;
    final selectedId = _childId;
    final hasCachedSelected =
        selectedId != null && _cache.containsKey(selectedId);
    // Only blank the body while the first load for the selected child is in flight.
    final showFullSpinner = _loading && !hasCachedSelected;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.empTitle,
              titleStyle: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
            ),
            if (showChips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: refresh ? 40 : 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = children[i];
                      final selected = c.id == _childId;
                      if (refresh) {
                        return _EmpChildPill(
                          name: c.name,
                          selected: selected,
                          onTap: () => _selectChild(c.id),
                        );
                      }
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
              ),
            Expanded(
              child: showFullSpinner
                  ? const Center(child: CircularProgressIndicator())
                  : selectedId == null
                      ? (refresh
                          ? PaVrEmptyState(
                              icon: Icons.child_care_rounded,
                              message: l10n.empNoChildren,
                            )
                          : Center(child: Text(l10n.empNoChildren)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            if (_activation != null && refresh) ...[
                              _EmpInScreenActiveBanner(
                                activation: _activation!,
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_loadError != null) ...[
                              Text(
                                l10n.empLoadError,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: () => unawaited(
                                    _refreshChild(
                                      selectedId,
                                      forceSpinner: true,
                                    ),
                                  ),
                                  child: Text(l10n.empRetry),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_primary == null)
                              widget.readOnly
                                  ? _EmptyCard(
                                      childName: showChips
                                          ? (selectedName ?? '')
                                          : null,
                                      onAdd: null,
                                    )
                                  : _EmptyCard(
                                      childName: showChips
                                          ? (selectedName ?? '')
                                          : null,
                                      onAdd: () =>
                                          unawaited(_pickAndSavePrimary()),
                                    )
                            else
                              _PrimaryCard(
                                point: _primary!,
                                mapPosition: _pointLatLng(),
                                childName: selectedName ?? '',
                                distanceLabel: distanceLabel,
                                onEdit: widget.readOnly
                                    ? null
                                    : () => unawaited(_pickAndSavePrimary()),
                                onDelete: widget.readOnly
                                    ? null
                                    : () => unawaited(_deletePrimary()),
                              ),
                            if (_activation != null) ...[
                              const SizedBox(height: 16),
                              _ActiveActivationCard(
                                activation: _activation!,
                                busy: _deactivating,
                                onRefresh: () => unawaited(_pollActivation()),
                                onDeactivate: widget.readOnly
                                    ? null
                                    : () => unawaited(_deactivate()),
                              ),
                            ],
                            if (!widget.readOnly &&
                                showActivate &&
                                _activation == null) ...[
                              const SizedBox(height: 20),
                              Divider(
                                height: 1,
                                color: refresh
                                    ? VisualRefreshColors.border
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              if (captionNames.isNotEmpty)
                                Text(
                                  l10n.empActivateCaption(captionNames),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: refresh
                                        ? VisualRefreshColors.textSecondary
                                        : AppColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    fontFamily: refresh
                                        ? GoogleFonts.plusJakartaSans()
                                            .fontFamily
                                        : null,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                key: const Key('emp_activate_button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: refresh
                                      ? VisualRefreshColors.danger
                                      : AppColors.danger,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: refresh
                                      ? const StadiumBorder()
                                      : RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                ),
                                onPressed: _activating
                                    ? null
                                    : () => unawaited(_activate()),
                                icon: const Icon(Icons.warning_amber_rounded),
                                label: Text(
                                  _activating ? '...' : l10n.empActivate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    fontFamily: refresh
                                        ? GoogleFonts.plusJakartaSans()
                                            .fontFamily
                                        : null,
                                  ),
                                ),
                              ),
                              if (_lastSummary != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: refresh
                                        ? VisualRefreshColors.surface
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      refresh ? AppRadius.vrCard : 12,
                                    ),
                                    border: Border.all(
                                      color: refresh
                                          ? VisualRefreshColors.border
                                          : const Color(0xFFE2E6EA),
                                      width: refresh ? 0.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    _lastSummary!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
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

class _EmpChildPill extends StatelessWidget {
  const _EmpChildPill({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? VisualRefreshColors.anchor
          : VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: VisualRefreshColors.border,
                    width: 0.5,
                  ),
          ),
          child: Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected
                  ? VisualRefreshColors.background
                  : VisualRefreshColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpInScreenActiveBanner extends StatelessWidget {
  const _EmpInScreenActiveBanner({required this.activation});

  final Map<String, dynamic> activation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = (activation['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((c) => c['notified'] == true)
        .toList();
    final arrived = children.where((c) => c['arrived'] == true).length;
    final pending = children
        .where((c) => c['arrived'] != true)
        .map((c) => c['childName'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final subtitle = children.isEmpty
        ? l10n.tapToViewStatus
        : pending.isEmpty
            ? l10n.allChildrenArrived
            : l10n.arrivedWaitingSummary(
                arrived,
                children.length,
                pending.join(', '),
              );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VisualRefreshColors.dangerTint,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(
          color: VisualRefreshColors.dangerTintBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: VisualRefreshColors.danger,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.empBannerActiveTitle,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: VisualRefreshColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: VisualRefreshColors.dangerTintText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: VisualRefreshColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _EmpConfirmDialog extends StatelessWidget {
  const _EmpConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
    this.confirmKey,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              title,
              style: GoogleFonts.fraunces(
                fontWeight: FontWeight.w600,
                fontSize: 24,
                height: 1.25,
                color: VisualRefreshColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: VisualRefreshColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: VisualRefreshColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    cancelLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: confirmKey,
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: VisualRefreshColors.background,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    confirmLabel,
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
    );
  }
}

class _ActiveActivationCard extends StatelessWidget {
  const _ActiveActivationCard({
    required this.activation,
    required this.busy,
    required this.onRefresh,
    required this.onDeactivate,
  });

  final Map<String, dynamic> activation;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback? onDeactivate;

  static String _clock(String? iso) {
    final at = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final children = (activation['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final note = (activation['note'] as String?)?.trim() ?? '';
    final since = _clock(activation['activatedAt'] as String?);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.dangerTint : Colors.white,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrHero : 18,
        ),
        border: Border.all(
          color: refresh
              ? VisualRefreshColors.dangerTintBorder
              : AppColors.danger.withValues(alpha: 0.35),
          width: refresh ? 0.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: refresh
                    ? VisualRefreshColors.danger
                    : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.empActiveTitle,
                  style: refresh
                      ? GoogleFonts.fraunces(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: VisualRefreshColors.danger,
                        )
                      : const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.danger,
                        ),
                ),
              ),
              IconButton(
                onPressed: busy ? null : onRefresh,
                tooltip: l10n.empRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: refresh
                      ? VisualRefreshColors.dangerTintText
                      : null,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (since.isNotEmpty)
            Text(
              l10n.empActiveSince(since),
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.dangerTintText
                    : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                fontFamily: refresh
                    ? GoogleFonts.plusJakartaSans().fontFamily
                    : null,
              ),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: refresh ? VisualRefreshColors.textPrimary : null,
                fontFamily: refresh
                    ? GoogleFonts.plusJakartaSans().fontFamily
                    : null,
              ),
            ),
          ],
          if (refresh) ...[
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              color: VisualRefreshColors.dangerTintBorder,
            ),
          ] else
            const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (refresh && i > 0)
              const Divider(
                height: 1,
                color: VisualRefreshColors.dangerTintBorder,
              ),
            _ChildProgressRow(child: children[i]),
          ],
          const SizedBox(height: 12),
          if (onDeactivate != null)
            FilledButton.icon(
              key: const Key('emp_deactivate_button'),
              onPressed: busy ? null : onDeactivate,
              style: FilledButton.styleFrom(
                backgroundColor: refresh
                    ? VisualRefreshColors.anchor
                    : AppColors.tealDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: refresh
                    ? const StadiumBorder()
                    : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                busy ? '...' : l10n.empDeactivate,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
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

class _ChildProgressRow extends StatelessWidget {
  const _ChildProgressRow({required this.child});

  final Map<String, dynamic> child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final name = child['childName'] as String? ?? '';
    final notified = child['notified'] == true;
    final arrived = child['arrived'] == true;
    final distanceLabel = (child['distanceLabel'] as String?)?.trim() ?? '';
    final pointName = child['meetingPointName'] as String?;

    final String subtitle;
    if (!notified) {
      subtitle = l10n.empActiveNoPoint;
    } else if (arrived) {
      subtitle = pointName == null || pointName.isEmpty
          ? l10n.empArrived
          : '${l10n.empArrived} - $pointName';
    } else if (distanceLabel.isEmpty) {
      subtitle = l10n.empChildLocationUnknown;
    } else {
      subtitle = '${l10n.empOnTheWay} – $distanceLabel';
    }

    final Color accent = !notified
        ? (refresh ? VisualRefreshColors.dangerTintText : AppColors.inkSoft)
        : arrived
            ? (refresh ? VisualRefreshColors.accent : AppColors.tealDeep)
            : (refresh ? VisualRefreshColors.danger : AppColors.danger);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: refresh ? 12 : 0),
      child: Padding(
        padding: EdgeInsets.only(bottom: refresh ? 0 : 8),
        child: Row(
          children: [
            Icon(
              !notified
                  ? Icons.remove_circle_outline
                  : arrived
                      ? Icons.check_circle_rounded
                      : Icons.directions_walk_rounded,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmpActivateDialog extends StatefulWidget {
  const _EmpActivateDialog();

  @override
  State<_EmpActivateDialog> createState() => _EmpActivateDialogState();
}

class _EmpActivateDialogState extends State<_EmpActivateDialog> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    if (refresh) {
      return Dialog(
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
                l10n.empActivate,
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  height: 1.25,
                  color: VisualRefreshColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.empActivateConfirm,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: VisualRefreshColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteCtrl,
                style: GoogleFonts.plusJakartaSans(
                  color: VisualRefreshColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: l10n.empActivateNoteHint,
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: VisualRefreshColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: VisualRefreshColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      l10n.empActivateCancel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
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
                    onPressed: () =>
                        Navigator.pop(context, _noteCtrl.text.trim()),
                    child: Text(
                      l10n.empActivateContinue,
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
      );
    }
    return AlertDialog(
      title: Text(l10n.empActivate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.empActivateConfirm),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(hintText: l10n.empActivateNoteHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.empActivateCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, _noteCtrl.text.trim()),
          child: Text(l10n.empActivateContinue),
        ),
      ],
    );
  }
}

class _EmpSaveResult {
  const _EmpSaveResult({
    required this.name,
    required this.instructions,
    required this.applyToTargets,
  });

  final String name;
  final String instructions;
  final List<String> applyToTargets;
}

class _EmpSaveDialog extends StatefulWidget {
  const _EmpSaveDialog({
    required this.hit,
    required this.isEditing,
    required this.siblings,
  });

  final PlaceHit hit;
  final bool isEditing;
  final List<ChildSummary> siblings;

  @override
  State<_EmpSaveDialog> createState() => _EmpSaveDialogState();
}

class _EmpSaveDialogState extends State<_EmpSaveDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  late bool _applyToOthers;
  late final Set<String> _selectedTargets;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.hit.name);
    _noteCtrl = TextEditingController();
    _applyToOthers = widget.siblings.isNotEmpty;
    _selectedTargets = {for (final c in widget.siblings) c.id};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final note = _noteCtrl.text.trim();
    final instructions =
        note.isNotEmpty ? note : widget.hit.address;
    Navigator.pop(
      context,
      _EmpSaveResult(
        name: name,
        instructions: instructions,
        applyToTargets: _applyToOthers
            ? _selectedTargets.toList()
            : const <String>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isEditing ? l10n.empEdit : l10n.empAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.empNameHint),
            ),
            const SizedBox(height: 8),
            Text(
              widget.hit.address,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.empInstructionsHint),
            ),
            if (widget.siblings.isNotEmpty) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _applyToOthers,
                title: Text(l10n.empApplyToOthers),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _applyToOthers = v == true),
              ),
              if (_applyToOthers)
                for (final c in widget.siblings)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _selectedTargets.contains(c.id),
                    title: Text(c.name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedTargets.add(c.id);
                        } else {
                          _selectedTargets.remove(c.id);
                        }
                      });
                    },
                  ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.empActivateCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.empSave),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({this.onAdd, this.childName});

  /// When null, shows the generic empty copy (first-time setup, no chips yet).
  final String? childName;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final emptyText = (childName == null || childName!.isEmpty)
        ? l10n.empEmptyGeneric
        : l10n.empEmpty(childName!);

    if (refresh) {
      return PaVrEmptyState(
        icon: Icons.place_outlined,
        message: emptyText,
        actionLabel: onAdd == null ? null : l10n.empAdd,
        actionIcon: Icons.add_rounded,
        onAction: onAdd,
      );
    }

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
          if (onAdd != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAdd,
              child: Text(l10n.empAdd),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.point,
    required this.childName,
    this.onEdit,
    this.onDelete,
    this.mapPosition,
    this.distanceLabel,
  });

  final Map<String, dynamic> point;
  final String childName;
  final LatLng? mapPosition;
  final String? distanceLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static bool get _inWidgetTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final name = point['name'] as String? ?? '';
    final subtitle = (point['instructions'] as String?)?.trim() ?? '';
    final pos = mapPosition;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrHero : 18,
        ),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
        boxShadow: refresh
            ? null
            : [
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
            style: TextStyle(
              color: refresh
                  ? VisualRefreshColors.textTertiary
                  : AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              fontFamily:
                  refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: pos == null || _inWidgetTest
                  ? Container(
                      color: refresh
                          ? VisualRefreshColors.accentTint
                          : const Color(0xFFEEF1F4),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: refresh
                            ? VisualRefreshColors.accent
                            : AppColors.tealDeep.withValues(alpha: 0.85),
                        size: 32,
                      ),
                    )
                  : GoogleMap(
                      key: ValueKey(
                        '${point['id'] ?? 'new'}-'
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
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: refresh ? VisualRefreshColors.textPrimary : null,
              fontFamily:
                  refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: refresh
                    ? VisualRefreshColors.accent
                    : AppColors.tealDeep,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (distanceLabel == null || distanceLabel!.isEmpty)
                      ? l10n.empDistanceUnknown
                      : l10n.empDistanceLive(childName, distanceLabel!),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
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
          ),
          const SizedBox(height: 14),
          if (onEdit != null || onDelete != null)
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.empEdit),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: refresh
                            ? VisualRefreshColors.textPrimary
                            : AppColors.ink,
                        side: BorderSide(
                          color: refresh
                              ? VisualRefreshColors.border
                              : const Color(0xFFD5DBE0),
                          width: refresh ? 0.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            refresh ? 999 : 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 10),
                if (onDelete != null)
                  OutlinedButton.icon(
                    key: const Key('emp_delete_button'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.empDelete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: refresh
                          ? VisualRefreshColors.danger
                          : AppColors.danger,
                      side: BorderSide(
                        color: refresh
                            ? VisualRefreshColors.danger.withValues(alpha: 0.45)
                            : AppColors.danger.withValues(alpha: 0.45),
                        width: refresh ? 0.5 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          refresh ? 999 : 12,
                        ),
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
