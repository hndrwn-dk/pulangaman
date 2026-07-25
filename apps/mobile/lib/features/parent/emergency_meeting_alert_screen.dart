import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/open_maps.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen EMP alert — same visual language as [ReminderFullScreenActivity]
/// (teal canvas, PULANGAMAN eyebrow, amber primary action).
class EmergencyMeetingAlertScreen extends StatefulWidget {
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
  State<EmergencyMeetingAlertScreen> createState() =>
      _EmergencyMeetingAlertScreenState();
}

class _EmergencyMeetingAlertScreenState
    extends State<EmergencyMeetingAlertScreen> {
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
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
