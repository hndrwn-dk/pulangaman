import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/features/child/child_usage_utils.dart';
import 'package:pulangaman/l10n/app_localizations_id.dart';

void main() {
  final l10n = AppLocalizationsId();

  group('formatDuration', () {
    test('returns minutes for short durations', () {
      expect(formatDuration(l10n, 0), '0 mnt');
      expect(formatDuration(l10n, 90), '1 mnt');
      expect(formatDuration(l10n, 3599), '59 mnt');
    });

    test('returns hours and minutes for long durations', () {
      expect(formatDuration(l10n, 3600), '1 jam 0 mnt');
      expect(formatDuration(l10n, 3660), '1 jam 1 mnt');
    });
  });

  group('formatDurationCompact', () {
    test('uses short units for ring display', () {
      expect(formatDurationCompact(0), '0m');
      expect(formatDurationCompact(90), '1m');
      expect(formatDurationCompact(3660), '1j 1m');
    });
  });

  group('friendlyAppName', () {
    test('maps known packages', () {
      expect(
        friendlyAppName('com.google.android.youtube'),
        'YouTube',
      );
      expect(
        friendlyAppName('com.tursinalabs.pulangaman'),
        'PulangAman',
      );
    });

    test('prefers native app label when provided', () {
      expect(
        friendlyAppName('com.example.myapp', appLabel: 'My Game'),
        'My Game',
      );
    });

    test('derives title case from package suffix', () {
      expect(friendlyAppName('com.example.myapp'), 'Myapp');
    });
  });

  group('UsageAppEntry', () {
    test('parses json', () {
      final entry = UsageAppEntry.fromJson({
        'packageName': 'com.test.app',
        'durationSeconds': 120,
        'appLabel': 'Test',
      });
      expect(entry.packageName, 'com.test.app');
      expect(entry.durationSeconds, 120);
      expect(entry.appLabel, 'Test');
    });
  });
}
