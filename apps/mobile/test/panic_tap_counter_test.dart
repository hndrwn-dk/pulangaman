import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/features/child/panic_tap_counter.dart';

void main() {
  test('counts three taps within idle window', () {
    final counter = PanicTapCounter(idleReset: const Duration(seconds: 3));
    final t0 = DateTime(2026, 7, 20, 12, 0, 0);

    expect(counter.registerTap(t0), 1);
    expect(counter.registerTap(t0.add(const Duration(seconds: 1))), 2);
    expect(counter.registerTap(t0.add(const Duration(seconds: 2))), -1);
  });

  test('resets after idle gap', () {
    final counter = PanicTapCounter(idleReset: const Duration(seconds: 3));
    final t0 = DateTime(2026, 7, 20, 12, 0, 0);

    expect(counter.registerTap(t0), 1);
    expect(counter.registerTap(t0.add(const Duration(seconds: 4))), 1);
    expect(counter.registerTap(t0.add(const Duration(seconds: 5))), 2);
  });

  test('cooldown blocks further triggers', () {
    final counter = PanicTapCounter(
      idleReset: const Duration(seconds: 3),
      cooldown: const Duration(seconds: 60),
    );
    final t0 = DateTime(2026, 7, 20, 12, 0, 0);

    expect(counter.registerTap(t0), 1);
    expect(counter.registerTap(t0.add(const Duration(seconds: 1))), 2);
    expect(counter.registerTap(t0.add(const Duration(seconds: 2))), -1);
    counter.markTriggered(t0);
    expect(counter.registerTap(t0.add(const Duration(seconds: 5))), 0);
    expect(counter.registerTap(t0.add(const Duration(seconds: 10))), 0);
  });
}
