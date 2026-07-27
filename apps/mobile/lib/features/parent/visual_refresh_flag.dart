import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/storage/session_store.dart';
import '../child/reminder_channel.dart';

/// Whether Visual Refresh (Approach A) tokens are active for parent/child UI.
///
/// Resolution order:
/// 1. Runtime preference in [SessionStore] (parent Account toggle), if set
/// 2. Compile-time `--dart-define=VISUAL_REFRESH=true` ([AppConfig.visualRefresh])
///
/// Default is **off** (classic theme). Preference wins over dart-define when set.
/// Child devices typically rely on the dart-define (no Account toggle).
final visualRefreshEnabledProvider =
    StateNotifierProvider<VisualRefreshController, bool>((ref) {
  return VisualRefreshController(
    store: ref.watch(sessionStoreProvider),
    compileTimeDefault: AppConfig.visualRefresh,
  );
});

class VisualRefreshController extends StateNotifier<bool> {
  VisualRefreshController({
    required SessionStore store,
    required bool compileTimeDefault,
  })  : _store = store,
        _compileTimeDefault = compileTimeDefault,
        super(compileTimeDefault) {
    unawaited(init());
  }

  final SessionStore _store;
  final bool _compileTimeDefault;
  bool _locked = false;
  final ReminderChannel _reminderChannel = ReminderChannel();

  Future<void> init() async {
    final saved = await _store.visualRefresh();
    if (_locked) return;
    state = saved ?? _compileTimeDefault;
    await _syncNative(state);
  }

  Future<void> setEnabled(bool enabled) async {
    _locked = true;
    state = enabled;
    await _store.saveVisualRefresh(enabled);
    await _syncNative(enabled);
  }

  Future<void> _syncNative(bool enabled) async {
    try {
      await _reminderChannel.setVisualRefresh(enabled);
    } catch (_) {
      // Native channel unavailable (tests / non-Android) — ignore.
    }
  }
}
