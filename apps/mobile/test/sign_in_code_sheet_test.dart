import 'package:flutter_test/flutter_test.dart';

import 'package:pulangaman/features/parent/sign_in_code_sheet.dart';
import 'package:pulangaman/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('expiryLabel shows minutes when under one hour', () {
    final expiresAt = DateTime.now().add(const Duration(minutes: 30, seconds: 5));
    final label = SignInCodeSheet.expiryLabel(l10n, expiresAt);
    expect(label, l10n.codeValidForMinutes(30));
  });

  test('expiryLabel shows expired when past', () {
    final expiresAt = DateTime.now().subtract(const Duration(minutes: 1));
    expect(SignInCodeSheet.expiryLabel(l10n, expiresAt), l10n.codeExpired);
  });

  test('expiryLabel falls back to 24h when expiresAt is null', () {
    expect(SignInCodeSheet.expiryLabel(l10n, null), l10n.codeValid24Hours);
  });

  test('formatDisplayCode uppercases and strips spaces', () {
    expect(SignInCodeSheet.formatDisplayCode('ab 12 cd'), 'AB12CD');
  });
}
