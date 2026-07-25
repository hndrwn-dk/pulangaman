import 'package:url_launcher/url_launcher.dart';

/// Opens the device maps app for turn-by-turn directions to a point.
Future<bool> openMapsDirections({
  required double lat,
  required double lng,
  String? label,
}) async {
  final q = label == null || label.trim().isEmpty
      ? '$lat,$lng'
      : Uri.encodeComponent(label.trim());
  final candidates = [
    Uri.parse('google.navigation:q=$lat,$lng'),
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    Uri.parse('geo:$lat,$lng?q=$lat,$lng($q)'),
  ];
  for (final uri in candidates) {
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    } catch (_) {}
  }
  try {
    return await launchUrl(
      candidates[1],
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
