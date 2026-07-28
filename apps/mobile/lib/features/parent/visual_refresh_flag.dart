import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../child/reminder_channel.dart';

/// Visual Refresh is always on — the sole UI look for parent/child.
///
/// Kept as a [Provider] so call sites and native sync stay stable; there is
/// no user toggle or `--dart-define=VISUAL_REFRESH` override.
final visualRefreshEnabledProvider = Provider<bool>((ref) {
  // Fire once per container: keep Android reminder templates on VR.
  unawaited(_syncNativeVisualRefresh());
  return true;
});

Future<void> _syncNativeVisualRefresh() async {
  try {
    await ReminderChannel().setVisualRefresh(true);
  } catch (_) {
    // Native channel unavailable (tests / non-Android) — ignore.
  }
}
