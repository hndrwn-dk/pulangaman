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

  @override
  String get homeByNoChildren => 'No child linked yet';

  @override
  String get tripSectionTitle => 'Safe Route';

  @override
  String get tripCreateCta => 'Create safe route';

  @override
  String get tripSuggestSchoolHome => 'School → Home';

  @override
  String get tripPickFrom => 'From';

  @override
  String get tripPickTo => 'To';

  @override
  String get tripCreate => 'Create route';

  @override
  String get tripStart => 'Start tracking';

  @override
  String get tripCancel => 'Cancel';

  @override
  String get tripActive => 'On the way';

  @override
  String get tripPlanned => 'Planned';

  @override
  String get tripArrived => 'Arrived';

  @override
  String get tripNeedTwoPlaces => 'Add at least two places first';

  @override
  String get tripNeedDistinct => 'Origin and destination must differ';

  @override
  String get tripCreated => 'Safe route created';

  @override
  String get tripChildStart => 'Start trip';

  @override
  String get tripChildPickDest => 'Choose destination';

  @override
  String tripChildActiveTo(String place) {
    return 'Heading to $place';
  }

  @override
  String get tripChildCancel => 'Cancel trip';

  @override
  String tripProgressMeta(String distance, String eta) {
    return '$distance · $eta';
  }

  @override
  String get empTitle => 'Emergency Meeting Point';

  @override
  String get empSubtitle => 'Where to meet in an emergency';

  @override
  String empEmpty(String childName) {
    return 'No meeting point for $childName yet';
  }

  @override
  String get empAdd => '+ Add meeting point';

  @override
  String get empAddBackup => 'Backup point';

  @override
  String get empPrimaryLabel => 'Primary meeting point';

  @override
  String get empPrimary => 'Primary';

  @override
  String get empBackup => 'Backup';

  @override
  String get empInstructionsHint =>
      'Example: If we cannot reach each other, meet here';

  @override
  String get empNameHint => 'Place name (e.g. Grandma\'s house)';

  @override
  String get empSave => 'Save';

  @override
  String get empDelete => 'Delete';

  @override
  String get empEdit => 'Change meeting point';

  @override
  String get empMapPreview => 'Map preview';

  @override
  String get empApplyToOthers => 'Apply to other children too?';

  @override
  String get empApply => 'Apply';

  @override
  String get empActivate => 'Activate meeting point';

  @override
  String get empActivateConfirm =>
      'All children and guardians will be notified to go to their meeting points. Continue?';

  @override
  String get empActivateNoteHint => 'Short note (optional)';

  @override
  String get empActivateContinue => 'Activate now';

  @override
  String get empActivateCancel => 'Cancel';

  @override
  String empActivateCaption(String names) {
    return 'Applies to $names, and their guardians';
  }

  @override
  String empSummarySent(int count) {
    return 'Sent to $count children';
  }

  @override
  String empSummarySkipped(String childName) {
    return '$childName has no meeting point yet';
  }

  @override
  String get empRateLimited => 'Activation limited — try again later';

  @override
  String get empOpenMaps => 'Open in Maps';

  @override
  String get empDistanceUnknown => 'Distance unknown';

  @override
  String empDistanceLive(String childName, String distance) {
    return '$childName is now $distance from here';
  }

  @override
  String empDistanceFromChild(String distance) {
    return 'Child distance: $distance';
  }

  @override
  String get empAlertTitle => 'Emergency Meeting Point';

  @override
  String empAlertBody(String place) {
    return 'Head to $place now';
  }

  @override
  String empMyDistance(String distance) {
    return 'Your distance: $distance';
  }

  @override
  String get empMenuHint => 'Meet here in an emergency';

  @override
  String get empPickPlace => 'Search for a meeting place';

  @override
  String get empNoChildren => 'No child linked yet';
}
