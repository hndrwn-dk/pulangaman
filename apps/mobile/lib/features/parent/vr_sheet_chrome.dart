import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

/// Shared modal presentation for visual-refresh bottom sheets.
Future<T?> showVrModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: VisualRefreshColors.anchor.withValues(alpha: 0.45),
    builder: builder,
  );
}

/// Soft cream/white sheet with rounded top — chrome shared by VR sheets.
class VrSheetShell extends StatelessWidget {
  const VrSheetShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: VisualRefreshColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [VisualRefreshColors.dialogShadow],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: child,
      ),
    );
  }
}

/// Centered drag handle for list / picker VR sheets.
class VrSheetDragHandle extends StatelessWidget {
  const VrSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VisualRefreshColors.tagMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class VrSheetIconTile extends StatelessWidget {
  const VrSheetIconTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class VrSheetTitle extends StatelessWidget {
  const VrSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 1.25,
        color: VisualRefreshColors.textPrimary,
      ),
    );
  }
}

class VrSheetBody extends StatelessWidget {
  const VrSheetBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: VisualRefreshColors.textSecondary,
      ),
    );
  }
}

class VrSheetDualActions extends StatelessWidget {
  const VrSheetDualActions({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.primaryDestructive = false,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final bool primaryDestructive;

  @override
  Widget build(BuildContext context) {
    final primaryBg = primaryDestructive
        ? VisualRefreshColors.danger
        : VisualRefreshColors.anchor;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onSecondary,
              style: FilledButton.styleFrom(
                backgroundColor: VisualRefreshColors.warmTint,
                foregroundColor: VisualRefreshColors.textPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                secondaryLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: primaryBg,
                foregroundColor: VisualRefreshColors.background,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                primaryLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
