import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Live (or planned) safe-trip progress card used on Places hub.
class TripRouteCard extends StatelessWidget {
  const TripRouteCard({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.meta,
    required this.progress,
    this.status,
    this.onTap,
    this.onStart,
    this.onCancel,
  });

  final String fromLabel;
  final String toLabel;
  final String meta;
  /// 0..1 fill along the route bar.
  final double progress;
  final String? status;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final isPlanned = status == 'planned';
    final isArrived = status == 'arrived' || p >= 0.999;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isArrived
                            ? Icons.check_circle_rounded
                            : Icons.directions_walk_rounded,
                        color: AppColors.tealDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromLabel → $toLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onCancel != null)
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.inkSoft,
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.inkSoft,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _TripDot(label: fromLabel),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: [
                                Container(color: const Color(0xFFE2E6EA)),
                                FractionallySizedBox(
                                  widthFactor: p,
                                  child: Container(color: AppColors.teal),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _TripDot(label: toLabel, filled: isArrived || p > 0.05),
                  ],
                ),
                if (isPlanned && onStart != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: onStart,
                      child: const Text('Mulai pantau'),
                    ),
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

class _TripDot extends StatelessWidget {
  const _TripDot({required this.label, this.filled = true});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: filled ? AppColors.teal : const Color(0xFFE2E6EA),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.teal, width: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
