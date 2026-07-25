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

  Future<void> previewNow({
    required String title,
    required String body,
    String style = 'fullscreen',
  }) async {
    await _channel.invokeMethod<void>('previewNow', {
      'title': title,
      'body': body,
      'style': style,
    });
  }

  /// Closes the native ReminderFullScreenActivity if it is on screen
  /// (e.g. parent turned off an emergency meeting point).
  Future<void> dismissFullScreen() async {
    await _channel.invokeMethod<void>('dismissFullScreen');
  }
}
