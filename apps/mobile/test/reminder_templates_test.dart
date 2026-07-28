import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/features/reminders/reminder_templates.dart';
import 'package:pulangaman/l10n/app_localizations_en.dart';
import 'package:pulangaman/l10n/app_localizations_id.dart';

void main() {
  final id = AppLocalizationsId();
  final en = AppLocalizationsEn();

  group('ReminderTemplates.resolveKey', () {
    test('uses API templateKey when present', () {
      expect(
        ReminderTemplates.resolveKey(
          templateKey: 'study',
          title: 'Custom text',
        ),
        ReminderTemplateKeys.study,
      );
      expect(
        ReminderTemplates.resolveKey(
          templateKey: 'bedtime',
          title: 'Anything',
        ),
        ReminderTemplateKeys.bedtime,
      );
    });

    test('infers from known ID/EN titles', () {
      expect(
        ReminderTemplates.resolveKey(title: 'Waktunya Belajar'),
        ReminderTemplateKeys.study,
      );
      expect(
        ReminderTemplates.resolveKey(title: 'Study Time'),
        ReminderTemplateKeys.study,
      );
      expect(
        ReminderTemplates.resolveKey(title: 'Waktunya Tidur'),
        ReminderTemplateKeys.bedtime,
      );
      expect(
        ReminderTemplates.resolveKey(title: 'Bedtime'),
        ReminderTemplateKeys.bedtime,
      );
    });

    test('does not classify arbitrary custom titles', () {
      expect(
        ReminderTemplates.resolveKey(title: 'Jangan lupa belajar'),
        isNull,
      );
      expect(
        ReminderTemplates.resolveKey(title: 'Minum obat'),
        isNull,
      );
    });
  });

  group('ReminderTemplates.display', () {
    test('localizes study/bedtime from key', () {
      expect(
        ReminderTemplates.displayTitle(
          en,
          templateKey: 'study',
          title: 'Waktunya Belajar',
        ),
        en.reminderStudyPresetTitle,
      );
      expect(
        ReminderTemplates.displayBody(
          id,
          templateKey: 'bedtime',
          title: 'Bedtime',
          body: 'old',
        ),
        id.reminderSleepPresetBody,
      );
    });

    test('keeps custom title/body', () {
      expect(
        ReminderTemplates.displayTitle(
          en,
          title: 'Drink water',
        ),
        'Drink water',
      );
      expect(
        ReminderTemplates.displayBody(
          en,
          title: 'Drink water',
          body: 'Stay hydrated',
        ),
        'Stay hydrated',
      );
    });
  });
}
