import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/child_avatar.dart';
import '../parent/children_controller.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  String? _childId;
  Map<String, dynamic> _balance = {};
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = false;
  final Map<String, ChildGender> _genders = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      final items = ref.read(childrenControllerProvider).items;
      if (items.isNotEmpty) await _load(items.first.id);
    });
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

  Future<void> _load(String childId) async {
    setState(() {
      _childId = childId;
      _loading = true;
    });
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/rewards/$childId');
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as Map<String, dynamic>?) ?? {};
        _ledger = (data['ledger'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _bonus() async {
    final childId = _childId;
    if (childId == null) return;
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        if (!refresh) {
          return AlertDialog(
            title: Text(l10n.giveRewardTitle),
            content: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.rewardReasonLabel,
                hintText: l10n.rewardReasonHint,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                child: Text(l10n.addFivePointsAction),
              ),
            ],
          );
        }
        return Dialog(
          backgroundColor: VisualRefreshColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: VisualRefreshColors.border,
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.giveRewardTitle,
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: VisualRefreshColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: VisualRefreshColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.rewardReasonLabel,
                    hintText: l10n.rewardReasonHint,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: VisualRefreshColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: VisualRefreshColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: VisualRefreshColors.surface,
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
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VisualRefreshColors.textPrimary,
                            side: const BorderSide(
                              color: VisualRefreshColors.border,
                              width: 0.5,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l10n.cancel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: VisualRefreshColors.praiseBtn,
                            foregroundColor: VisualRefreshColors.anchor,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l10n.addFivePointsAction,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/rewards/$childId/adjust',
        body: {
          'delta': 5,
          'reason': controller.text.trim().isEmpty
              ? l10n.defaultPraiseReason
              : controller.text.trim(),
        },
      );
      await _load(childId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pointsAddedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorWithDetail('$e'))),
      );
    }
  }

  Future<void> _pickChild(List<ChildSummary> items) async {
    final l10n = AppLocalizations.of(context);
    final current = _childId;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.pickChildTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
            ),
            for (final c in items)
              ListTile(
                leading: ChildAvatar(
                  name: c.name,
                  gender: _genders[c.id] ??
                      ChildGenderStore.guessFromName(c.name),
                  size: 40,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: c.id == current
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _load(picked);
  }

  String _formatLedgerWhen(DateTime? at, String? raw, {required bool refresh}) {
    if (at == null) return raw ?? '';
    final local = at.toLocal();
    if (!refresh) {
      return '${local.day}/${local.month} '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM, HH:mm', locale).format(local);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final children = ref.watch(childrenControllerProvider);
    final items = children.items;
    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (c) => c.id == _childId,
            orElse: () => items.first,
          );
    final points = (_balance['points'] as num?)?.toInt() ?? 0;
    final streak = (_balance['current_streak'] as num?)?.toInt() ?? 0;
    final name = selected?.name ?? l10n.homeByDefaultChildName;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      floatingActionButton: refresh || selected == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _bonus,
              backgroundColor: AppColors.coral,
              icon: const Icon(Icons.favorite_rounded),
              label: Text(
                l10n.givePraiseFabLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.rewardsTitle,
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
              child: RefreshIndicator(
                color: refresh ? VisualRefreshColors.accent : AppColors.teal,
                onRefresh: () async {
                  final id = _childId;
                  if (id != null) await _load(id);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    refresh ? 0 : 4,
                    16,
                    refresh ? 24 : 100,
                  ),
                  children: [
                    Text(
                      l10n.rewardsIntro,
                      style: refresh
                          ? GoogleFonts.plusJakartaSans(
                              color: VisualRefreshColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              fontSize: 14,
                            )
                          : const TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              fontSize: 13.5,
                            ),
                    ),
                    SizedBox(height: refresh ? 16 : 14),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          l10n.noChildren,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                        ),
                      )
                    else ...[
                      if (refresh)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                _ChildChip(
                                  name: items[i].name,
                                  selected: items[i].id == selected?.id,
                                  onTap: () => _load(items[i].id),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _pickChild(items),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ChildAvatar(
                                    name: name,
                                    gender: _genders[selected!.id] ??
                                        ChildGenderStore.guessFromName(name),
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    color: AppColors.inkSoft,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: refresh ? 16 : 14),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _PointsHeroCard(
                          childName: name,
                          points: points,
                          streak: streak,
                          refresh: refresh,
                        ),
                        SizedBox(height: refresh ? 22 : 22),
                        if (refresh) ...[
                          _SectionLabel(l10n.howToEarnPointsReferenceTitle),
                          const SizedBox(height: 10),
                          _VrEarnCard(
                            rows: [
                              _VrEarnRowData(
                                icon: Icons.school_outlined,
                                title: l10n.earnSchoolOnTimeTitle,
                                subtitle: l10n.earnPerDayLabel,
                                points: '+10',
                              ),
                              _VrEarnRowData(
                                icon: Icons.home_outlined,
                                title: l10n.earnHomeOnTimeTitle,
                                subtitle: l10n.earnPerDayLabel,
                                points: '+5',
                              ),
                              _VrEarnRowData(
                                icon: Icons.favorite_border_rounded,
                                title: l10n.earnParentPraiseTitle,
                                subtitle: l10n.earnManualLabel,
                                points: '+5',
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _SectionLabel(l10n.pointsHistoryTitle),
                          const SizedBox(height: 10),
                          if (_ledger.isEmpty)
                            _VrEmptyHistory(l10n: l10n)
                          else
                            _VrHistoryCard(
                              children: [
                                for (var i = 0; i < _ledger.length; i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: VisualRefreshColors.border,
                                    ),
                                  _VrHistoryRow(
                                    item: _ledger[i],
                                    when: _formatLedgerWhen(
                                      DateTime.tryParse(
                                        '${_ledger[i]['created_at'] ?? ''}',
                                      ),
                                      _ledger[i]['created_at']?.toString(),
                                      refresh: true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ] else ...[
                          Text(
                            l10n.howToEarnPointsTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _EarnRow(
                            icon: Icons.school_rounded,
                            iconBg: const Color(0xFFDCEBFF),
                            iconColor: const Color(0xFF2563EB),
                            title: l10n.earnSchoolOnTimeTitle,
                            subtitle: l10n.earnSchoolOnTimeSubtitle,
                            points: '+10',
                          ),
                          const SizedBox(height: 8),
                          _EarnRow(
                            icon: Icons.home_rounded,
                            iconBg: const Color(0xFFE8F6F1),
                            iconColor: AppColors.tealDeep,
                            title: l10n.earnHomeOnTimeTitle,
                            subtitle: l10n.earnHomeOnTimeSubtitle,
                            points: '+5',
                          ),
                          const SizedBox(height: 8),
                          _EarnRow(
                            icon: Icons.favorite_rounded,
                            iconBg: const Color(0xFFFFE8E6),
                            iconColor: AppColors.coral,
                            title: l10n.earnParentPraiseTitle,
                            subtitle: l10n.earnParentPraiseSubtitle,
                            points: '+5',
                          ),
                          const SizedBox(height: 22),
                          Text(
                            l10n.pointsHistoryTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_ledger.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 28,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.markunread_mailbox_outlined,
                                    size: 44,
                                    color: Color(0xFF93C5FD),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.noPointsHistoryTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.noPointsHistoryMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.inkSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._ledger.map((item) {
                              final raw = item['created_at']?.toString();
                              final at =
                                  raw == null ? null : DateTime.tryParse(raw);
                              final when = _formatLedgerWhen(
                                at,
                                raw,
                                refresh: false,
                              );
                              final delta =
                                  (item['delta'] as num?)?.toInt() ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    14,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F6F1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          delta >= 0 ? '+$delta' : '$delta',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.tealDeep,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item['reason']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              when,
                                              style: const TextStyle(
                                                color: AppColors.inkSoft,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (refresh && selected != null) _PraiseFooter(onPressed: _bonus),
          ],
        ),
      ),
    );
  }
}

class _PraiseFooter extends StatelessWidget {
  const _PraiseFooter({required this.onPressed});

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
          icon: const Icon(Icons.favorite_border_rounded, size: 20),
          label: Text(
            l10n.givePraiseFabLabel,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: VisualRefreshColors.praiseBtn,
            foregroundColor: VisualRefreshColors.anchor,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: VisualRefreshColors.textSecondary,
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  : VisualRefreshColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsHeroCard extends StatelessWidget {
  const _PointsHeroCard({
    required this.childName,
    required this.points,
    required this.streak,
    this.refresh = false,
  });

  final String childName;
  final int points;
  final int streak;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dayLabels = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];
    final dayLetters = [
      for (final label in dayLabels)
        label.isEmpty ? '' : label.substring(0, 1).toUpperCase(),
    ];
    final todayIndex = DateTime.now().weekday - 1; // Mon=0
    final filled = streak.clamp(0, 7);

    if (refresh) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: VisualRefreshColors.rewardBg,
          borderRadius: BorderRadius.circular(AppRadius.vrHero),
          border: Border.all(
            color: VisualRefreshColors.rewardBorder,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: VisualRefreshColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$points',
                    style: GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.rewardAccent,
                      letterSpacing: -0.8,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.totalPointsForChild(childName),
                        style: GoogleFonts.plusJakartaSans(
                          color: VisualRefreshColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        streak == 0
                            ? l10n.noStreakYet
                            : l10n.streakDaysLabel(streak),
                        style: GoogleFonts.plusJakartaSans(
                          color: VisualRefreshColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.weeklyStreakTitle.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: VisualRefreshColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _StreakDot(
                    letter: dayLetters[i],
                    label: dayLabels[i],
                    active: filled > 0 &&
                        i >= (todayIndex - filled + 1).clamp(0, 6) &&
                        i <= todayIndex,
                    refresh: true,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8913A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8913A).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8913A),
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.totalPointsForChild(childName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streak == 0
                          ? l10n.noStreakYet
                          : l10n.streakDaysLabel(streak),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.earnExampleHint,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.weeklyStreakTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _StreakDot(
                  letter: dayLetters[i],
                  label: dayLabels[i],
                  active: filled > 0 &&
                      i >= (todayIndex - filled + 1).clamp(0, 6) &&
                      i <= todayIndex,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  const _StreakDot({
    required this.letter,
    required this.label,
    required this.active,
    this.refresh = false,
  });

  final String letter;
  final String label;
  final bool active;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    if (refresh) {
      return Column(
        children: [
          // Display-only badge — no Material/InkWell press state.
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? VisualRefreshColors.rewardAccent
                  : VisualRefreshColors.surface,
              shape: BoxShape.circle,
              border: active
                  ? null
                  : Border.all(
                      color: VisualRefreshColors.rewardAccent,
                      width: 1.2,
                    ),
            ),
            child: Text(
              letter,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: active
                    ? VisualRefreshColors.surface
                    : VisualRefreshColors.rewardAccent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: VisualRefreshColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: active
                  ? const Color(0xFFE8913A)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _VrEarnRowData {
  const _VrEarnRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String points;
}

class _VrEarnCard extends StatelessWidget {
  const _VrEarnCard({required this.rows});

  final List<_VrEarnRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VisualRefreshColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: VisualRefreshColors.border,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Icon(
                    rows[i].icon,
                    color: VisualRefreshColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: VisualRefreshColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[i].subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            color: VisualRefreshColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    rows[i].points,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: VisualRefreshColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VrHistoryCard extends StatelessWidget {
  const _VrHistoryCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VisualRefreshColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _VrHistoryRow extends StatelessWidget {
  const _VrHistoryRow({
    required this.item,
    required this.when,
  });

  final Map<String, dynamic> item;
  final String when;

  @override
  Widget build(BuildContext context) {
    final delta = (item['delta'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VisualRefreshColors.accentTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              delta >= 0 ? '+$delta' : '$delta',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: VisualRefreshColors.accent,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['reason']}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: VisualRefreshColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VrEmptyHistory extends StatelessWidget {
  const _VrEmptyHistory({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: VisualRefreshColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.markunread_mailbox_outlined,
            size: 40,
            color: VisualRefreshColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noPointsHistoryTitle,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: VisualRefreshColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noPointsHistoryMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: VisualRefreshColors.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.tealDeep,
            ),
          ),
        ],
      ),
    );
  }
}
