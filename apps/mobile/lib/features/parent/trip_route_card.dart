import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final p = progress.clamp(0.0, 1.0);
    final isPlanned = status == 'planned';
    final isArrived = status == 'arrived' || p >= 0.999;
    final radius = refresh ? AppRadius.vrCard : 18.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: refresh ? VisualRefreshColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: refresh
                ? Border.all(color: VisualRefreshColors.border, width: 0.5)
                : null,
            boxShadow: refresh
                ? null
                : [
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
                        color: refresh
                            ? VisualRefreshColors.accentTint
                            : const Color(0xFFE8F6F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isArrived
                            ? Icons.check_circle_rounded
                            : Icons.directions_walk_rounded,
                        color: refresh
                            ? VisualRefreshColors.accent
                            : AppColors.tealDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromLabel → $toLabel',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: refresh
                                  ? VisualRefreshColors.textPrimary
                                  : null,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: TextStyle(
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onCancel != null)
                      IconButton(
                        tooltip: l10n.cancelTripTooltip,
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded),
                        color: refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft,
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _TripDot(label: fromLabel, filled: true),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: [
                                Container(
                                  color: refresh
                                      ? VisualRefreshColors.border
                                      : const Color(0xFFE2E6EA),
                                ),
                                FractionallySizedBox(
                                  widthFactor: p,
                                  child: Container(
                                    color: refresh
                                        ? VisualRefreshColors.anchor
                                        : AppColors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _TripDot(
                      label: toLabel,
                      filled: isArrived || p > 0.05,
                      endDot: true,
                    ),
                  ],
                ),
                if (isPlanned && onStart != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: onStart,
                      style: refresh
                          ? FilledButton.styleFrom(
                              backgroundColor: VisualRefreshColors.anchor,
                              foregroundColor: VisualRefreshColors.background,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            )
                          : null,
                      child: Text(
                        l10n.startMonitoringAction,
                        style: refresh
                            ? GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              )
                            : null,
                      ),
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
  const _TripDot({
    required this.label,
    this.filled = true,
    this.endDot = false,
  });

  final String label;
  final bool filled;
  final bool endDot;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final Color fillColor;
    final Color borderColor;
    if (refresh) {
      if (endDot && !filled) {
        fillColor = Colors.transparent;
        borderColor = VisualRefreshColors.accent;
      } else {
        fillColor = filled
            ? VisualRefreshColors.anchor
            : VisualRefreshColors.border;
        borderColor = VisualRefreshColors.anchor;
      }
    } else {
      fillColor = filled ? AppColors.teal : const Color(0xFFE2E6EA);
      borderColor = AppColors.teal;
    }

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: refresh
                  ? VisualRefreshColors.textSecondary
                  : AppColors.inkSoft,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
