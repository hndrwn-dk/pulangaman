import '../../l10n/app_localizations.dart';

/// Stable ids for parent quick-add schedules (Study / Bedtime).
/// Stored on the API so UI and child alarms can re-localize without
/// depending on whichever language was active at create time.
abstract final class ReminderTemplateKeys {
  static const study = 'study';
  static const bedtime = 'bedtime';

  static const all = <String>{study, bedtime};

  static bool isKnown(String? key) => key != null && all.contains(key);
}

/// Resolve / infer template keys and localized copy for reminders.
abstract final class ReminderTemplates {
  static String? normalizeKey(String? raw) {
    final key = raw?.trim().toLowerCase();
    return ReminderTemplateKeys.isKnown(key) ? key : null;
  }

  /// Prefer API [templateKey]; otherwise match known ID/EN preset titles.
  static String? resolveKey({
    String? templateKey,
    required String title,
    String body = '',
  }) {
    final fromApi = normalizeKey(templateKey);
    if (fromApi != null) return fromApi;

    final t = title.trim().toLowerCase();
    if (t.isEmpty) return null;

    const studyTitles = {
      'waktunya belajar',
      'study time',
    };
    const bedtimeTitles = {
      'waktunya tidur',
      'bedtime',
    };
    if (studyTitles.contains(t)) return ReminderTemplateKeys.study;
    if (bedtimeTitles.contains(t)) return ReminderTemplateKeys.bedtime;
    return null;
  }

  static String titleFor(AppLocalizations l10n, String key) {
    switch (key) {
      case ReminderTemplateKeys.study:
        return l10n.reminderStudyPresetTitle;
      case ReminderTemplateKeys.bedtime:
        return l10n.reminderSleepPresetTitle;
      default:
        return '';
    }
  }

  static String bodyFor(AppLocalizations l10n, String key) {
    switch (key) {
      case ReminderTemplateKeys.study:
        return l10n.reminderStudyPresetBody;
      case ReminderTemplateKeys.bedtime:
        return l10n.reminderSleepPresetBody;
      default:
        return '';
    }
  }

  static String displayTitle(
    AppLocalizations l10n, {
    String? templateKey,
    required String title,
    String body = '',
  }) {
    final key = resolveKey(templateKey: templateKey, title: title, body: body);
    if (key == null) return title;
    return titleFor(l10n, key);
  }

  static String displayBody(
    AppLocalizations l10n, {
    String? templateKey,
    required String title,
    required String body,
  }) {
    final key = resolveKey(templateKey: templateKey, title: title, body: body);
    if (key == null) return body;
    return bodyFor(l10n, key);
  }

  static int defaultHour(String key) {
    switch (key) {
      case ReminderTemplateKeys.study:
        return 19;
      case ReminderTemplateKeys.bedtime:
        return 21;
      default:
        return 12;
    }
  }

  static int defaultMinute(String key) => 0;
}
