import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/core/day_period.dart';

void main() {
  test('dayPeriodFor maps morning midday afternoon night bands', () {
    expect(dayPeriodFor(DateTime(2026, 7, 26, 7)), DayPeriod.morning);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 12)), DayPeriod.midday);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 16)), DayPeriod.afternoon);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 21)), DayPeriod.night);
  });

  test('each period exposes a distinct greeting and icon', () {
    final greetings = DayPeriod.values.map((p) => p.greetingId).toSet();
    final icons = DayPeriod.values.map((p) => p.icon).toSet();
    expect(greetings.length, DayPeriod.values.length);
    expect(icons.length, DayPeriod.values.length);
  });
}
