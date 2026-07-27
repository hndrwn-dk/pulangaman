import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'zone_alert_host.dart';

/// Featured child card on parent home: map preview + status + quick metrics.
class ChildHomeMapCard extends StatelessWidget {
  const ChildHomeMapCard({
    super.key,
    required this.child,
    required this.gender,
    required this.position,
    required this.onOpenMap,
    this.batteryLevel,
    this.batteryCharging = false,
    this.stale = true,
    this.updatedAt,
    this.stayDurationLabel,
    this.onRelinkCode,
    this.onRemove,
  });

  final ChildSummary child;
  final ChildGender gender;
  final LatLng? position;
  final VoidCallback onOpenMap;
  final int? batteryLevel;
  final bool batteryCharging;
  final bool stale;
  final DateTime? updatedAt;
  final String? stayDurationLabel;
  final VoidCallback? onRelinkCode;
  final VoidCallback? onRemove;

  String _where(AppLocalizations l10n) {
    final label = commuteStatusLabel(l10n, child.commuteStatus);
    if (label.isNotEmpty) {
      if (child.commuteStatus == 'home') return l10n.homeArrivedStatus;
      return label;
    }
    return position == null ? l10n.locationUnclear : l10n.seenOnMap;
  }

  String _whenBubble(AppLocalizations l10n) {
    if (position == null) return l10n.waitingLocationDots;
    final at = updatedAt ??
        (child.lastSeenAt != null
            ? DateTime.tryParse(child.lastSeenAt!)?.toLocal()
            : null);
    if (at == null) return l10n.hereNowLabel;
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return l10n.hereAtTime(hm);
  }

  String _signalKey() {
    if (position == null || updatedAt == null) return 'lost';
    final age = DateTime.now().difference(updatedAt!);
    if (stale || age.inMinutes >= 30) return 'weak';
    if (age.inMinutes >= 10) return 'medium';
    return 'strong';
  }

  String _signalLabel(AppLocalizations l10n) {
    switch (_signalKey()) {
      case 'strong':
        return l10n.signalStrong;
      case 'medium':
        return l10n.signalMedium;
      case 'weak':
        return l10n.signalWeak;
      default:
        return l10n.signalLost;
    }
  }

  Color get _signalColor {
    switch (_signalKey()) {
      case 'strong':
        return const Color(0xFF3B82F6);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.inkSoft;
    }
  }

  String get _batteryLabel {
    final v = batteryLevel;
    if (v == null) return '—';
    return batteryCharging ? '$v%+' : '$v%';
  }

  String _freshnessBadge(AppLocalizations l10n, {required bool refresh}) {
    if (!refresh) {
      final active = !stale && position != null;
      return active ? l10n.activeBadgeShort : l10n.staleBadgeShort;
    }
    final at = updatedAt ??
        (child.lastSeenAt != null
            ? DateTime.tryParse(child.lastSeenAt!)?.toLocal()
            : null);
    if (at == null) {
      return stale ? l10n.locationNotUpdatedRecently : l10n.updatedJustNowBadge;
    }
    final age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return l10n.updatedJustNowBadge;
    if (age.inHours < 1) return l10n.updatedMinutesAgoBadge(age.inMinutes);
    if (age.inDays < 1) return l10n.updatedHoursAgoBadge(age.inHours);
    return l10n.updatedHoursAgoBadge(age.inHours.clamp(1, 99));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final active = !stale && position != null;
    final heroRadius = refresh ? AppRadius.vrHero : 24.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(heroRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: refresh ? VisualRefreshColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(heroRadius),
            border: refresh ? Border.all(
              color: VisualRefreshColors.border,
              width: 0.5,
            ) : null,
            boxShadow: refresh
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 168,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(heroRadius),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (position != null)
                        GoogleMap(
                          key: ValueKey(
                            '${child.id}-${position!.latitude.toStringAsFixed(5)}-'
                            '${position!.longitude.toStringAsFixed(5)}',
                          ),
                          initialCameraPosition: CameraPosition(
                            target: position!,
                            zoom: 15,
                          ),
                          liteModeEnabled: true,
                          markers: {
                            Marker(
                              markerId: MarkerId(child.id),
                              position: position!,
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
                          onTap: (_) => onOpenMap(),
                        )
                      else
                        Container(
                          color: refresh
                              ? VisualRefreshColors.accentTint
                              : AppColors.mint.withValues(alpha: 0.55),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 36,
                                  color: refresh
                                      ? VisualRefreshColors.anchor
                                      : AppColors.tealDeep,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.waitingLocationDots,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: refresh
                                        ? VisualRefreshColors.anchor
                                        : AppColors.tealDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        left: 14,
                        right: 14,
                        top: 12,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: refresh
                                  ? VisualRefreshColors.anchor
                                  : AppColors.tealDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _whenBubble(l10n),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                fontFamily: refresh
                                    ? GoogleFonts.plusJakartaSans().fontFamily
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChildAvatar(
                          name: child.name,
                          gender: gender,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      child.name,
                                      style: refresh
                                          ? GoogleFonts.fraunces(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  VisualRefreshColors.textPrimary,
                                            )
                                          : const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: refresh
                                          ? VisualRefreshColors.tagMuted
                                          : active
                                              ? const Color(0xFFD8F5E8)
                                              : const Color(0xFFFFF0E0),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _freshnessBadge(l10n, refresh: refresh),
                                      style: TextStyle(
                                        fontSize: refresh ? 11 : 10,
                                        fontWeight: refresh
                                            ? FontWeight.w600
                                            : FontWeight.w900,
                                        letterSpacing: refresh ? 0 : 0.4,
                                        color: refresh
                                            ? VisualRefreshColors.textSecondary
                                            : active
                                                ? AppColors.tealDeep
                                                : const Color(0xFFC46A0A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: refresh
                                          ? (active
                                              ? VisualRefreshColors.accent
                                              : VisualRefreshColors
                                                  .textSecondary)
                                          : active
                                              ? AppColors.teal
                                              : const Color(0xFFE8A11A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _where(l10n),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: refresh
                                            ? (position == null
                                                ? VisualRefreshColors
                                                    .textSecondary
                                                : VisualRefreshColors
                                                    .textPrimary)
                                            : position == null
                                                ? AppColors.inkSoft
                                                : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (onRelinkCode != null || onRemove != null)
                          refresh
                              ? _VisualRefreshOverflowMenu(
                                  tooltip: l10n.optionsTooltip,
                                  relinkLabel: l10n.relinkCodeShort,
                                  removeLabel: l10n.removeFromList,
                                  onRelink: onRelinkCode,
                                  onRemove: onRemove,
                                )
                              : PopupMenuButton<String>(
                                  tooltip: l10n.optionsTooltip,
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'relink') {
                                      onRelinkCode?.call();
                                    }
                                    if (value == 'remove') onRemove?.call();
                                  },
                                  itemBuilder: (context) => [
                                    if (onRelinkCode != null)
                                      PopupMenuItem(
                                        value: 'relink',
                                        child: Text(
                                          l10n.relinkCodeMenu(child.name),
                                        ),
                                      ),
                                    if (onRemove != null)
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(l10n.removeFromList),
                                      ),
                                  ],
                                ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.battery_std_rounded,
                            iconColor: refresh
                                ? VisualRefreshColors.accent
                                : AppColors.teal,
                            label: l10n.batteryMetricLabel,
                            value: _batteryLabel,
                            refresh: refresh,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.signal_cellular_alt_rounded,
                            iconColor: refresh
                                ? VisualRefreshColors.accent
                                : _signalColor,
                            label: l10n.signalMetricLabel,
                            value: _signalLabel(l10n),
                            refresh: refresh,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.timer_outlined,
                            iconColor: refresh
                                ? VisualRefreshColors.accent
                                : const Color(0xFF8B5CF6),
                            label: l10n.timeMetricLabel,
                            value: stayDurationLabel ?? '—',
                            refresh: refresh,
                          ),
                        ),
                      ],
                    ),
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.refresh = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.warmTint
            : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrChip : 14),
      ),
      child: Column(
        crossAxisAlignment: refresh
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (refresh)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textTertiary,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: refresh ? TextAlign.center : TextAlign.start,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textPrimary,
                  )
                : const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Anchored overflow popover matching visual-refresh mockups.
class _VisualRefreshOverflowMenu extends StatefulWidget {
  const _VisualRefreshOverflowMenu({
    required this.tooltip,
    required this.relinkLabel,
    required this.removeLabel,
    this.onRelink,
    this.onRemove,
  });

  final String tooltip;
  final String relinkLabel;
  final String removeLabel;
  final VoidCallback? onRelink;
  final VoidCallback? onRemove;

  @override
  State<_VisualRefreshOverflowMenu> createState() =>
      _VisualRefreshOverflowMenuState();
}

class _VisualRefreshOverflowMenuState extends State<_VisualRefreshOverflowMenu> {
  OverlayEntry? _entry;

  void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  void _open() {
    _dismiss();
    final box = context.findRenderObject() as RenderBox?;
    final overlayState = Overlay.of(context);
    final overlayBox =
        overlayState.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    const menuWidth = 212.0;
    const menuEstimateH = 112.0;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;
    final screen = overlayBox.size;
    final safeTop = MediaQuery.paddingOf(context).top + 8;

    // Match mockup: float just below the ⋮ with a gap. Flip above only when
    // there is not enough room above the bottom safe inset.
    var top = origin.dy + size.height + 8;
    if (top + menuEstimateH > screen.height - 24) {
      top = origin.dy - menuEstimateH - 8;
    }
    if (top < safeTop) top = safeTop;

    var left = origin.dx + size.width - menuWidth;
    left = left.clamp(12.0, screen.width - menuWidth - 12);

    _entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: VisualRefreshColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: VisualRefreshColors.border,
                      width: 0.5,
                    ),
                    boxShadow: const [VisualRefreshColors.popoverShadow],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onRelink != null)
                        _OverflowMenuRow(
                          icon: Icons.link_rounded,
                          iconColor: VisualRefreshColors.accent,
                          label: widget.relinkLabel,
                          labelColor: VisualRefreshColors.textPrimary,
                          onTap: () {
                            _dismiss();
                            widget.onRelink?.call();
                          },
                        ),
                      if (widget.onRelink != null && widget.onRemove != null)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: VisualRefreshColors.border,
                        ),
                      if (widget.onRemove != null)
                        _OverflowMenuRow(
                          icon: Icons.delete_outline_rounded,
                          iconColor: VisualRefreshColors.danger,
                          label: widget.removeLabel,
                          labelColor: VisualRefreshColors.danger,
                          onTap: () {
                            _dismiss();
                            widget.onRemove?.call();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(_entry!);
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: widget.tooltip,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 24,
              color: VisualRefreshColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowMenuRow extends StatelessWidget {
  const _OverflowMenuRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
