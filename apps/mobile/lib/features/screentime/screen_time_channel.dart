import 'package:flutter/services.dart';

class ScreenTimeChannel {
  static const _channel = MethodChannel('com.tursinalabs.pulangaman/screen_time');

  Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  Future<void> openUsageAccessSettings() => _channel.invokeMethod('openUsageAccessSettings');

  Future<void> openAccessibilitySettings() => _channel.invokeMethod('openAccessibilitySettings');

  Future<List<Map<String, dynamic>>> getTodayUsage() async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getTodayUsage');
    return (result ?? [])
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Future<void> applyPolicy(Map<String, dynamic> policy) {
    return _channel.invokeMethod('applyPolicy', policy);
  }

  Future<void> startEnforcement() => _channel.invokeMethod('startEnforcement');
}
