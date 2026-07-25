import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/open_maps.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';

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
      final pos = await Geolocator.getCurrentPosition();
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaScreenHeader(
              title: l10n.empAlertTitle,
              showBack: true,
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.empAlertBody(widget.placeName),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (widget.childNames != null &&
                        widget.childNames!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.childNames!.join(', '),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    if (widget.note != null && widget.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.note!,
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                    ],
                    if (widget.instructions != null &&
                        widget.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.instructions!,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      _loadingDistance
                          ? '...'
                          : (_distanceLabel == null
                              ? l10n.empDistanceUnknown
                              : l10n.empMyDistance(_distanceLabel!)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.tealDeep,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await openMapsDirections(
                          lat: widget.lat,
                          lng: widget.lng,
                          label: widget.placeName,
                        );
                      },
                      child: Text(l10n.empOpenMaps),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
