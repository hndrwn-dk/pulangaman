import 'package:flutter/services.dart';

class ReminderChannel {
  static const _channel = MethodChannel('com.tursinalabs.pulangaman/reminders');

  Future<void> syncReminders(List<Map<String, dynamic>> reminders) async {
    await _channel.invokeMethod<void>('syncReminders', reminders);
  }

  Future<bool> canScheduleExactAlarms() async {
    final ok = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    return ok == true;
  }

  Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod<void>('openExactAlarmSettings');
  }

  Future<void> openFullScreenIntentSettings() async {
    await _channel.invokeMethod<void>('openFullScreenIntentSettings');
  }

  /// Mirrors Flutter Visual Refresh onto Android SharedPreferences so
  /// [ReminderFullScreenActivity] can style scheduled alarms correctly.
  Future<void> setVisualRefresh(bool enabled) async {
    await _channel.invokeMethod<void>('setVisualRefresh', {'enabled': enabled});
  }

  /// Persist Flutter app locale for native fullscreen reminder chrome (CTA).
  Future<void> setAppLocale(String languageCode) async {
    await _channel.invokeMethod<void>('setAppLocale', {
      'languageCode': languageCode,
    });
  }

  Future<void> previewNow({
    required String title,
    required String body,
    String style = 'fullscreen',
    bool? visualRefresh,
    String? mood,
    String? accent,
  }) async {
    await _channel.invokeMethod<void>('previewNow', {
      'title': title,
      'body': body,
      'style': style,
      if (visualRefresh != null) 'visualRefresh': visualRefresh,
      if (mood != null) 'mood': mood,
      if (accent != null) 'accent': accent,
    });
  }

  /// Closes the native ReminderFullScreenActivity if it is on screen
  /// (e.g. parent turned off an emergency meeting point).
  Future<void> dismissFullScreen() async {
    await _channel.invokeMethod<void>('dismissFullScreen');
  }
}
