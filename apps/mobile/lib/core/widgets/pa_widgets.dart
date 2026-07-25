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
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: elevation,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: iconColor ?? AppColors.ink),
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
    this.padding = const EdgeInsets.fromLTRB(edgePad, 8, 16, 0),
  });

  /// Left inset matching the map overlay back chip.
  static const edgePad = 12.0;

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
