import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../parent/vr_sheet_chrome.dart';

enum RemoveChildChoice { cancel, unlinkTemporary, deletePermanently }

/// Visual-refresh confirmation sheet for removing a child from the parent list.
Future<RemoveChildChoice> showRemoveChildSheet({
  required BuildContext context,
  required String childName,
}) async {
  final result = await showVrModalBottomSheet<RemoveChildChoice>(
    context: context,
    builder: (ctx) => RemoveChildSheet(childName: childName),
  );
  return result ?? RemoveChildChoice.cancel;
}

class RemoveChildSheet extends StatelessWidget {
  const RemoveChildSheet({super.key, required this.childName});

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
            icon: Icons.delete_outline_rounded,
            tint: VisualRefreshColors.danger.withValues(alpha: 0.12),
            iconColor: VisualRefreshColors.danger,
          ),
          const SizedBox(height: 18),
          VrSheetTitle(l10n.removeChildConfirmTitle(childName)),
          const SizedBox(height: 10),
          VrSheetBody(l10n.removeChildConfirmBody(childName)),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.pop(context, RemoveChildChoice.unlinkTemporary),
              style: OutlinedButton.styleFrom(
                foregroundColor: VisualRefreshColors.textPrimary,
                side: const BorderSide(
                  color: VisualRefreshColors.border,
                  width: 1,
                ),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l10n.unlinkChildTemporary,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () =>
                  Navigator.pop(context, RemoveChildChoice.deletePermanently),
              style: FilledButton.styleFrom(
                backgroundColor: VisualRefreshColors.danger,
                foregroundColor: VisualRefreshColors.background,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                l10n.deleteChildDataPermanently,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, RemoveChildChoice.cancel),
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
