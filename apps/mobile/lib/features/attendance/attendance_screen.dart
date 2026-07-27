import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/child_avatar.dart';
import '../parent/children_controller.dart';

/// Ringkasan di mana anak berada hari ini (rumah / sekolah / perjalanan / zona aman).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final Map<String, ChildGender> _genders = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadGenders);
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

  String _statusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'home':
        return l10n.statusHomeLabel;
      case 'school':
        return l10n.statusSchoolLabel;
      case 'safe_zone':
        return l10n.statusSafeZoneLabel;
      case 'commuting':
        return l10n.statusCommutingLabel;
      default:
        return '';
    }
  }

  String _statusTitle(AppLocalizations l10n, String? status) {
    final label = _statusLabel(l10n, status);
    if (label.isNotEmpty) return label;
    return l10n.locationUnclear;
  }

  String _statusHint(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'home':
        return l10n.inHomeZoneHint;
      case 'school':
        return l10n.inSchoolZoneHint;
      case 'commuting':
        return l10n.commutingHint;
      default:
        return l10n.locationHintDefault;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'home':
        return Icons.home_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'commuting':
        return Icons.directions_walk_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'home':
        return AppColors.teal;
      case 'school':
        return AppColors.sky;
      case 'commuting':
        return AppColors.amber;
      default:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider);
    if (children.items.isNotEmpty && _genders.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGenders());
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        title: Text(l10n.whereTitle),
        actions: [
          IconButton(
            tooltip: l10n.reloadTooltip,
            onPressed: () =>
                ref.read(childrenControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(childrenControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.childPositionsTodayTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.whereScreenIntro,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (children.items.isEmpty)
              PaEmptyState(
                icon: Icons.place_outlined,
                title: l10n.noChildrenTitle,
                message: l10n.addChildFirstMessage,
              )
            else
              ...children.items.map((child) {
                final gender = _genders[child.id] ??
                    ChildGenderStore.guessFromName(child.name);
                final status = child.commuteStatus;
                final color = _statusColor(status);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChildWhereDetailScreen(child: child),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            ChildAvatar(
                              name: child.name,
                              gender: gender,
                              size: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(_statusIcon(status),
                                          size: 16, color: color),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _statusTitle(l10n, status),
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _statusHint(l10n, status),
                                    style: const TextStyle(
                                      color: AppColors.inkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ChildWhereDetailScreen extends ConsumerStatefulWidget {
  const ChildWhereDetailScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<ChildWhereDetailScreen> createState() =>
      _ChildWhereDetailScreenState();
}

class _ChildWhereDetailScreenState
    extends ConsumerState<ChildWhereDetailScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final data = await ref.read(apiClientProvider).get(
        '/api/v1/attendance',
        query: {'childId': widget.child.id, 'date': date},
      );
      if (!mounted) return;
      setState(() {
        _events = (data['events'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'home':
        return l10n.statusHomeLabel;
      case 'school':
        return l10n.statusSchoolLabel;
      case 'safe_zone':
        return l10n.statusSafeZoneLabel;
      case 'commuting':
        return l10n.statusCommutingLabel;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = widget.child.commuteStatus;
    final statusLabel = _statusLabel(l10n, status);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        title: Text(l10n.whereDetailTitle(widget.child.name)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PaSectionCard(
            color: AppColors.mint.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel.isEmpty ? l10n.locationUnclear : statusLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.zoneStatusExplain,
                  style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.schoolNotesToday,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.schoolNotesHint,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_events.isEmpty)
            PaEmptyState(
              icon: Icons.event_available_outlined,
              title: l10n.noSchoolNotesTitle,
              message: l10n.noSchoolNotesMessage,
            )
          else
            ..._events.map((event) {
              final checkIn = event['event_type'] == 'check_in';
              final raw = event['recorded_at']?.toString();
              final at = raw == null ? null : DateTime.tryParse(raw);
              final timeLabel = at == null
                  ? (raw ?? '')
                  : '${at.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${at.toLocal().minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PaSectionCard(
                  color: (checkIn ? AppColors.mint : AppColors.sky)
                      .withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            checkIn ? AppColors.success : AppColors.sky,
                        child: Icon(
                          checkIn ? Icons.login : Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkIn
                                  ? l10n.arrivedAtSchool
                                  : l10n.departedFromSchool,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              timeLabel,
                              style: const TextStyle(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
