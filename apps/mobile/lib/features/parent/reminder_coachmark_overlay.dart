import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Dimmed overlay with a speech-bubble tooltip anchored above the More tab.
class ReminderCoachmarkOverlay extends StatelessWidget {
  const ReminderCoachmarkOverlay({
    super.key,
    required this.onSkip,
    required this.onView,
    this.tabCount = 4,
    this.moreTabIndex = 3,
  });

  final VoidCallback onSkip;
  final VoidCallback onView;
  final int tabCount;
  final int moreTabIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final navHeight = 80.0 + padding.bottom;
    final tabWidth = size.width / tabCount;
    final spotlightCenterX = tabWidth * (moreTabIndex + 0.5);
    final spotlightRect = Rect.fromCenter(
      center: Offset(
        spotlightCenterX,
        size.height - navHeight / 2,
      ),
      width: tabWidth - 8,
      height: navHeight - padding.bottom - 12,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ScrimHolePainter(hole: spotlightRect),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: navHeight + 12,
            child: _CoachmarkBubble(
              title: l10n.reminderCoachmarkTitle,
              body: l10n.reminderCoachmarkBody,
              skipLabel: l10n.coachmarkSkip,
              viewLabel: l10n.coachmarkView,
              arrowCenterX: spotlightCenterX - 16,
              onSkip: onSkip,
              onView: onView,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachmarkBubble extends StatelessWidget {
  const _CoachmarkBubble({
    required this.title,
    required this.body,
    required this.skipLabel,
    required this.viewLabel,
    required this.arrowCenterX,
    required this.onSkip,
    required this.onView,
  });

  final String title;
  final String body;
  final String skipLabel;
  final String viewLabel;
  final double arrowCenterX;
  final VoidCallback onSkip;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: VisualRefreshColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.vrCard),
            border: Border.all(
              color: VisualRefreshColors.border,
              width: 0.5,
            ),
            boxShadow: const [VisualRefreshColors.popoverShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: VisualRefreshColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: VisualRefreshColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: VisualRefreshColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      skipLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onView,
                    style: FilledButton.styleFrom(
                      backgroundColor: VisualRefreshColors.anchor,
                      foregroundColor: VisualRefreshColors.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      viewLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(double.infinity, 10),
          painter: _BubbleArrowPainter(
            fill: VisualRefreshColors.surface,
            border: VisualRefreshColors.border,
            tipX: arrowCenterX.clamp(24.0, MediaQuery.sizeOf(context).width - 56),
          ),
        ),
      ],
    );
  }
}

class _ScrimHolePainter extends CustomPainter {
  _ScrimHolePainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(14)),
      );
    final path = Path.combine(PathOperation.difference, scrim, cutout);
    canvas.drawPath(
      path,
      Paint()..color = const Color(0x99141E19),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimHolePainter oldDelegate) =>
      oldDelegate.hole != hole;
}

class _BubbleArrowPainter extends CustomPainter {
  _BubbleArrowPainter({
    required this.fill,
    required this.border,
    required this.tipX,
  });

  final Color fill;
  final Color border;
  final double tipX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(tipX - 10, 0)
      ..lineTo(tipX, 10)
      ..lineTo(tipX + 10, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleArrowPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.tipX != tipX;
}
