import 'package:flutter/services.dart';

class LocationTrackingChannel {
  static const _channel =
      MethodChannel('com.tursinalabs.pulangaman/location_tracking');

  Future<void> start({
    required String token,
    required String apiBaseUrl,
    bool panic = false,
  }) async {
    await _channel.invokeMethod<bool>('startLocationTracking', {
      'token': token,
      'apiBaseUrl': apiBaseUrl,
      'panic': panic,
    });
  }

  Future<void> update({
    String? token,
    String? apiBaseUrl,
    bool panic = false,
  }) async {
    await _channel.invokeMethod<bool>('updateLocationTracking', {
      if (token != null) 'token': token,
      if (apiBaseUrl != null) 'apiBaseUrl': apiBaseUrl,
      'panic': panic,
    });
  }

  Future<void> stop() async {
    await _channel.invokeMethod<bool>('stopLocationTracking');
  }

  Future<bool> isRunning() async {
    final running = await _channel.invokeMethod<bool>('isLocationTrackingRunning');
    return running == true;
  }
}
