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
  String get homeByModeLabel => 'Mode';

  @override
  String homeBySkipDatesCount(int count) {
    return '$count holiday dates';
  }

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
  String get homeBySummaryNotTurnedOn => 'Not turned on';

  @override
  String homeBySummaryMaghrib(String status) {
    return 'Maghrib mode selected · $status';
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
  String get empEmptyGeneric => 'No meeting point yet';

  @override
  String get empLoadError => 'Could not load meeting point';

  @override
  String get empRetry => 'Try again';

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
  String get empDeleteConfirm => 'Delete the meeting point for all children?';

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
  String get listAnd => 'and';

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
  String get empActiveTitle => 'Meeting point is active';

  @override
  String empActiveSince(String time) {
    return 'Activated $time';
  }

  @override
  String get empArrived => 'Arrived';

  @override
  String get empOnTheWay => 'On the way';

  @override
  String get empChildLocationUnknown => 'Location unknown';

  @override
  String get empActiveNoPoint => 'No meeting point yet';

  @override
  String get empRefresh => 'Refresh';

  @override
  String get empDeactivate => 'Turn off meeting point';

  @override
  String get empDeactivateConfirm =>
      'Turn off the emergency meeting point? Children and guardians will be told the emergency is over.';

  @override
  String get empDeactivated => 'Meeting point turned off';

  @override
  String get empMenuHint => 'Meet here in an emergency';

  @override
  String get empPickPlace => 'Search for a meeting place';

  @override
  String get empNoChildren => 'No child linked yet';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'Choose your preferred language';

  @override
  String get settingsLanguageId => 'Bahasa Indonesia';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutHint => 'Share, rate, and app information';

  @override
  String get settingsVersion => 'Version';

  @override
  String settingsVersionValue(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get settingsShare => 'Share this app';

  @override
  String get settingsShareHint => 'Tell family about PulangAman';

  @override
  String get settingsShareMessage =>
      'Try PulangAman — a safety network for parents and kids.\nhttps://www.tursinalabs.com';

  @override
  String get settingsRate => 'Rate this app';

  @override
  String get settingsRateHint => 'Leave a review on Google Play';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsPrivacyHint => 'Read our privacy policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsTermsHint => 'Read our terms of service';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsHint => 'Updates, SOS, and safe zones';

  @override
  String get brand => 'Pulang Aman';

  @override
  String get tagline => 'Go home calmly, arrive safely.';

  @override
  String get roleParent => 'I am a parent';

  @override
  String get roleChild => 'I am a child';

  @override
  String get roleGuardian => 'I am a trusted guardian';

  @override
  String get roleLabel => 'Role';

  @override
  String get roleParentShort => 'Parent';

  @override
  String get roleChildShort => 'Child';

  @override
  String get roleGuardianShort => 'Guardian';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHint => 'Enter full name';

  @override
  String get phoneHint => '+62812...';

  @override
  String get loginAction => 'Sign in';

  @override
  String get otpLabel => 'OTP code';

  @override
  String get otpHint => '6 digits from SMS';

  @override
  String get otpSentHint => 'Verification code sent to your number';

  @override
  String get verifyOtpAction => 'Verify';

  @override
  String get otpVerifyingHint => 'Verifying code. Please wait a moment.';

  @override
  String get otpSendingHint => 'Sending verification code. Please wait…';

  @override
  String get resendOtp => 'Resend code';

  @override
  String get changeNumber => 'Change number';

  @override
  String get sendOtpAction => 'Send OTP code';

  @override
  String get inviteCodeHintChild => 'Ask your parent for a 6-digit code';

  @override
  String get connecting => 'Connecting...';

  @override
  String get sending => 'Sending...';

  @override
  String get featureCheckIn => 'Check-in';

  @override
  String get featureRewards => 'Rewards';

  @override
  String get featureScreenTime => 'Screen Time';

  @override
  String get childrenTitle => 'My children';

  @override
  String get addChild => 'Invite child';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get createInvite => 'Create invite code';

  @override
  String get inviteShareHint =>
      'Give this code to the child\'s phone. Valid 24 hours.';

  @override
  String get liveMap => 'Live map';

  @override
  String get zonesTitle => 'Safe Zones';

  @override
  String get guardiansTitle => 'Trusted guardians';

  @override
  String get panicButton => 'PANIC BUTTON';

  @override
  String get panicConfirm => 'Tap 3 times to send an alert';

  @override
  String get panicHoldConfirm => 'Press & hold 3 seconds to send an alert';

  @override
  String get panicSent => 'Panic alert sent';

  @override
  String get trackingOn => 'Tracking on';

  @override
  String get bgLocationDisclosureTitle =>
      'Why do we need location all the time?';

  @override
  String get bgLocationDisclosureBody =>
      'So parents can see your live location and get safe-zone alerts even when the app is closed.';

  @override
  String get bgLocationDisclosureContinue => 'Continue';

  @override
  String get trackingOff => 'Tracking off';

  @override
  String get staleLocation => 'Child location not updated';

  @override
  String get ackAlert => 'I have responded';

  @override
  String get resolveAlert => 'Resolved / safe';

  @override
  String get inviteGuardian => 'Invite guardian';

  @override
  String get acceptInvite => 'Accept invite';

  @override
  String get shareLocation => 'Share my location';

  @override
  String get needBackup => 'Need backup help';

  @override
  String get guardianGuidance =>
      'Contact a parent or emergency services. Do not chase strangers.';

  @override
  String get offlineQueued => 'Saved offline — will send when online';

  @override
  String get homeZone => 'Home';

  @override
  String get schoolZone => 'School';

  @override
  String get save => 'Save';

  @override
  String get logout => 'Sign out';

  @override
  String get cancel => 'Cancel';

  @override
  String get emergencyContacts => 'Emergency contacts';

  @override
  String get noChildren => 'No child linked yet';

  @override
  String get noInvites => 'No invites';

  @override
  String get activeAlerts => 'Active alerts';

  @override
  String get mapKeyMissing =>
      'Google Maps is not configured. Add GOOGLE_MAPS_API_KEY in android/local.properties then rebuild.';

  @override
  String get lastKnownCoords => 'Last known coordinates';

  @override
  String get childTabHome => 'Home';

  @override
  String get childTabScreen => 'Screen';

  @override
  String get childTabMessages => 'Updates';

  @override
  String get childMessageSent => 'Update sent';

  @override
  String get childMessageFailed => 'Failed to send update. Try again.';

  @override
  String errorWithDetail(String error) {
    return 'Failed: $error';
  }

  @override
  String get panicAckedByParent =>
      'Your parent has already responded to the panic alert';

  @override
  String get panicResolvedSafe => 'Panic marked as resolved and safe';

  @override
  String panicConfirmCount(int count) {
    return 'Tap 3 times to send an alert ($count/3)';
  }

  @override
  String get panicSendFailedRetrying =>
      'Failed to send panic alert. Retrying automatically.';

  @override
  String get smsFallbackPanicBody => 'PulangAman PANIC — need help now.';

  @override
  String get empDefaultPlaceName => 'Meeting point';

  @override
  String empAlertBodyWithNote(String note, String place) {
    return '$note — heading to $place';
  }

  @override
  String empAlertBodyPlain(String place) {
    return 'Head to the meeting point now: $place';
  }

  @override
  String get homeByPreviewTitle => 'Time to head home';

  @override
  String homeByPreviewBody(String name) {
    return '$name, it\'s almost time to head home';
  }

  @override
  String get greetingDefaultName => 'Friend';

  @override
  String get homeByDefaultChildName => 'Child';

  @override
  String get tripNotEnoughPlaces => 'Not enough saved places yet';

  @override
  String get zoneGenericLabel => 'Place';

  @override
  String get startAction => 'Start';

  @override
  String tripArrivedNotified(String place) {
    return 'Arrived at $place — parent notified';
  }

  @override
  String get destinationFallback => 'destination';

  @override
  String get locationSendFailed => 'Failed to send location';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get sessionNotReady => 'Session not ready';

  @override
  String get allowExactAlarmMessage =>
      'Allow exact alarms so your parent\'s reminders show up.';

  @override
  String get openAction => 'Open';

  @override
  String get trackingOnNeedsAlways =>
      'Location active — allow \"Always\" so it keeps running in the background';

  @override
  String get refreshTooltip => 'Refresh (send app list & rules)';

  @override
  String get refreshSentWithApps => 'Location & app list sent to your parent';

  @override
  String get refreshSentNoApps =>
      'Location sent. App list is empty — check Usage Access permission.';

  @override
  String get logoutConfirmTitle => 'Sign out of child account?';

  @override
  String get logoutConfirmBody =>
      'To sign in again, ask your parent for a new invite code from their phone.';

  @override
  String childMessageSentWithLabel(String label) {
    return 'Update sent: $label';
  }

  @override
  String get homeSubtitleTagline =>
      'Stay safe, earn points, and keep your family posted.';

  @override
  String get pillLocationOn => 'Location on';

  @override
  String get pillLocationOff => 'Location off';

  @override
  String pointsStreakLabel(int points, int streak) {
    return '$points points · $streak-day streak';
  }

  @override
  String get screenRulesActive => 'Screen rules active';

  @override
  String get screenPermissionIncomplete => 'Screen permission incomplete';

  @override
  String get alarmPermissionIncomplete => 'Alarm permission incomplete';

  @override
  String reminderActiveCount(int count) {
    return 'Reminders active ($count)';
  }

  @override
  String get noRemindersYet => 'No reminders yet';

  @override
  String get sendingAlert => 'Sending alert...';

  @override
  String get panicCooldownMessage =>
      'Panic alert sent. Wait a moment before you can send again.';

  @override
  String get panicModeActiveWaiting =>
      'Panic mode active — waiting for parent response';

  @override
  String get enableScreenProtectionTitle => 'Turn on screen time protection';

  @override
  String get neverBlockedAppsNote =>
      'PulangAman, Phone, and Messages are never blocked.';

  @override
  String get allowUsageAccess => 'Allow usage access';

  @override
  String get enableAppBlocking => 'Turn on app blocking';

  @override
  String get restrictedSettingsHelp =>
      'Button locked (\"Restricted setting\")? Open App info, tap the three-dot menu in the top right, then choose \"Allow restricted setting\". Then try again.';

  @override
  String get openAppInfo => 'Open app info';

  @override
  String get empActiveNowLabel => 'Emergency — go now';

  @override
  String get empFamilyMeetingPoint => 'Family meeting point';

  @override
  String get followParentInstructions => 'Follow your parent\'s instructions';

  @override
  String get memorizeEmpPlace => 'Memorize this place for emergencies';

  @override
  String tripArrivedAt(String place) {
    return 'Arrived at $place';
  }

  @override
  String get tripRouteReady => 'Route ready';

  @override
  String get tripGenericLabel => 'Trip';

  @override
  String get tripParentNotified => 'Parent has been notified';

  @override
  String get tripReadyToStart => 'Ready to start';

  @override
  String get tripInProgress => 'In progress';

  @override
  String get tripChooseSafeDestination =>
      'Choose a safe destination from saved places';

  @override
  String get screenTimeToday => 'Screen time today';

  @override
  String get yourPoints => 'Your points';

  @override
  String dayStreakCaption(int streak) {
    return '$streak-day streak';
  }

  @override
  String get todaysRemindersTitle => 'Today\'s reminders';

  @override
  String get todaysRemindersEmpty => 'No reminders scheduled for today.';

  @override
  String get kabarTitle => 'Update to parent';

  @override
  String get kabarSubtitle => 'Tap once — the message is sent right away.';

  @override
  String get kabarInfoNote =>
      'Messages go to your linked parent. For emergencies, use the panic button on Home.';

  @override
  String get kabarHeroTitle => 'Send a quick update';

  @override
  String get kabarHeroSubtitle =>
      'No need to type. Just pick one of the messages below.';

  @override
  String get presetAtSchoolLabel => 'Arrived at school';

  @override
  String get presetAtSchoolSubtitle =>
      'Let your parent know you\'re safe at school';

  @override
  String get presetAtHomeLabel => 'Home now';

  @override
  String get presetAtHomeSubtitle => 'Let them know you\'re home';

  @override
  String get presetNeedHelpLabel => 'Need help';

  @override
  String get presetNeedHelpSubtitle => 'Ask your parent to call you right away';

  @override
  String get screenTimeTitle => 'Screen time';

  @override
  String get screenTimeSubtitle =>
      'See how long you\'ve used your phone today.';

  @override
  String screenTimeOverTargetStatus(String period) {
    return '$period · over target';
  }

  @override
  String get appsLabel => 'Apps';

  @override
  String appCountLabel(int count) {
    return '$count apps';
  }

  @override
  String get usageAccessInactiveTitle => 'Usage access not active';

  @override
  String get usageAccessInactiveBody =>
      'Allow PulangAman to see your screen usage so stats can show up here.';

  @override
  String get openPermissionSettings => 'Open permission settings';

  @override
  String get totalLabel => 'Total';

  @override
  String get targetLabel => 'Target';

  @override
  String get noDataYet => 'No data yet';

  @override
  String get useAsUsualStatsAppear =>
      'Use your phone as usual — stats will appear here.';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get understood => 'Got it';

  @override
  String get editAction => 'Edit';

  @override
  String get retryAction => 'Try again';

  @override
  String get okAction => 'OK';

  @override
  String get closeAction => 'Close';

  @override
  String get viewAllAction => 'View all ›';

  @override
  String get noChildrenTitle => 'No children yet';

  @override
  String get addChildFirstMessage => 'Add a child first from the Children tab.';

  @override
  String get reloadTooltip => 'Reload';

  @override
  String deleteFailedWithDetail(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String saveFailedWithDetail(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get markAllReadAction => 'Mark all as read';

  @override
  String get markReadAction => 'Mark as read';

  @override
  String get allFilterLabel => 'All';

  @override
  String get parentFallbackName => 'Parent';

  @override
  String get weekdayMonShort => 'Mon';

  @override
  String get weekdayTueShort => 'Tue';

  @override
  String get weekdayWedShort => 'Wed';

  @override
  String get weekdayThuShort => 'Thu';

  @override
  String get weekdayFriShort => 'Fri';

  @override
  String get weekdaySatShort => 'Sat';

  @override
  String get weekdaySunShort => 'Sun';

  @override
  String durationHoursLabel(int hours) {
    return '${hours}h';
  }

  @override
  String durationMinutesLabel(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHoursMinutesLabel(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get settingsAccountTitle => 'Account Settings';

  @override
  String get parentAccountSubtitle => 'PulangAman parent account';

  @override
  String get notificationsSheetTitle => 'PulangAman Notifications';

  @override
  String get notificationsSheetBody =>
      'Notifications are used for Updates, SOS, and safe zones. Manage permissions in phone Settings (Apps > PulangAman > Notifications).';

  @override
  String get remindersTitle => 'Reminder Schedule';

  @override
  String get remindersLoadError =>
      'Couldn\'t load reminders. Check your connection and try again.';

  @override
  String reminderPresetSaved(String title) {
    return 'Reminder \"$title\" saved.\nOpen PulangAman on your child\'s phone so the schedule turns on.';
  }

  @override
  String get reminderEditTitle => 'Edit reminder';

  @override
  String get reminderCustomTitle => 'Custom reminder';

  @override
  String get reminderTitleFieldLabel => 'Title';

  @override
  String get reminderMessageFieldLabel => 'Message';

  @override
  String get reminderTimeQuestion => 'What time?';

  @override
  String get reminderPickTimeHelp => 'Choose reminder time';

  @override
  String get reminderUseThisTime => 'Use this time';

  @override
  String get reminderHourLabel => 'Hour';

  @override
  String get reminderMinuteLabel => 'Minute';

  @override
  String get reminderStyleFullscreen => 'Fullscreen';

  @override
  String get reminderStyleNotification => 'Notification';

  @override
  String get reminderEveryDay => 'Every day';

  @override
  String get reminderSaveChanges => 'Save changes';

  @override
  String get reminderTitleBodyRequired => 'Title and message are required';

  @override
  String get reminderInfoBanner =>
      'Your child\'s phone will show a big message at the set time. They just tap \"Got it\" to close it.';

  @override
  String get reminderNoChildrenMessage =>
      'Link a child first before creating reminders.';

  @override
  String get sectionForChild => 'FOR CHILD';

  @override
  String get sectionQuickAdd => 'QUICK ADD';

  @override
  String get reminderActiveScheduleTitle => 'Active Schedule';

  @override
  String get reminderAddShort => '+ Add';

  @override
  String get reminderEmptyMessage => 'No reminders yet. Use quick add above.';

  @override
  String reminderPresetAlreadyExists(String title) {
    return '\"$title\" is already scheduled for this child.';
  }

  @override
  String get reminderStudyChipLabel => 'Study 19:00';

  @override
  String get reminderSleepChipLabel => 'Sleep 21:00';

  @override
  String get reminderStudyPresetTitle => 'Study Time';

  @override
  String get reminderStudyPresetBody =>
      'It\'s study time now. Turn off games first.';

  @override
  String get reminderSleepPresetTitle => 'Bedtime';

  @override
  String get reminderSleepPresetBody =>
      'It\'s getting late. Time to rest so you\'re refreshed tomorrow.';

  @override
  String get parentHomeNoChildrenMessage =>
      'Tap \"Add child\" below to create a code, then enter it on your child\'s phone. If you\'re switching sign-in methods, recover from the old number first.';

  @override
  String get recoverChildrenButton => 'Recover children from old number';

  @override
  String get childLocationSectionTitle => 'Child Location';

  @override
  String get viewMapAction => 'View map ›';

  @override
  String get todaySummaryTitle => 'Today\'s Summary';

  @override
  String get placesVisitedLabel => 'Places visited';

  @override
  String get totalTripDistanceLabel => 'Total distance';

  @override
  String get pendingCodesTitle => 'Pending codes';

  @override
  String get dismissPendingCodeTooltip => 'Dismiss code';

  @override
  String get dismissPendingCodeConfirm =>
      'Dismiss this pending code? It will stop working.';

  @override
  String get pendingCodeDismissedSnack => 'Pending code dismissed';

  @override
  String dismissPendingCodeFailed(String error) {
    return 'Could not dismiss code: $error';
  }

  @override
  String relinkReplaceConfirmBody(String name) {
    return 'There\'s already a pending code for $name. Generate a new one? The old code will stop working.';
  }

  @override
  String get generateNewCodeAction => 'Generate new';

  @override
  String get recoverChildrenTitle => 'Recover children';

  @override
  String get recoverChildrenPrompt =>
      'Enter the number the parent account used before.';

  @override
  String get oldPhoneNumberLabel => 'Old number';

  @override
  String get recoverAction => 'Recover';

  @override
  String recoverChildrenSuccess(int count) {
    return 'Recovered $count children. Now create a new sign-in code from the child menu.';
  }

  @override
  String get recoverChildrenNone =>
      'No children were moved. Check the old number.';

  @override
  String recoverChildrenFailed(String error) {
    return 'Failed to recover: $error';
  }

  @override
  String relinkCodeTitle(String name) {
    return 'New sign-in code for $name';
  }

  @override
  String createCodeFailed(String error) {
    return 'Failed to create code: $error';
  }

  @override
  String removeChildConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String removeChildConfirmBody(String name) {
    return '$name will be removed from your list. Location sharing stops until you add them again with a new sign-in code.';
  }

  @override
  String childRemoved(String name) {
    return '$name removed';
  }

  @override
  String get addChildTitle => 'Add child';

  @override
  String get createCodeAction => 'Create code';

  @override
  String get codeTitle => 'Code';

  @override
  String get tapToViewStatus => 'Tap to view status';

  @override
  String get allChildrenArrived => 'All children have arrived';

  @override
  String arrivedWaitingSummary(int arrived, int total, String names) {
    return '$arrived/$total arrived - waiting for $names';
  }

  @override
  String get empBannerActiveTitle => 'Emergency meeting point active';

  @override
  String childNeedsHelp(String name) {
    return '$name needs help';
  }

  @override
  String withTapDetail(String time) {
    return '$time · Tap for details';
  }

  @override
  String get navChildrenLabel => 'Children';

  @override
  String get navZonesLabel => 'Zones';

  @override
  String get navMoreLabel => 'More';

  @override
  String get moreScreenTitle => 'More Features';

  @override
  String get moreScreenSubtitle => 'Manage settings & extras';

  @override
  String get activeRemindersStatLabel => 'Active Reminders';

  @override
  String get totalPointsStatLabel => 'Total Points';

  @override
  String get sectionScheduleActivity => 'SCHEDULE & ACTIVITY';

  @override
  String get sectionSafety => 'SAFETY';

  @override
  String get sectionSettings => 'SETTINGS';

  @override
  String get noPointsNoStreak => '0 points · No streak yet';

  @override
  String pointsCountLabel(int points) {
    return '$points points';
  }

  @override
  String get noGuardiansYet => 'No guardians yet';

  @override
  String guardiansCountLabel(int count) {
    return '$count guardians';
  }

  @override
  String get noReportsYet => 'No reports yet';

  @override
  String reportsCountLabel(int count) {
    return '$count reports';
  }

  @override
  String get emergencyMeetingMenuSubtitle => 'Where to meet in an emergency';

  @override
  String get accountSettingsMenuSubtitle => 'Notifications, privacy, sign out';

  @override
  String get allKabarMarkedRead => 'All updates marked as read';

  @override
  String get kabarHistoryTitle => 'Update History';

  @override
  String get noKabarYet => 'No updates yet';

  @override
  String kabarSummaryUnread(int unread, int total) {
    return '$unread unread · $total updates · last 24h';
  }

  @override
  String kabarSummaryAll(int total) {
    return '$total updates · last 24h';
  }

  @override
  String get noKabarForFilter => 'No updates for this filter.';

  @override
  String get giveRewardTitle => 'Give praise';

  @override
  String get rewardReasonLabel => 'Reason (optional)';

  @override
  String get rewardReasonHint => 'e.g. Studied hard today';

  @override
  String get addFivePointsAction => 'Add +5';

  @override
  String get defaultPraiseReason => 'Praise from parent';

  @override
  String get pointsAddedSnackbar => '+5 points added';

  @override
  String get pickChildTitle => 'Choose child';

  @override
  String get rewardsTitle => 'Rewards & Points';

  @override
  String get givePraiseFabLabel => 'Give Praise (+5)';

  @override
  String get rewardsIntro =>
      'Points are earned when a child arrives at school on time. You can also add them manually as praise.';

  @override
  String get howToEarnPointsTitle => 'How to Earn Points';

  @override
  String get howToEarnPointsReferenceTitle =>
      'How points are earned (reference)';

  @override
  String get earnSchoolOnTimeTitle => 'Arrive at School on Time';

  @override
  String get earnSchoolOnTimeSubtitle => '+10 points per day';

  @override
  String get earnHomeOnTimeTitle => 'Home on Time';

  @override
  String get earnHomeOnTimeSubtitle => '+5 points per day';

  @override
  String get earnParentPraiseTitle => 'Praise from Parent';

  @override
  String get earnParentPraiseSubtitle => '+5 points manual';

  @override
  String get earnPerDayLabel => 'per day';

  @override
  String get earnManualLabel => 'manual';

  @override
  String get pointsHistoryTitle => 'Points History';

  @override
  String get noPointsHistoryTitle => 'No points history yet';

  @override
  String get noPointsHistoryMessage =>
      'After your child checks in at school, points will appear here.';

  @override
  String totalPointsForChild(String name) {
    return '$name\'s Total Points';
  }

  @override
  String get noStreakYet => 'No daily streak yet';

  @override
  String streakDaysLabel(int streak) {
    return '$streak-day streak going strong';
  }

  @override
  String streakCelebrationTitle(int days) {
    return '$days-Day Streak!';
  }

  @override
  String streakCelebrationBody(int days) {
    return 'You\'ve kept your screen time on target for $days days. Nice work!';
  }

  @override
  String streakPointsBadge(int points) {
    return '+$points points';
  }

  @override
  String get viewPointsCta => 'View Points';

  @override
  String get weeklyDigestBannerTitle => 'This week\'s summary';

  @override
  String get weeklyDigestBannerAction => 'View details';

  @override
  String get weeklyDigestBannerDismiss => 'Dismiss';

  @override
  String get earnExampleHint => 'Example: arriving at school +10 points';

  @override
  String get weeklyStreakTitle => 'This Week\'s Streak';

  @override
  String get screenTimeMonitorSubtitle => 'Monitor daily usage';

  @override
  String get noAppDataToday => 'No app data yet today.';

  @override
  String get appUsageTitle => 'App Usage';

  @override
  String get thisWeekTitle => 'This Week';

  @override
  String get thisMonthTitle => 'This Month';

  @override
  String get heatmapLegendLow => 'Little';

  @override
  String get heatmapLegendOver => 'Over limit';

  @override
  String topAppCallout(String period, String app, String time) {
    return 'Most used $period: $app, total $time';
  }

  @override
  String get periodLabelToday => 'today';

  @override
  String get periodLabelThisWeek => 'this week';

  @override
  String get periodLabelThisMonth => 'this month';

  @override
  String appTrendNew(String period) {
    return 'New $period';
  }

  @override
  String get noAppDataForPeriod => 'No app data for this period yet.';

  @override
  String weekdayPatternInsight(String dayNames, int weekCount) {
    return 'A pattern is showing: $dayNames consistently higher over the last $weekCount weeks.';
  }

  @override
  String weekendPatternInsight(int weekCount) {
    return 'Weekends have been consistently higher over the last $weekCount weeks.';
  }

  @override
  String get weekdayMonFull => 'Monday';

  @override
  String get weekdayTueFull => 'Tuesday';

  @override
  String get weekdayWedFull => 'Wednesday';

  @override
  String get weekdayThuFull => 'Thursday';

  @override
  String get weekdayFriFull => 'Friday';

  @override
  String get weekdaySatFull => 'Saturday';

  @override
  String get weekdaySunFull => 'Sunday';

  @override
  String get insightThisWeekTitle => 'This week\'s insight';

  @override
  String insightAddReminderPrompt(String time) {
    return 'Add a reminder at $time?';
  }

  @override
  String insightDaysUnderLimit(int days, int total) {
    return '$days of $total days under limit';
  }

  @override
  String get insightRewardsAutoHint => 'Rewards tracks this automatically';

  @override
  String get insightReminderBodyDefault =>
      'Time to put the phone down and wind down.';

  @override
  String get limitScheduleTitle => 'Limit Schedule';

  @override
  String get editInRulesHint => 'Edit in Rules';

  @override
  String get todayLabel => 'Today';

  @override
  String get limitOffLabel => 'Limit turned off';

  @override
  String outOfLimitLabel(String limit) {
    return 'of $limit limit';
  }

  @override
  String remainingTimeLabel(String remaining) {
    return '$remaining left';
  }

  @override
  String overLimitLegend(String limit) {
    return 'Over limit ($limit)';
  }

  @override
  String get safeLegendLabel => 'Safe';

  @override
  String get noActiveScheduleLabel => 'No active schedule';

  @override
  String screenTimeRulesTitle(String name) {
    return 'Rules · $name';
  }

  @override
  String get limitScreenUsageLabel => 'Limit phone use';

  @override
  String get noLimitLabel => 'No limit';

  @override
  String get schoolDaysTitle => 'School Days';

  @override
  String get schoolDaysRangeLabel => 'Mon–Fri';

  @override
  String get weekendDaysTitle => 'Weekend';

  @override
  String get weekendDaysRangeLabel => 'Sat–Sun';

  @override
  String maxLimitLabel(String limit) {
    return 'Max $limit';
  }

  @override
  String get blockedAppsTitle => 'Blocked Apps';

  @override
  String get noAppListYet => 'No app list yet.';

  @override
  String get notUsedTodayLabel => 'Not used today';

  @override
  String usedDurationLabel(String duration) {
    return 'Used $duration';
  }

  @override
  String get schoolLimitPickerTitle => 'School days limit';

  @override
  String get weekendLimitPickerTitle => 'Weekend limit';

  @override
  String get savingLabel => 'Saving...';

  @override
  String rulesSavedMessage(String name) {
    return 'Rules saved for $name. Open PulangAman on your child\'s phone to activate.';
  }

  @override
  String limitsDisabledMessage(String name) {
    return 'Screen time limit turned off for $name.';
  }

  @override
  String get whereTitle => 'Where';

  @override
  String get childPositionsTodayTitle => 'Children\'s Location Today';

  @override
  String get whereScreenIntro =>
      'Not just school — home, commutes, and other safe zones show up too. Tap a child to see school check-in/out records.';

  @override
  String get locationUnclear => 'Location unclear';

  @override
  String get inHomeZoneHint => 'In the home zone you set';

  @override
  String get inSchoolZoneHint => 'In the school zone you set';

  @override
  String get commutingHint => 'Currently commuting';

  @override
  String get locationHintDefault =>
      'Make sure your child\'s location is on and important places are set';

  @override
  String whereDetailTitle(String name) {
    return 'Where · $name';
  }

  @override
  String get zoneStatusExplain =>
      'Status based on the safe zones you\'ve set (home, school, or others).';

  @override
  String get schoolNotesToday => 'Today\'s School Notes';

  @override
  String get schoolNotesHint =>
      'Appears automatically when your child enters/leaves the school zone.';

  @override
  String get noSchoolNotesTitle => 'No school notes yet';

  @override
  String get noSchoolNotesMessage =>
      'Once the school zone is set and your child\'s location is on, arrival/departure notes will appear here.';

  @override
  String get arrivedAtSchool => 'Arrived at school';

  @override
  String get departedFromSchool => 'Left school';

  @override
  String get statusHomeLabel => 'Home';

  @override
  String get statusSchoolLabel => 'At school';

  @override
  String get statusSafeZoneLabel => 'In safe zone';

  @override
  String get statusCommutingLabel => 'Commuting';

  @override
  String get categoryHazardTitle => 'Hazard / Damaged Road';

  @override
  String get categoryTrafficTitle => 'Traffic';

  @override
  String get categoryCrowdTitle => 'Crowd';

  @override
  String get categoryOtherTitle => 'Other Report';

  @override
  String get categoryHazardShort => 'Hazard';

  @override
  String get categoryTrafficShort => 'Traffic';

  @override
  String get categoryCrowdShort => 'Crowd';

  @override
  String get categoryOtherShort => 'Other';

  @override
  String get addPinTitle => 'Add Pin';

  @override
  String get reportTypeLabel => 'Type';

  @override
  String get reportTypeHazard => 'Hazard / Damaged road';

  @override
  String get reportNoteLabel => 'Note';

  @override
  String get reportNoteHint => 'e.g. Damaged road';

  @override
  String get reportNoteHintVr => 'e.g. Pothole near the crossing';

  @override
  String get reportLocationDefault =>
      'Location: using default point (GPS permission not granted)';

  @override
  String reportLocationCoords(String lat, String lng) {
    return 'Location: $lat, $lng';
  }

  @override
  String get savePinAction => 'Save Pin';

  @override
  String get pinAddedSnackbar => 'Pin added';

  @override
  String get reportVerifiedSnackbar => 'Report verified';

  @override
  String verifyFailed(String error) {
    return 'Failed to verify: $error';
  }

  @override
  String get alreadyVerifiedThanks => 'Already verified. Thank you.';

  @override
  String get fixedSuggestionNoted =>
      'Thanks. Your \"fixed\" suggestion has been logged for review.';

  @override
  String get communityReportsTitle => 'Community Reports';

  @override
  String get reportsInfoBanner =>
      'Pins expire after 72 hours unless verified. No marketplace or contact with strangers.';

  @override
  String get totalReportsLabel => 'Total Reports';

  @override
  String get verifiedLabel => 'Verified';

  @override
  String get expiredLabel => 'Expired';

  @override
  String get areaMapTitle => 'Area Map';

  @override
  String get reportsListTitle => 'Report List';

  @override
  String get activeLabel => 'Active';

  @override
  String get filterLabel => 'Filter';

  @override
  String get noActiveReports => 'No active reports';

  @override
  String get noCoordinatesLabel => 'No coordinates';

  @override
  String get coordinatesAvailableLabel => 'Coordinates available';

  @override
  String expiresAtLabel(String date) {
    return 'Expires $date';
  }

  @override
  String get stillThereAction => 'Still There';

  @override
  String get fixedAction => 'Fixed';

  @override
  String get pinLocationLabel => 'Location';

  @override
  String get usingCurrentLocation => 'Using your current location';

  @override
  String get changeLocationAction => 'Change';

  @override
  String get whatAreYouReporting => 'What are you reporting?';

  @override
  String get shortNoteOptional => 'Short note (optional)';

  @override
  String get verifiedBadge => 'VERIFIED';

  @override
  String nearPlaceLabel(String place) {
    return 'near $place';
  }

  @override
  String approxMetersFromPlace(int meters, String place) {
    return '~${meters}m from $place';
  }

  @override
  String get pickPinLocationTitle => 'Pick pin location';

  @override
  String get resolvingLocation => 'Resolving location...';

  @override
  String get locationUnknown => 'Location unavailable';

  @override
  String get presetAtSchoolText => 'Arrived at school!';

  @override
  String get presetAtHomeText => 'Arrived home.';

  @override
  String get presetNeedHelpText => 'Need help — please contact me.';

  @override
  String get homeArrivedStatus => 'At home · Arrived';

  @override
  String hereAtTime(String time) {
    return 'Here · $time';
  }

  @override
  String get waitingGpsSignal => 'Waiting for location signal...';

  @override
  String get atHomeTrackingStopped => 'At home · tracking paused';

  @override
  String get locationNotUpdatedRecently => 'Location has not updated recently';

  @override
  String get movingNow => 'On the move';

  @override
  String get liveJustNow => 'Live · just now';

  @override
  String liveSecondsAgo(int seconds) {
    return 'Live · ${seconds}s ago';
  }

  @override
  String liveMinutesAgo(int minutes) {
    return 'Live · ${minutes}m ago';
  }

  @override
  String zoneNameActive(String name) {
    return '$name · active';
  }

  @override
  String zoneNameWithCount(String name, int count) {
    return '$name · $count zones';
  }

  @override
  String safeZonesCount(int count) {
    return '$count safe zones';
  }

  @override
  String zonesSummaryActiveCount(int count, int active) {
    return '$count zones · $active active now';
  }

  @override
  String get noZonesYet => 'No zones yet';

  @override
  String get addHomeOrSchoolHint => 'Add home or school';

  @override
  String get remindersNoneActive => 'None active';

  @override
  String remindersActiveCount(int count) {
    return '$count active';
  }

  @override
  String remindersActiveNext(int count, String title, String time) {
    return '$count active · next $title $time';
  }

  @override
  String get chargingShortSuffix => ' · charging';

  @override
  String batteryPercentLabel(int value) {
    return 'Battery $value%';
  }

  @override
  String batteryPercentCharging(int value) {
    return 'Battery $value% · charging';
  }

  @override
  String get batteryUnknown => 'Battery unknown';

  @override
  String get weakSignalRoute => 'Weak signal — route may be less accurate.';

  @override
  String get beingMonitored => 'Being monitored';

  @override
  String get locationCannotUpdate => 'Location could not be updated';

  @override
  String get adminAllChildren => 'Admin · All children';

  @override
  String waitingWithNames(String names) {
    return 'Pending · $names';
  }

  @override
  String activeWithNames(String names) {
    return 'Active · $names';
  }

  @override
  String get zeroGuardiansAdd => '0 guardians · Add guardian';

  @override
  String guardiansCountNamed(int count, String names) {
    return '$count guardians · $names';
  }

  @override
  String guardiansCountOnly(int count) {
    return '$count guardians';
  }

  @override
  String guardiansForChildTitle(String name) {
    return 'Guardians · $name';
  }

  @override
  String get noGuardiansForChild => 'No guardians for this child yet.';

  @override
  String get youBadge => 'YOU';

  @override
  String get doneAction => 'Done';

  @override
  String get editChevron => 'Edit ›';

  @override
  String get notConfiguredTapSearch => 'Not set — tap to search';

  @override
  String get noPlacesYetAddHomeSchool => 'No places yet. Add home or school.';

  @override
  String get noPlacesMatch => 'No matching places.';

  @override
  String get homePlaceLabel => 'Home';

  @override
  String get schoolPlaceLabel => 'School';

  @override
  String get parentRoleFallback => 'Parent';

  @override
  String get hereNowLabel => 'Here';

  @override
  String get waitingLocationDots => 'Waiting for location...';

  @override
  String get seenOnMap => 'Visible on map';

  @override
  String get signalStrong => 'Strong';

  @override
  String get signalMedium => 'Fair';

  @override
  String get signalWeak => 'Weak';

  @override
  String get signalLost => 'Lost';

  @override
  String get activeBadgeShort => 'LIVE';

  @override
  String get staleBadgeShort => 'STALE';

  @override
  String get batteryMetricLabel => 'Battery';

  @override
  String get signalMetricLabel => 'Signal';

  @override
  String get timeMetricLabel => 'Time';

  @override
  String get optionsTooltip => 'Options';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String relinkCodeMenu(String name) {
    return 'Relink code for $name';
  }

  @override
  String get noSignalYet => 'No signal yet';

  @override
  String updatedAtTime(String time) {
    return 'Updated $time';
  }

  @override
  String get batteryDeadBanner =>
      'Child\'s phone is nearly empty / off. Location may not update.';

  @override
  String batteryLowBanner(String level) {
    return 'Child\'s phone battery is low ($level%).';
  }

  @override
  String get locationStaleBanner =>
      'Location signal is stale. Phone may be off or offline.';

  @override
  String get screenLimitsOff => 'Limits turned off';

  @override
  String screenUsedToday(String used, String limit) {
    return '$used / $limit today';
  }

  @override
  String limitCaptionShort(String limit) {
    return 'limit $limit';
  }

  @override
  String unreadKabarCount(int count) {
    return '$count unread';
  }

  @override
  String get noTrailToday => 'No trail yet today.';

  @override
  String get safeZoneFeatureTitle => 'Safe zones';

  @override
  String get parentKabarFeatureTitle => 'Updates';

  @override
  String get remindersFeatureTitle => 'Reminders';

  @override
  String get todaySectionTitle => 'Today';

  @override
  String get safePlaceLabel => 'Safe place';

  @override
  String get placesCountLabel => 'places';

  @override
  String get girlChildLabel => 'Girl';

  @override
  String get boyChildLabel => 'Boy';

  @override
  String get noActiveAlerts => 'No active alerts';

  @override
  String get invitesSectionTitle => 'Invites';

  @override
  String childIdLabel(String id) {
    return 'Child: $id';
  }

  @override
  String get childFallbackName => 'Child';

  @override
  String get guardianFallbackName => 'Guardian';

  @override
  String get needExtraHelpNote => 'Needs additional help';

  @override
  String get resolvedByParentNote => 'Resolved by parent';

  @override
  String get sendResponseFailed => 'Failed to send response. Try again.';

  @override
  String get resolvePanicFailed => 'Failed to resolve panic. Try again.';

  @override
  String get panicBadge => 'PANIC';

  @override
  String get childInSafeZoneTitle => 'Child in safe zone';

  @override
  String get zoneUpdateTitle => 'Zone update';

  @override
  String arrivedAtZoneMsg(String childName, String zoneLabel) {
    return '$childName arrived at $zoneLabel';
  }

  @override
  String childInSafeZoneMsg(String childName) {
    return '$childName is in a safe zone';
  }

  @override
  String leftSafeZoneMsg(String childName) {
    return '$childName left a safe zone';
  }

  @override
  String get newKabarBanner => 'New update';

  @override
  String get shortTrailLabel => 'Short trail';

  @override
  String get importantPlacesLabel => 'Safe Zones';

  @override
  String get zonesHubTitle => 'Safe Zones';

  @override
  String get zonesHubSubtitle => 'Home, school, and frequently visited places';

  @override
  String get searchPlaceHint => 'Search places...';

  @override
  String get addNewPlaceLabel => 'Add new place';

  @override
  String estimateMinutes(int minutes) {
    return 'About $minutes min';
  }

  @override
  String get noAddressYet => 'No address yet';

  @override
  String get extraSafePlace => 'Additional safe place';

  @override
  String get searchHomeAddress => 'Search home address';

  @override
  String get searchSchoolName => 'Search school name';

  @override
  String searchCustomPlace(String label) {
    return 'Search place: $label';
  }

  @override
  String get homeSearchHint => 'e.g. Marine Parade, postal code, complex name';

  @override
  String get schoolSearchHint => 'e.g. Tao Nan School, school name';

  @override
  String get customSearchHint => 'e.g. tuition, mall, park, address';

  @override
  String placeSavedSnack(String name) {
    return 'Saved: $name';
  }

  @override
  String failedSavePlace(String error) {
    return 'Failed to save place: $error';
  }

  @override
  String get placeLessonSuggestion => 'Tuition place';

  @override
  String get placeGrandmaSuggestion => 'Grandparent\'s house';

  @override
  String get newPlaceDefault => 'New place';

  @override
  String get addSafePlaceTitle => 'Add safe place';

  @override
  String get customPlaceHint => 'e.g. Piano lesson Blok M';

  @override
  String get continueSearchAddress => 'Continue to search address';

  @override
  String get otherPlaceLabel => 'Other place';

  @override
  String get deletePlaceTitle => 'Delete place?';

  @override
  String deletePlaceConfirm(String name) {
    return 'Delete \"$name\"? Associated safe routes using this place will also be deleted.';
  }

  @override
  String get deletePlaceCascadeNote =>
      'Associated safe routes using this place will also be deleted.';

  @override
  String get placeDeletedSnack => 'Place deleted';

  @override
  String failedDeletePlace(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String placesForChildLabel(String name) {
    return 'Places · $name';
  }

  @override
  String get addChildBeforeInvite => 'Add a child before inviting a guardian';

  @override
  String get inviteViaWhatsApp => 'Invite via WhatsApp';

  @override
  String get inviteViaEmail => 'Invite via Email';

  @override
  String get inviteViaLink => 'Invite via Link';

  @override
  String get guardianNameLabel => 'Guardian name';

  @override
  String get phoneWhatsAppLabel => 'WhatsApp / phone number';

  @override
  String get emailOptionalLabel => 'Email (optional)';

  @override
  String get namePhoneRequired => 'Name and phone are required';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String inviteFailedDetail(String error) {
    return 'Invite failed: $error';
  }

  @override
  String failedGenericDetail(String error) {
    return 'Failed: $error';
  }

  @override
  String get guardiansInviteHint =>
      'Invite guardians you already know. No stranger search — only people you trust.';

  @override
  String get activeGuardiansSection => 'ACTIVE GUARDIANS';

  @override
  String get inviteNewSection => 'INVITE NEW GUARDIAN';

  @override
  String get addTrustedGuardian => 'Add Trusted Guardian';

  @override
  String get guardianInviteChannelHint =>
      'Create a code, then share it. The guardian installs the app, signs in as Guardian, and enters the code.';

  @override
  String guardianInviteBody(String name, String children, String link) {
    return 'Hi $name, you are invited as a Trusted Guardian for $children on PulangAman. Open invite: $link';
  }

  @override
  String guardianInviteCodeShareBody(String child, String code, String link) {
    return 'You are invited as a Trusted Guardian for $child on PulangAman.\n\n1. Install the app: $link\n2. Sign in as Guardian\n3. Enter invite code: $code';
  }

  @override
  String guardianInviteCodeTitle(String name) {
    return 'Guardian invite code for $name';
  }

  @override
  String get guardianInviteCodeBody =>
      'Ask the guardian to install PulangAman, sign in as Guardian, then enter this code under Invites.';

  @override
  String get createGuardianInviteCode => 'Create invite code';

  @override
  String get enterGuardianInviteCode => 'Enter invite code';

  @override
  String get enterGuardianInviteCodeHint =>
      'Ask the primary parent for a 6-character code';

  @override
  String guardianInviteRedeemed(String name) {
    return 'Invite accepted for $name';
  }

  @override
  String get guardianInviteInvalidCode => 'Invalid or expired invite code';

  @override
  String get guardianInviteAlreadyLinked =>
      'This account is already linked. Ask the primary parent to add more children.';

  @override
  String get guardianInviteRedeemFailed =>
      'Could not redeem invite. Try again.';

  @override
  String get shareCodeAction => 'Share code';

  @override
  String get guardianInviteSubject => 'PulangAman Trusted Guardian Invite';

  @override
  String activeGuardiansCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active guardians',
      one: '1 active guardian',
      zero: '0 active guardians',
    );
    return '$_temp0';
  }

  @override
  String get channelWhatsApp => 'WhatsApp';

  @override
  String get channelEmail => 'Email';

  @override
  String get channelLink => 'Link';

  @override
  String get justNowRelative => 'just now';

  @override
  String minutesAgoRelative(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get noLocationYet => 'No location yet';

  @override
  String get sessionTokenFailed => 'Failed to get session token. Try again.';

  @override
  String get phoneNotFoundRelogin =>
      'Phone number not found. Sign out and sign in again.';

  @override
  String get phoneInvalidFormat => 'Invalid phone number. Use format +62...';

  @override
  String get placesApiKeyHint =>
      'Needs a separate server key: enable Places API + Geocoding.';

  @override
  String get forChildLabel => 'For child';

  @override
  String get allChildrenOption => 'All children';

  @override
  String get phoneCountryCode => '+62';

  @override
  String get accessPerChildSection => 'ACCESS PER CHILD';

  @override
  String get revokeAccessTooltip => 'Revoke access';

  @override
  String get guardianAccessView => 'Guardian (view)';

  @override
  String get guardianAccessCoParent => 'Co-parent';

  @override
  String get guardianAccessSectionTitle => 'Access level';

  @override
  String get guardianAccessViewHint =>
      'Can see location and alerts. Cannot change zones, reminders, or meeting points.';

  @override
  String get guardianAccessCoParentHint =>
      'Same manage access as you for zones, reminders, Safe Home Time, and emergency meeting points. Cannot remove the child or change login codes.';

  @override
  String get coParentBadge => 'Co-parent';

  @override
  String get waliBadge => 'Guardian';

  @override
  String get promoteToCoParentTitle => 'Promote to co-parent?';

  @override
  String promoteToCoParentBody(String name) {
    return '$name will be able to edit zones, reminders, Safe Home Time, and emergency meeting points for this child.';
  }

  @override
  String get demoteToGuardianTitle => 'Change to view-only?';

  @override
  String demoteToGuardianBody(String name) {
    return '$name will keep guardian access but will no longer be able to edit zones, reminders, or meeting points.';
  }

  @override
  String get changeAccessLevel => 'Change access';

  @override
  String get confirmPromoteCoParent => 'Promote';

  @override
  String get confirmDemoteGuardian => 'Make view-only';

  @override
  String get coParentManageTitle => 'Co-parent tools';

  @override
  String get coParentManageSubtitle =>
      'Manage settings for children you co-parent';

  @override
  String get inviteAsCoParent => 'Invite as co-parent';

  @override
  String get inviteAsGuardian => 'Invite as guardian';

  @override
  String get coParentInviteLabel => 'This invite is for a co-parent';

  @override
  String fromParentWithAccess(String parent, String access) {
    return 'From $parent · $access';
  }

  @override
  String get alertAcknowledged => 'Alert acknowledged';

  @override
  String get alertAcknowledgedCascadeStopped =>
      'Alert acknowledged. Cascade stopped.';

  @override
  String alertLabelWithId(String id) {
    return 'Alert $id';
  }

  @override
  String fromParentLabel(String name) {
    return 'From $name';
  }

  @override
  String pickAvatarTitle(String name) {
    return 'Choose avatar for $name';
  }

  @override
  String get pickAvatarHint =>
      'Choose boy or girl. Child photos are not used for privacy.';

  @override
  String get changeAvatarAction => 'Change avatar';

  @override
  String get placeFriendSuggestion => 'Friend';

  @override
  String get placeMallSuggestion => 'Mall / play place';

  @override
  String get customPlaceDialogHint =>
      'Pick a type, or type your own. Then search the address.';

  @override
  String get routeBadge => 'ROUTE';

  @override
  String trailPointsCount(int count) {
    return '$count trail points';
  }

  @override
  String hoursAgoRelative(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgoRelative(int days) {
    return '${days}d ago';
  }

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String lastSeenLabel(String when) {
    return 'Last seen: $when';
  }

  @override
  String get tooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get invalidOtpCode => 'Incorrect OTP code.';

  @override
  String get otpExpiredResend => 'OTP expired. Request a new one.';

  @override
  String get appConfigIncomplete =>
      'App configuration incomplete. Contact the developer.';

  @override
  String get serverMissingCustomToken =>
      'Server did not return customToken. Deploy the latest API first.';

  @override
  String get startMonitoringAction => 'Start monitoring';

  @override
  String get openLocationAction => 'Open location';

  @override
  String get orTypeOwnNameLabel => 'Or type your own name';

  @override
  String get todayShortLabel => 'Today';

  @override
  String get thisWeekLabel => 'This week';

  @override
  String get thisMonthLabel => 'This month';

  @override
  String get weekShortLabel => 'Week';

  @override
  String get monthShortLabel => 'Month';

  @override
  String get dayShortLabel => 'Day';

  @override
  String durationMinutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get otpSendTimedOut => 'Sending the code took too long. Try again.';

  @override
  String get recoverParentsOnly => 'Only a signed-in parent can recover.';

  @override
  String get activityLoadFailed => 'Could not load today\'s history';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingMidday => 'Good afternoon';

  @override
  String get greetingAfternoon => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get periodMorningShort => 'Morning';

  @override
  String get periodMiddayShort => 'Afternoon';

  @override
  String get periodAfternoonShort => 'Evening';

  @override
  String get periodNightShort => 'Night';

  @override
  String get menuLabel => 'Menu';

  @override
  String get brandNameUpper => 'PULANGAMAN';

  @override
  String get premiumFamilyMapTitle => 'FAMILY MAP';

  @override
  String get premiumLiveLabel => 'Live';

  @override
  String get premiumFamilyMapHint => 'One stage — all children';

  @override
  String get premiumStatusSection => 'STATUS';

  @override
  String premiumGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String premiumAllChildrenSafe(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All children within safe reach.',
      one: 'One child within safe reach.',
    );
    return '$_temp0';
  }

  @override
  String premiumChildrenTracked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children being watched.',
      one: '1 child being watched.',
    );
    return '$_temp0';
  }

  @override
  String premiumBatteryLowDetail(int percent) {
    return 'Battery $percent%';
  }

  @override
  String get premiumChargeSoonMeta => 'charge soon';

  @override
  String get settingsPremiumHomeShell => 'Editorial home (Alt A)';

  @override
  String get settingsPremiumHomeShellHint =>
      'No bottom navigation bar. Turn off to restore the classic tabs.';

  @override
  String get updatedJustNowBadge => 'Updated just now';

  @override
  String updatedMinutesAgoBadge(int minutes) {
    return 'Updated ${minutes}m ago';
  }

  @override
  String updatedHoursAgoBadge(int hours) {
    return 'Updated ${hours}h ago';
  }

  @override
  String get relinkCodeShort => 'Relink code';

  @override
  String newSignInCodeTitle(String name) {
    return 'New sign-in code for $name';
  }

  @override
  String newSignInCodeBody(String name) {
    return 'Enter this code in $name\'s app when choosing \"Already have a code\" on the sign-in screen.';
  }

  @override
  String get copyCodeAction => 'Copy code';

  @override
  String get codeCopiedSnack => 'Code copied';

  @override
  String get codeValid24Hours => 'Valid for 24 hours';

  @override
  String codeValidForHours(int hours) {
    return 'Valid for $hours hours';
  }

  @override
  String codeValidForMinutes(int minutes) {
    return 'Valid for $minutes min';
  }

  @override
  String get codeExpired => 'Code expired';

  @override
  String get empQuickAccessSubtitle => 'Quick access in an emergency';

  @override
  String get reminderCoachmarkTitle => 'Try Schedule Reminders';

  @override
  String get reminderCoachmarkBody =>
      'Set routine reminders for your child — study, bedtime, or other schedules — from the More menu.';

  @override
  String get coachmarkSkip => 'Skip';

  @override
  String get coachmarkView => 'View';

  @override
  String get coParentAccessPill => 'CO-PARENT ACCESS';

  @override
  String get viewOnlyAccessPill => 'VIEW-ONLY ACCESS';

  @override
  String guardianCoParentInfoBanner(String name) {
    return 'You have co-parent access to $name. View location, manage tools below.';
  }

  @override
  String guardianViewOnlyInfoBanner(String name) {
    return 'You have view-only access to $name. See location and safety info below.';
  }

  @override
  String get sectionManageLabel => 'MANAGE';

  @override
  String get sectionViewLabel => 'VIEW';

  @override
  String get sectionAccountLabel => 'ACCOUNT';

  @override
  String get viewPillLabel => 'View';

  @override
  String get guardianAccountTitle => 'Account';

  @override
  String get guardianAccountInviteSubtitle =>
      'Enter the invite code from the primary parent to link a child';

  @override
  String get guardianNoLinkedChildren =>
      'No linked children yet. Enter an invite code to link a child.';

  @override
  String get guardianToolZonesLabel => 'Zones';

  @override
  String get guardianToolMeetingLabel => 'Meeting';

  @override
  String get guardianToolRemindersLabel => 'Reminders';

  @override
  String get guardianToolHomeTimeLabel => 'Home Time';

  @override
  String get guardianToolZonesSub => 'Safe Zones';

  @override
  String get guardianToolMeetingSub => 'EMP';

  @override
  String get guardianToolRemindersSub => 'Schedule';

  @override
  String get guardianToolHomeTimeSub => 'Safe home';

  @override
  String get guardianEmpActiveBannerTitle => 'Meeting point active';

  @override
  String get guardianEmpActiveBannerBody =>
      'Emergency meeting point is live — open for location and instructions.';
}
