import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/core/day_period.dart';
import 'package:pulangaman/l10n/app_localizations_id.dart';

void main() {
  test('dayPeriodFor maps morning midday afternoon night bands', () {
    expect(dayPeriodFor(DateTime(2026, 7, 26, 7)), DayPeriod.morning);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 12)), DayPeriod.midday);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 16)), DayPeriod.afternoon);
    expect(dayPeriodFor(DateTime(2026, 7, 26, 21)), DayPeriod.night);
  });

  test('each period exposes a distinct greeting and icon', () {
    final l10n = AppLocalizationsId();
    final greetings = DayPeriod.values.map((p) => p.greeting(l10n)).toSet();
    final icons = DayPeriod.values.map((p) => p.icon).toSet();
    expect(greetings.length, DayPeriod.values.length);
    expect(icons.length, DayPeriod.values.length);
  });
}
