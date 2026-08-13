import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'kabar_models.dart';

/// Soft accent-tinted border for unread VR cards (routine highlight, not danger).
const _vrUnreadBorder = Color(0xFFB9D6C6);

/// Full kabar history with per-child filter — used when home only shows
/// the latest status per child.
class KabarInboxScreen extends StatefulWidget {
  const KabarInboxScreen({
    super.key,
    required this.messages,
    this.initialChildId,
    this.childNames = const {},
    this.unreadIds = const {},
    this.onMarkAllRead,
  });

  final List<ChildKabarMessage> messages;
  final String? initialChildId;
  final Map<String, String> childNames;
  final Set<String> unreadIds;
  final Future<void> Function()? onMarkAllRead;

  @override
  State<KabarInboxScreen> createState() => _KabarInboxScreenState();
}

class _KabarInboxScreenState extends State<KabarInboxScreen> {
  String? _filterChildId;
  bool _marking = false;
  Set<String> _unreadIds = {};

  @override
  void initState() {
    super.initState();
    _filterChildId = widget.initialChildId;
    _unreadIds = {...widget.unreadIds};
  }

  @override
  void didUpdateWidget(covariant KabarInboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadIds != widget.unreadIds) {
      _unreadIds = {...widget.unreadIds};
    }
  }

  List<ChildKabarMessage> get _filtered {
    final list = widget.messages.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    if (_filterChildId == null) return list;
    return list.where((m) => m.childId == _filterChildId).toList();
  }

  List<MapEntry<String, String>> get _childFilters {
    final map = <String, String>{...widget.childNames};
    for (final m in widget.messages) {
      map.putIfAbsent(m.childId, () => m.childName);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  Future<void> _markAllRead() async {
    final onMark = widget.onMarkAllRead;
    if (onMark == null || _marking) return;
    setState(() => _marking = true);
    try {
      await onMark();
      if (!mounted) return;
      setState(() {
        _unreadIds = {};
        _marking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).allKabarMarkedRead)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _marking = false);
    }
  }

  String? _emptyMessage(AppLocalizations l10n, List<ChildKabarMessage> filtered) {
    if (filtered.isNotEmpty) return null;
    if (widget.messages.isEmpty) return l10n.noKabarYet;
    return l10n.noKabarForFilter;
  }

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;
    final groups = <String, List<ChildKabarMessage>>{};
    for (final msg in filtered) {
      final key = dayLabel(l10n, msg.sentAt);
      groups.putIfAbsent(key, () => []).add(msg);
    }
    final unreadCount = filtered.where((m) => _unreadIds.contains(m.id)).length;
    final emptyMessage = _emptyMessage(l10n, filtered);
    final showMarkAll =
        widget.onMarkAllRead != null && unreadCount > 0;

    if (refresh) {
      return _buildVr(
        context: context,
        l10n: l10n,
        filtered: filtered,
        groups: groups,
        unreadCount: unreadCount,
        emptyMessage: emptyMessage,
        showMarkAll: showMarkAll,
      );
    }

    return _buildClassic(
      context: context,
      l10n: l10n,
      filtered: filtered,
      groups: groups,
      unreadCount: unreadCount,
      emptyMessage: emptyMessage,
      showMarkAll: showMarkAll,
    );
  }

  Widget _buildVr({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<ChildKabarMessage> filtered,
    required Map<String, List<ChildKabarMessage>> groups,
    required int unreadCount,
    required String? emptyMessage,
    required bool showMarkAll,
  }) {
    return Scaffold(
      backgroundColor: VisualRefreshColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaScreenHeader(
              title: l10n.kabarHistoryTitle,
              titleStyle: GoogleFonts.fraunces(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: VisualRefreshColors.textPrimary,
              ),
              trailing: showMarkAll
                  ? TextButton(
                      onPressed: _marking ? null : _markAllRead,
                      style: TextButton.styleFrom(
                        foregroundColor: VisualRefreshColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _marking ? '...' : l10n.markAllReadAction,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : null,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: l10n.allFilterLabel,
                    selected: _filterChildId == null,
                    onTap: () => setState(() => _filterChildId = null),
                    refresh: true,
                  ),
                  ..._childFilters.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: e.value,
                        selected: _filterChildId == e.key,
                        onTap: () => setState(() => _filterChildId = e.key),
                        refresh: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  unreadCount > 0
                      ? l10n.kabarSummaryUnread(unreadCount, filtered.length)
                      : l10n.kabarSummaryAll(filtered.length),
                  style: GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: emptyMessage != null
                  ? Center(
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: VisualRefreshColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                color: VisualRefreshColors.textTertiary,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (msg) => _HistoryTile(
                              msg: msg,
                              unread: _unreadIds.contains(msg.id),
                              refresh: true,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassic({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<ChildKabarMessage> filtered,
    required Map<String, List<ChildKabarMessage>> groups,
    required int unreadCount,
    required String? emptyMessage,
    required bool showMarkAll,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        title: Text(l10n.kabarHistoryTitle),
        actions: [
          if (showMarkAll)
            TextButton(
              onPressed: _marking ? null : _markAllRead,
              child: Text(
                _marking ? '...' : l10n.markAllReadAction,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.allFilterLabel,
                  selected: _filterChildId == null,
                  onTap: () => setState(() => _filterChildId = null),
                ),
                ..._childFilters.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: e.value,
                      selected: _filterChildId == e.key,
                      onTap: () => setState(() => _filterChildId = e.key),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                unreadCount > 0
                    ? l10n.kabarSummaryUnread(unreadCount, filtered.length)
                    : l10n.kabarSummaryAll(filtered.length),
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: emptyMessage != null
                ? Center(
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (msg) => _HistoryTile(
                            msg: msg,
                            unread: _unreadIds.contains(msg.id),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.refresh = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    if (refresh) {
      final selectedFill = VisualRefreshColors.anchor;
      final selectedFg = VisualRefreshColors.background;
      final unselectedFg = VisualRefreshColors.anchor;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? selectedFill : VisualRefreshColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: selected
                  ? null
                  : Border.all(color: VisualRefreshColors.border, width: 0.5),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? selectedFg : unselectedFg,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.teal : const Color(0x22075A4F),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.msg,
    required this.unread,
    this.refresh = false,
  });

  final ChildKabarMessage msg;
  final bool unread;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final local = msg.sentAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (refresh) {
      final urgent = msg.isUrgent;
      final iconBg = urgent
          ? VisualRefreshColors.dangerTint
          : VisualRefreshColors.accentTint;
      final iconColor =
          urgent ? VisualRefreshColors.danger : VisualRefreshColors.accent;
      final borderColor = unread
          ? (urgent ? VisualRefreshColors.dangerTintBorder : _vrUnreadBorder)
          : VisualRefreshColors.border;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: urgent && unread
                ? VisualRefreshColors.dangerTint
                : VisualRefreshColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.vrCard),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  kabarPresetIcon(msg.preset),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            msg.childName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: VisualRefreshColors.textPrimary,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: VisualRefreshColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          time,
                          style: GoogleFonts.plusJakartaSans(
                            color: VisualRefreshColors.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: VisualRefreshColors.textSecondary,
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

    final color = kabarPresetColor(msg.preset);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: unread ? 1 : 0.72,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: msg.isUrgent
                ? AppColors.coral.withValues(alpha: unread ? 0.10 : 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? color.withValues(alpha: 0.35)
                  : color.withValues(alpha: 0.16),
              width: unread ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(kabarPresetIcon(msg.preset), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            msg.childName,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(msg.text),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
