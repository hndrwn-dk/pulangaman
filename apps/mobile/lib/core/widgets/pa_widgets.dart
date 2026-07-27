import 'package:flutter/material.dart';
import '../theme.dart';

/// Circular white icon chip used on map overlays and screen headers.
class PaRoundIconButton extends StatelessWidget {
  const PaRoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor = Colors.white,
    this.size = 42,
    this.iconSize = 20,
    this.elevation = 3,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final resolvedBg = refresh && backgroundColor == Colors.white
        ? VisualRefreshColors.surface
        : backgroundColor;
    final resolvedIcon =
        iconColor ?? (refresh ? VisualRefreshColors.textPrimary : AppColors.ink);
    return Material(
      color: resolvedBg,
      shape: CircleBorder(
        side: refresh
            ? const BorderSide(
                color: VisualRefreshColors.border,
                width: 0.5,
              )
            : BorderSide.none,
      ),
      elevation: refresh ? 0 : elevation,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: resolvedIcon),
        ),
      ),
    );
  }
}

/// Map-style circular back chip (white circle + dark arrow).
class PaBackButton extends StatelessWidget {
  const PaBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PaRoundIconButton(
      icon: Icons.arrow_back_rounded,
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// AppBar [leading] that matches [PaBackButton] + header spacing.
Widget paAppBarLeading(BuildContext context, {VoidCallback? onPressed}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: PaScreenHeader.edgePad),
      child: PaBackButton(onPressed: onPressed),
    ),
  );
}

/// Consistent screen title row: circular back + title (+ optional subtitle).
class PaScreenHeader extends StatelessWidget {
  const PaScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
    this.onBack,
    this.titleStyle,
    this.subtitleStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = const EdgeInsets.fromLTRB(edgePad, 8, 16, contentGap),
  });

  /// Left inset matching the map overlay back chip.
  static const edgePad = 12.0;

  /// Space below the header before the next content (chips, list, etc.).
  static const contentGap = 12.0;

  /// Gap from circular back chip to title text.
  static const titleGap = 12.0;

  /// AppBar leading slot width: [edgePad] + 42 chip.
  static const appBarLeadingWidth = edgePad + 42;

  /// AppBar title gap matching [titleGap].
  static const appBarTitleSpacing = titleGap;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: AppColors.ink,
        );
    final resolvedSubtitleStyle = subtitleStyle ??
        const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (showBack) ...[
            PaBackButton(onPressed: onBack),
            const SizedBox(width: titleGap),
          ],
          Expanded(
            child: subtitle == null
                ? Text(title, style: resolvedTitleStyle)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: resolvedTitleStyle),
                      const SizedBox(height: 2),
                      Text(subtitle!, style: resolvedSubtitleStyle),
                    ],
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PaSectionCard extends StatelessWidget {
  const PaSectionCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
  }
}

class PaStatusPill extends StatelessWidget {
  const PaStatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.color = AppColors.teal,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PaEmptyState extends StatelessWidget {
  const PaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PaSectionCard(
      color: AppColors.sky.withValues(alpha: 0.12),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.teal),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Centered empty-state template for Visual Refresh screens.
///
/// Icon in an accent-tint circle, message, optional solid anchor CTA —
/// used by Trusted Guardians (per-child) and intended for EMP / similar.
class PaVrEmptyState extends StatelessWidget {
  const PaVrEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: VisualRefreshColors.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: VisualRefreshColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: VisualRefreshColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: VisualRefreshColors.anchor,
                    foregroundColor: VisualRefreshColors.background,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionIcon != null) ...[
                        Icon(actionIcon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
