// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PulangAman';

  @override
  String get homeByTitle => 'Safe Home Time';

  @override
  String get homeBySubtitle =>
      'Check whether your child is home by the set time';

  @override
  String get homeByModeOff => 'Off';

  @override
  String get homeByModeMaghrib => 'Follow Maghrib time';

  @override
  String get homeByModeMaghribHint =>
      'Time changes daily, based on home location';

  @override
  String get homeByModeCustom => 'Fixed time';

  @override
  String get homeByGraceLabel => 'Grace period';

  @override
  String homeByGraceHint(int minutes) {
    return '$minutes minutes after home time';
  }

  @override
  String get homeByWeekendTitle => 'Weekends';

  @override
  String get homeByWeekendOff => 'Turn off';

  @override
  String get homeByWeekendSame => 'Same as weekdays';

  @override
  String get homeByWeekendCustom => 'Different time';

  @override
  String get homeBySkipDatesTitle => 'Holidays';

  @override
  String get homeBySkipDatesAdd => 'Mark a date';

  @override
  String get homeBySkipDatesEmpty => 'No holiday dates yet';

  @override
  String get homeByTodayStatus => 'Today\'s status';

  @override
  String get homeByStatusPending => 'Waiting for home time';

  @override
  String get homeByStatusPreNotified => 'Home reminder sent to child';

  @override
  String get homeByStatusTargetNotified => 'Not home yet — parent notified';

  @override
  String get homeByStatusGraceNotified => 'Still not home after grace period';

  @override
  String get homeByStatusResolved => 'Already home';

  @override
  String get homeByStatusSkipped => 'Holiday / not monitored today';

  @override
  String homeByTargetTime(String time) {
    return 'Home by $time';
  }

  @override
  String get homeByOnceHomeNote =>
      'Once your child arrives home, today\'s monitoring ends even if they leave again.';

  @override
  String get homeBySave => 'Save';

  @override
  String get homeBySaved => 'Safe home time settings saved';

  @override
  String get homeBySeeAll => 'See all';

  @override
  String get homeBySummaryOff => 'Not enabled yet';

  @override
  String homeBySummaryMaghrib(String status) {
    return 'Follow Maghrib · $status';
  }

  @override
  String homeBySummaryCustom(String time, String status) {
    return '$time · $status';
  }

  @override
  String get homeByChildAckButton => 'I\'m on my way home';

  @override
  String get homeByChildAckSent => 'Sent to parent';

  @override
  String get homeByChildAckReasonInTransit => 'On the way';

  @override
  String get homeByChildAckReasonStoppedBy => 'Stopped somewhere';

  @override
  String get homeByChildAckReasonSchool => 'School activity';

  @override
  String get homeByChildAckReasonOther => 'Other';

  @override
  String get homeByChildAckNoteHint => 'Short note (optional)';

  @override
  String get homeByChildAckSubmit => 'Send to parent';

  @override
  String get homeByChildAckTitle => 'Update your parent';
}
