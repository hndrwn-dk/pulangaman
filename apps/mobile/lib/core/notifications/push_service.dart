import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';

/// Must be a top-level/static function — FCM runs this in a separate isolate.
/// Registered once from [main] before [runApp] (not again in [PushService.init]).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the payload already includes a `notification` block, so Android
  // auto-displays it from the system tray while backgrounded/killed.
  // This handler just needs to exist so the plugin's isolate is registered
  // and `data` is available via getInitialMessage() when the user taps it.
}

class PushService {
  PushService(this._apiClient);

  final ApiClient _apiClient;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'parent_alerts',
    'Peringatan akun & keamanan',
    description:
        'Notifikasi perangkat baru, ringkasan mingguan, dan peringatan lain.',
    importance: Importance.high,
  );

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static PushService? _active;
  static void Function(Map<String, dynamic> data)? _onTapPayload;

  Future<void> init({
    required void Function(Map<String, dynamic> data) onTapPayload,
  }) async {
    _onTapPayload = onTapPayload;
    await FirebaseMessaging.instance.requestPermission();
    // Background handler is registered in main.dart only — FCM requires a
    // single early registration before runApp.

    if (!_initialized) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (resp) {
          // Local notifications we show ourselves while foregrounded.
          final raw = resp.payload;
          if (raw == null || raw.isEmpty) return;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              _onTapPayload?.call(decoded);
            } else if (decoded is Map) {
              _onTapPayload?.call(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {
            // Ignore malformed local payloads.
          }
        },
      );

      // Foreground: FCM does NOT auto-show notification-type messages, so
      // display one manually.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        final payload =
            message.data.isEmpty ? null : jsonEncode(message.data);
        unawaited(
          _localNotifications.show(
            id: message.hashCode,
            title: n.title,
            body: n.body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'parent_alerts',
                'Peringatan akun & keamanan',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            payload: payload,
          ),
        );
      });

      // Tap while backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _onTapPayload?.call(message.data);
      });

      _initialized = true;
    }

    // Cold start via tap (app was killed).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) onTapPayload(initial.data);
  }

  Future<void> registerToken() async {
    _active = this;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _postToken(token);

    // Single process-wide refresh listener; cancel/replace on re-login.
    _tokenRefreshSub ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
      unawaited(_active?._postToken(refreshed) ?? Future<void>.value());
    });
  }

  Future<void> _postToken(String token) {
    return _apiClient.post('/api/v1/devices', body: {
      'fcmToken': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    });
  }
}
