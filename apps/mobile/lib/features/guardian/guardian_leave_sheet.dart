import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../parent/vr_sheet_chrome.dart';

enum GuardianLeaveChoice { cancel, leaveNow, requestParent }

Future<GuardianLeaveChoice> showGuardianLeaveSheet({
  required BuildContext context,
  required String childName,
}) async {
  final result = await showVrModalBottomSheet<GuardianLeaveChoice>(
    context: context,
    builder: (ctx) => GuardianLeaveSheet(childName: childName),
  );
  return result ?? GuardianLeaveChoice.cancel;
}

class GuardianLeaveSheet extends StatelessWidget {
  const GuardianLeaveSheet({super.key, required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return VrSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VrSheetIconTile(
            icon: Icons.person_off_outlined,
            tint: VisualRefreshColors.danger.withValues(alpha: 0.12),
            iconColor: VisualRefreshColors.danger,
          ),
          const SizedBox(height: 18),
          VrSheetTitle(l10n.guardianLeaveSheetTitle),
          const SizedBox(height: 10),
          VrSheetBody(childName),
          const SizedBox(height: 24),
          _LeaveOptionButton(
            label: l10n.guardianLeaveNowLabel,
            subtitle: l10n.guardianLeaveNowSubtitle,
            destructive: true,
            onPressed: () =>
                Navigator.pop(context, GuardianLeaveChoice.leaveNow),
          ),
          const SizedBox(height: 10),
          _LeaveOptionButton(
            label: l10n.guardianRequestParentLabel,
            subtitle: l10n.guardianRequestParentSubtitle,
            destructive: false,
            onPressed: () =>
                Navigator.pop(context, GuardianLeaveChoice.requestParent),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, GuardianLeaveChoice.cancel),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: VisualRefreshColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveOptionButton extends StatelessWidget {
  const _LeaveOptionButton({
    required this.label,
    required this.subtitle,
    required this.destructive,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? VisualRefreshColors.danger
        : VisualRefreshColors.warmTint;
    final fg = destructive
        ? VisualRefreshColors.background
        : VisualRefreshColors.textPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  height: 1.35,
                  color: destructive
                      ? VisualRefreshColors.background.withValues(alpha: 0.85)
                      : VisualRefreshColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
