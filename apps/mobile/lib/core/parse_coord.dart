/// Parse lat/lng that may arrive as num or String (WS/FCM payloads).
double? parseCoord(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
