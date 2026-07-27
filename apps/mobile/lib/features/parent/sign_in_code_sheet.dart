import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'vr_sheet_chrome.dart';

/// Visual-refresh bottom sheet for a newly created invite / relink code.
Future<void> showSignInCodeSheet({
  required BuildContext context,
  required String childName,
  required String code,
  DateTime? expiresAt,
}) {
  return showVrModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SignInCodeSheet(
      childName: childName,
      code: code,
      expiresAt: expiresAt,
    ),
  );
}

class SignInCodeSheet extends StatelessWidget {
  const SignInCodeSheet({
    super.key,
    required this.childName,
    required this.code,
    this.expiresAt,
  });

  final String childName;
  final String code;
  final DateTime? expiresAt;

  static String formatSpacedCode(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleaned.length <= 3) return cleaned;
    final mid = (cleaned.length / 2).ceil();
    return '${cleaned.substring(0, mid)} ${cleaned.substring(mid)}';
  }

  static String expiryLabel(AppLocalizations l10n, DateTime? expiresAt) {
    if (expiresAt == null) return l10n.codeValid24Hours;
    final hours = expiresAt.difference(DateTime.now()).inHours;
    if (hours <= 0 || (hours >= 20 && hours <= 24)) {
      return l10n.codeValid24Hours;
    }
    return l10n.codeValidForHours(hours.clamp(1, 168));
  }

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: code.trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.codeCopiedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spaced = formatSpacedCode(code);

    return VrSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VrSheetIconTile(
            icon: Icons.link_rounded,
            tint: VisualRefreshColors.accentTint,
            iconColor: VisualRefreshColors.accent,
          ),
          const SizedBox(height: 18),
          VrSheetTitle(l10n.newSignInCodeTitle(childName)),
          const SizedBox(height: 10),
          VrSheetBody(l10n.newSignInCodeBody(childName)),
          const SizedBox(height: 22),
          CustomPaint(
            painter: _DashedRRectPainter(
              color: VisualRefreshColors.dashedDisplay,
              radius: 16,
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: VisualRefreshColors.warmTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                spaced,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: VisualRefreshColors.anchor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            expiryLabel(l10n, expiresAt),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: VisualRefreshColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          VrSheetDualActions(
            secondaryLabel: l10n.copyCodeAction,
            primaryLabel: l10n.doneAction,
            onSecondary: () => _copy(context),
            onPrimary: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
