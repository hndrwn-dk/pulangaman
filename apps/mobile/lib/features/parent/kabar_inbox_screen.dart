import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'kabar_models.dart';

/// Full kabar history with per-child filter — used when home only shows
/// the latest status per child.
class KabarInboxScreen extends StatefulWidget {
  const KabarInboxScreen({
    super.key,
    required this.messages,
    this.initialChildId,
    this.childNames = const {},
  });

  final List<ChildKabarMessage> messages;
  final String? initialChildId;
  final Map<String, String> childNames;

  @override
  State<KabarInboxScreen> createState() => _KabarInboxScreenState();
}

class _KabarInboxScreenState extends State<KabarInboxScreen> {
  String? _filterChildId;

  @override
  void initState() {
    super.initState();
    _filterChildId = widget.initialChildId;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final groups = <String, List<ChildKabarMessage>>{};
    for (final msg in filtered) {
      final key = dayLabel(msg.sentAt);
      groups.putIfAbsent(key, () => []).add(msg);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat kabar'),
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
            child: Text(
              filtered.isEmpty
                  ? 'Belum ada kabar'
                  : '${filtered.length} kabar · 24 jam terakhir',
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
                        ...entry.value.map((msg) => _HistoryTile(msg: msg)),
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
  const _HistoryTile({required this.msg});

  final ChildKabarMessage msg;

  @override
  Widget build(BuildContext context) {
    final color = kabarPresetColor(msg.preset);
    final local = msg.sentAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUrgent
              ? AppColors.coral.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
    );
  }
}
