import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Play-compliance disclosure shown before the OS "Allow all the time" dialog.
/// Returns `true` if the user taps continue.
Future<bool> showBackgroundLocationDisclosure(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const BackgroundLocationDisclosureScreen(),
    ),
  );
  return result == true;
}

class BackgroundLocationDisclosureScreen extends StatelessWidget {
  const BackgroundLocationDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final bg =
        refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5);
    final titleStyle = refresh
        ? GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: VisualRefreshColors.textPrimary,
            height: 1.25,
          )
        : const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.25,
          );
    final bodyColor =
        refresh ? VisualRefreshColors.textSecondary : AppColors.inkSoft;
    final buttonBg =
        refresh ? VisualRefreshColors.anchor : AppColors.teal;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: refresh
                        ? VisualRefreshColors.accentTint
                        : AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: refresh
                        ? VisualRefreshColors.accent
                        : AppColors.teal,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.bgLocationDisclosureTitle, style: titleStyle),
              const SizedBox(height: 14),
              Text(
                l10n.bgLocationDisclosureBody,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: bodyColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l10n.bgLocationDisclosureContinue,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
