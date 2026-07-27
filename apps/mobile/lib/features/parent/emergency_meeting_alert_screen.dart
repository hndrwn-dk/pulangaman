import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/open_maps.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'visual_refresh_flag.dart';

/// Full-screen EMP alert — same visual language as [ReminderFullScreenActivity]
/// (teal canvas, PULANGAMAN eyebrow, amber primary action).
///
/// When Visual Refresh is on: dark-teal moment template with terracotta accent,
/// pin/radar illustration, X close, Fraunces title.
class EmergencyMeetingAlertScreen extends ConsumerStatefulWidget {
  const EmergencyMeetingAlertScreen({
    super.key,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.instructions,
    this.note,
    this.childNames,
  });

  final String placeName;
  final double lat;
  final double lng;
  final String? instructions;
  final String? note;
  final List<String>? childNames;

  @override
  ConsumerState<EmergencyMeetingAlertScreen> createState() =>
      _EmergencyMeetingAlertScreenState();
}

class _EmergencyMeetingAlertScreenState
    extends ConsumerState<EmergencyMeetingAlertScreen> {
  String? _distanceLabel;
  bool _loadingDistance = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDistance);
  }

  Future<void> _loadDistance() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      // A hanging GPS fix must not leave the distance line stuck on "...".
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final m = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.lat,
        widget.lng,
      );
      if (!mounted) return;
      setState(() {
        _distanceLabel =
            m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';
        _loadingDistance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDistance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refresh = ref.watch(visualRefreshEnabledProvider);
    if (refresh) return _buildVisualRefresh(context);
    return _buildClassic(context);
  }

  Widget _buildVisualRefresh(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final note = widget.note?.trim() ?? '';
    final instructions = widget.instructions?.trim() ?? '';
    final names = widget.childNames ?? const <String>[];
    final distanceText = _loadingDistance
        ? '...'
        : (_distanceLabel == null
            ? l10n.empDistanceUnknown
            : l10n.empMyDistance(_distanceLabel!));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ReminderMomentColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'PULANGAMAN',
                      style: GoogleFonts.plusJakartaSans(
                        color: ReminderMomentColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                      color: ReminderMomentColors.closeIcon,
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.empAlertTitle,
                  style: GoogleFonts.fraunces(
                    color: ReminderMomentColors.title,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.empAlertBody(widget.placeName),
                  style: GoogleFonts.plusJakartaSans(
                    color: ReminderMomentColors.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    names.join(', '),
                    style: GoogleFonts.plusJakartaSans(
                      color: ReminderMomentColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      color: ReminderMomentColors.mutedText,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    instructions,
                    style: GoogleFonts.plusJakartaSans(
                      color: ReminderMomentColors.mutedText.withValues(
                        alpha: 0.9,
                      ),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  distanceText,
                  style: GoogleFonts.plusJakartaSans(
                    color: ReminderMomentColors.empAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(
                        painter: _EmpRadarPainter(
                          accent: ReminderMomentColors.empAccent,
                          disc: ReminderMomentColors.illustrationBg,
                          shadow: ReminderMomentColors.background,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ReminderMomentColors.empAccent,
                      foregroundColor: ReminderMomentColors.onAccent,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      await openMapsDirections(
                        lat: widget.lat,
                        lng: widget.lng,
                        label: widget.placeName,
                      );
                    },
                    child: Text(
                      l10n.empOpenMaps,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: ReminderMomentColors.mutedText,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    l10n.understood,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassic(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final note = widget.note?.trim() ?? '';
    final instructions = widget.instructions?.trim() ?? '';
    final names = widget.childNames ?? const <String>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.tealDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white.withValues(alpha: 0.9),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                const Text(
                  'PULANGAMAN',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.empAlertTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.empAlertBody(widget.placeName),
                  style: const TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    names.join(', '),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF),
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                ],
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    instructions,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _loadingDistance
                      ? '...'
                      : (_distanceLabel == null
                          ? l10n.empDistanceUnknown
                          : l10n.empMyDistance(_distanceLabel!)),
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: const Color(0xFF18332D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await openMapsDirections(
                        lat: widget.lat,
                        lng: widget.lng,
                        label: widget.placeName,
                      );
                    },
                    child: Text(
                      l10n.empOpenMaps,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.85),
                  ),
                  child: Text(
                    l10n.understood,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpRadarPainter extends CustomPainter {
  _EmpRadarPainter({
    required this.accent,
    required this.disc,
    required this.shadow,
  });

  final Color accent;
  final Color disc;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.42;

    final soft = Paint()
      ..color = disc.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 1.15, soft);

    final ring = Paint()
      ..color = ReminderMomentColors.mutedText.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(cx, cy), r * 0.95, ring);
    canvas.drawCircle(Offset(cx, cy), r * 0.72, ring);
    canvas.drawCircle(Offset(cx, cy), r * 0.48, ring);

    final base = Paint()..color = shadow.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.55),
        width: r * 0.9,
        height: r * 0.28,
      ),
      base,
    );

    final pin = Paint()..color = accent;
    final path = Path()
      ..moveTo(cx, cy - r * 0.55)
      ..cubicTo(
        cx + r * 0.42,
        cy - r * 0.55,
        cx + r * 0.42,
        cy + r * 0.05,
        cx,
        cy + r * 0.42,
      )
      ..cubicTo(
        cx - r * 0.42,
        cy + r * 0.05,
        cx - r * 0.42,
        cy - r * 0.55,
        cx,
        cy - r * 0.55,
      )
      ..close();
    canvas.drawPath(path, pin);

    final hole = Paint()..color = ReminderMomentColors.background;
    canvas.drawCircle(Offset(cx, cy - r * 0.18), r * 0.14, hole);
  }

  @override
  bool shouldRepaint(covariant _EmpRadarPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.disc != disc ||
      oldDelegate.shadow != shadow;
}
