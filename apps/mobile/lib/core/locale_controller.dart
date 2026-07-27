import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'storage/session_store.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController(store: ref.watch(sessionStoreProvider));
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController({
    required SessionStore store,
    Locale? deviceLocale,
  })  : _store = store,
        _deviceLocale = deviceLocale,
        super(const Locale('id')) {
    unawaited(init());
  }

  final SessionStore _store;
  final Locale? _deviceLocale;

  /// Set when the user (or a test) picks a locale so a late [init] cannot
  /// overwrite it with a stale storage/device value.
  bool _locked = false;

  Future<void> init() async {
    final saved = await _store.locale();
    if (_locked) return;
    if (saved != null && _isSupported(saved)) {
      state = Locale(saved);
      return;
    }
    if (_locked) return;
    final deviceCode =
        (_deviceLocale ?? PlatformDispatcher.instance.locale).languageCode;
    state = _isSupported(deviceCode) ? Locale(deviceCode) : const Locale('id');
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) return;
    _locked = true;
    state = Locale(locale.languageCode);
    await _store.saveLocale(locale.languageCode);
  }

  bool _isSupported(String languageCode) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == languageCode);
}
