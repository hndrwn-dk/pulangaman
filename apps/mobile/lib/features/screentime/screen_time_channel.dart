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

  /// App info page — needed to lift Android 13+ "restricted settings"
  /// before the accessibility toggle can be turned on (sideloaded installs).
  Future<void> openAppInfoSettings() => _channel.invokeMethod('openAppInfoSettings');

  Future<List<Map<String, dynamic>>> getTodayUsage() async {
    return getUsageStats('today');
  }

  Future<List<Map<String, dynamic>>> getUsageStats(String period) async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'getUsageStats',
      {'period': period},
    );
    return (result ?? [])
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  /// Hour-bucketed foreground usage for peak-hour insights (last [days] days).
  Future<List<Map<String, dynamic>>> getHourlyUsage({int days = 7}) async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'getHourlyUsage',
      {'days': days},
    );
    return (result ?? [])
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Future<void> applyPolicy(Map<String, dynamic> policy) {
    return _channel.invokeMethod('applyPolicy', policy);
  }

  Future<void> startEnforcement() => _channel.invokeMethod('startEnforcement');
}
