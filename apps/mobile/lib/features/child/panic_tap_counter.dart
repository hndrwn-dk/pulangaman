/// Tracks triple-tap panic gesture with idle reset and post-trigger cooldown.
class PanicTapCounter {
  PanicTapCounter({
    this.idleReset = const Duration(seconds: 3),
    this.cooldown = const Duration(seconds: 60),
  });

  final Duration idleReset;
  final Duration cooldown;

  int taps = 0;
  DateTime? lastTapAt;
  DateTime? cooldownUntil;

  bool isOnCooldownAt(DateTime clock) {
    final until = cooldownUntil;
    return until != null && clock.isBefore(until);
  }

  bool get isOnCooldown => isOnCooldownAt(DateTime.now());

  /// Returns tap count (1-2) while counting, 0 on cooldown, -1 when trigger fires.
  int registerTap([DateTime? now]) {
    final clock = now ?? DateTime.now();
    if (isOnCooldownAt(clock)) {
      return 0;
    }
    if (lastTapAt == null || clock.difference(lastTapAt!) > idleReset) {
      taps = 0;
    }
    lastTapAt = clock;
    taps += 1;
    if (taps >= 3) {
      taps = 0;
      lastTapAt = null;
      return -1;
    }
    return taps;
  }

  void markTriggered([DateTime? now]) {
    taps = 0;
    lastTapAt = null;
    cooldownUntil = (now ?? DateTime.now()).add(cooldown);
  }

  void reset() {
    taps = 0;
    lastTapAt = null;
    cooldownUntil = null;
  }
}
