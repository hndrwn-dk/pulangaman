import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/push_service.dart';
import 'features/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  // Shared container so App Check tokens land on the same ApiClient the app uses.
  final container = ProviderContainer();
  final apiClient = container.read(apiClientProvider);
  FirebaseAppCheck.instance.onTokenChange.listen(apiClient.setAppCheckToken);
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    apiClient.setAppCheckToken(token);
  } catch (_) {
    // Monitor-first: missing/invalid tokens are logged server-side until enforce.
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PulangAmanApp(),
    ),
  );
}
