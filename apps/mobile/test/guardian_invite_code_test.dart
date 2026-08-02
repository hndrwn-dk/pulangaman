import 'package:flutter_test/flutter_test.dart';

import 'package:pulangaman/features/guardian/guardian_account_screen.dart';

void main() {
  test('normalizeGuardianInviteCode strips spaces and punctuation', () {
    expect(normalizeGuardianInviteCode('XE6 RJ7'), 'XE6RJ7');
    expect(normalizeGuardianInviteCode('xe6-rj7'), 'XE6RJ7');
    expect(normalizeGuardianInviteCode('  XE6RJ7  '), 'XE6RJ7');
  });
}
