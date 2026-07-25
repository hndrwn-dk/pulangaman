import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<Map<String, dynamic>> _points = [];
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _activating = false;

  bool get _locked => widget.lockedChild != null;

  @override
  void initState() {
    super.initState();
    _childId = widget.lockedChild?.id;
    Future.microtask(() async {
      if (_childId == null) {
        await ref.read(childrenControllerProvider.notifier).bootstrap();
        final items = ref.read(childrenControllerProvider).items;
        if (items.isNotEmpty) _childId = items.first.id;
      }
      await _reload();
    });
  }

  Future<void> _reload() async {
    final id = _childId;
    if (id == null) {
      setState(() {
        _points = [];
        _status = null;
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
      final status = await api.get('/api/v1/emergency-meeting-points/$id/status');
      if (!mounted) return;
      setState(() {
        _points = (list['points'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _selectChild(String id) {
    if (_locked || _childId == id) return;
    setState(() => _childId = id);
    unawaited(_reload());
  }

  Future<void> _addPoint({bool backup = false}) async {
    final childId = _childId;
    if (childId == null) return;
    final l10n = AppLocalizations.of(context);
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(backup ? l10n.empAddBackup : l10n.empAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.empNameHint),
            ),
            const SizedBox(height: 8),
            Text(hit.address, style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.empInstructionsHint),
            ),
          ],
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
    final instructions = noteCtrl.text.trim();
    nameCtrl.dispose();
    noteCtrl.dispose();
    if (saved != true || name.isEmpty) return;

    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points',
        body: {
          'childId': childId,
          'name': name,
          'lat': hit.lat,
          'lng': hit.lng,
          if (instructions.isNotEmpty) 'instructions': instructions,
          'isPrimary': !backup,
        },
      );
      await _reload();
      if (!mounted) return;
      if (!backup) await _offerApplyToOthers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _offerApplyToOthers() async {
    final children = ref.read(childrenControllerProvider).items;
    final sourceId = _childId;
    if (sourceId == null || children.length < 2) return;
    final l10n = AppLocalizations.of(context);
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(l10n.empApplyToOthers),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in children)
                    if (c.id != sourceId)
                      CheckboxListTile(
                        value: selected.contains(c.id),
                        title: Text(c.name),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selected.add(c.id);
                            } else {
                              selected.remove(c.id);
                            }
                          });
                        },
                      ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.empActivateCancel),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: Text(l10n.empApply),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || selected.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/emergency-meeting-points/apply-to-all',
        body: {
          'sourceChildId': sourceId,
          'targetChildIds': selected.toList(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deletePoint(String id) async {
    try {
      await ref.read(apiClientProvider).delete(
        '/api/v1/emergency-meeting-points/$id',
      );
      await _reload();
    } catch (_) {}
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.empTitle,
              subtitle: selectedName ?? l10n.empSubtitle,
            ),
            if (!_locked && children.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = children[i];
                    final selected = c.id == _childId;
                    return ChoiceChip(
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          children: [
                            Text(
                              l10n.empSubtitle,
                              style: const TextStyle(
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_points.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      l10n.empEmpty(selectedName ?? ''),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () => unawaited(_addPoint()),
                                      child: Text(l10n.empAdd),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              for (final p in _points)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PointCard(
                                    point: p,
                                    distanceLabel: p['isPrimary'] == true
                                        ? (_status?['distanceLabel'] as String?)
                                        : null,
                                    onDelete: () => unawaited(
                                      _deletePoint(p['id'] as String),
                                    ),
                                  ),
                                ),
                              OutlinedButton(
                                onPressed: () =>
                                    unawaited(_addPoint(backup: true)),
                                child: Text(l10n.empAddBackup),
                              ),
                            ],
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F0),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.danger.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.empActivate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    key: const Key('emp_activate_button'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.danger,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: _activating
                                        ? null
                                        : () => unawaited(_activate()),
                                    child: Text(
                                      _activating
                                          ? '...'
                                          : l10n.empActivate,
                                    ),
                                  ),
                                ],
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

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.point,
    required this.onDelete,
    this.distanceLabel,
  });

  final Map<String, dynamic> point;
  final VoidCallback onDelete;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = point['isPrimary'] == true;
    final name = point['name'] as String? ?? '';
    final instructions = point['instructions'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary
                      ? AppColors.teal.withValues(alpha: 0.15)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  primary ? l10n.empPrimary : l10n.empBackup,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: primary ? AppColors.tealDeep : AppColors.inkSoft,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.inkSoft,
              ),
            ],
          ),
          if (instructions != null && instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              instructions,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ],
          if (distanceLabel != null && distanceLabel!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.empDistanceFromChild(distanceLabel!),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.tealDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
