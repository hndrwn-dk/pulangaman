import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import 'kabar_models.dart';

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
        const SnackBar(content: Text('Semua kabar ditandai sudah dibaca')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final groups = <String, List<ChildKabarMessage>>{};
    for (final msg in filtered) {
      final key = dayLabel(msg.sentAt);
      groups.putIfAbsent(key, () => []).add(msg);
    }
    final unreadCount = filtered.where((m) => _unreadIds.contains(m.id)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        leading: paAppBarLeading(context),
        title: const Text('Riwayat kabar'),
        actions: [
          if (widget.onMarkAllRead != null && unreadCount > 0)
            TextButton(
              onPressed: _marking ? null : _markAllRead,
              child: Text(
                _marking ? '...' : 'Tandai dibaca',
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
                  label: 'Semua',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filtered.isEmpty
                        ? 'Belum ada kabar'
                        : unreadCount > 0
                            ? '$unreadCount belum dibaca · ${filtered.length} kabar · 24 jam'
                            : '${filtered.length} kabar · 24 jam terakhir',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (widget.onMarkAllRead != null && unreadCount > 0)
                  TextButton(
                    onPressed: _marking ? null : _markAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.tealDeep,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Tandai semua dibaca',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada kabar untuk filter ini.',
                      style: TextStyle(color: AppColors.inkSoft),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.msg, required this.unread});

  final ChildKabarMessage msg;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final color = kabarPresetColor(msg.preset);
    final local = msg.sentAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

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
