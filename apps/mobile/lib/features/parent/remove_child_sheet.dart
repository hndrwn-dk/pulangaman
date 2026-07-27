import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'vr_sheet_chrome.dart';

/// Visual-refresh confirmation sheet for removing a child from the parent list.
Future<bool> showRemoveChildSheet({
  required BuildContext context,
  required String childName,
}) async {
  final result = await showVrModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => RemoveChildSheet(childName: childName),
  );
  return result == true;
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
          VrSheetDualActions(
            secondaryLabel: l10n.cancel,
            primaryLabel: l10n.delete,
            primaryDestructive: true,
            onSecondary: () => Navigator.pop(context, false),
            onPrimary: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
