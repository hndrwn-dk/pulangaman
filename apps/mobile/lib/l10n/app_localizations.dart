import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'PulangAman'**
  String get appTitle;

  /// No description provided for @homeByTitle.
  ///
  /// In id, this message translates to:
  /// **'Jam Pulang Aman'**
  String get homeByTitle;

  /// No description provided for @homeBySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pantau apakah anak sudah di rumah pada jam yang ditentukan'**
  String get homeBySubtitle;

  /// No description provided for @homeByModeOff.
  ///
  /// In id, this message translates to:
  /// **'Nonaktif'**
  String get homeByModeOff;

  /// No description provided for @homeByModeMaghrib.
  ///
  /// In id, this message translates to:
  /// **'Ikuti waktu Maghrib'**
  String get homeByModeMaghrib;

  /// No description provided for @homeByModeMaghribHint.
  ///
  /// In id, this message translates to:
  /// **'Waktu berbeda tiap hari, dihitung dari lokasi rumah'**
  String get homeByModeMaghribHint;

  /// No description provided for @homeByModeCustom.
  ///
  /// In id, this message translates to:
  /// **'Jam tetap'**
  String get homeByModeCustom;

  /// No description provided for @homeByGraceLabel.
  ///
  /// In id, this message translates to:
  /// **'Masa tenggang'**
  String get homeByGraceLabel;

  /// No description provided for @homeByGraceHint.
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit setelah jam pulang'**
  String homeByGraceHint(int minutes);

  /// No description provided for @homeByWeekendTitle.
  ///
  /// In id, this message translates to:
  /// **'Akhir pekan'**
  String get homeByWeekendTitle;

  /// No description provided for @homeByWeekendOff.
  ///
  /// In id, this message translates to:
  /// **'Nonaktifkan'**
  String get homeByWeekendOff;

  /// No description provided for @homeByWeekendSame.
  ///
  /// In id, this message translates to:
  /// **'Sama seperti hari biasa'**
  String get homeByWeekendSame;

  /// No description provided for @homeByWeekendCustom.
  ///
  /// In id, this message translates to:
  /// **'Jam berbeda'**
  String get homeByWeekendCustom;

  /// No description provided for @homeBySkipDatesTitle.
  ///
  /// In id, this message translates to:
  /// **'Hari libur'**
  String get homeBySkipDatesTitle;

  /// No description provided for @homeBySkipDatesAdd.
  ///
  /// In id, this message translates to:
  /// **'Tandai tanggal'**
  String get homeBySkipDatesAdd;

  /// No description provided for @homeBySkipDatesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada tanggal libur'**
  String get homeBySkipDatesEmpty;

  /// No description provided for @homeByTodayStatus.
  ///
  /// In id, this message translates to:
  /// **'Status hari ini'**
  String get homeByTodayStatus;

  /// No description provided for @homeByStatusPending.
  ///
  /// In id, this message translates to:
  /// **'Menunggu jam pulang'**
  String get homeByStatusPending;

  /// No description provided for @homeByStatusPreNotified.
  ///
  /// In id, this message translates to:
  /// **'Pengingat pulang dikirim ke anak'**
  String get homeByStatusPreNotified;

  /// No description provided for @homeByStatusTargetNotified.
  ///
  /// In id, this message translates to:
  /// **'Belum di rumah — orang tua sudah diberitahu'**
  String get homeByStatusTargetNotified;

  /// No description provided for @homeByStatusGraceNotified.
  ///
  /// In id, this message translates to:
  /// **'Masih belum di rumah setelah masa tenggang'**
  String get homeByStatusGraceNotified;

  /// No description provided for @homeByStatusResolved.
  ///
  /// In id, this message translates to:
  /// **'Sudah di rumah'**
  String get homeByStatusResolved;

  /// No description provided for @homeByStatusSkipped.
  ///
  /// In id, this message translates to:
  /// **'Libur / tidak dipantau hari ini'**
  String get homeByStatusSkipped;

  /// No description provided for @homeByTargetTime.
  ///
  /// In id, this message translates to:
  /// **'Jam pulang {time}'**
  String homeByTargetTime(String time);

  /// No description provided for @homeByOnceHomeNote.
  ///
  /// In id, this message translates to:
  /// **'Setelah anak tiba di rumah, pantauan hari ini selesai meski anak keluar lagi.'**
  String get homeByOnceHomeNote;

  /// No description provided for @homeBySave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get homeBySave;

  /// No description provided for @homeBySaved.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan jam pulang disimpan'**
  String get homeBySaved;

  /// No description provided for @homeBySeeAll.
  ///
  /// In id, this message translates to:
  /// **'Lihat semua'**
  String get homeBySeeAll;

  /// No description provided for @homeBySummaryOff.
  ///
  /// In id, this message translates to:
  /// **'Belum diaktifkan'**
  String get homeBySummaryOff;

  /// No description provided for @homeBySummaryMaghrib.
  ///
  /// In id, this message translates to:
  /// **'Ikuti Maghrib · {status}'**
  String homeBySummaryMaghrib(String status);

  /// No description provided for @homeBySummaryCustom.
  ///
  /// In id, this message translates to:
  /// **'Jam {time} · {status}'**
  String homeBySummaryCustom(String time, String status);

  /// No description provided for @homeByChildAckButton.
  ///
  /// In id, this message translates to:
  /// **'Aku otw pulang'**
  String get homeByChildAckButton;

  /// No description provided for @homeByChildAckSent.
  ///
  /// In id, this message translates to:
  /// **'Sudah dikirim ke orang tua'**
  String get homeByChildAckSent;

  /// No description provided for @homeByChildAckReasonInTransit.
  ///
  /// In id, this message translates to:
  /// **'Di jalan'**
  String get homeByChildAckReasonInTransit;

  /// No description provided for @homeByChildAckReasonStoppedBy.
  ///
  /// In id, this message translates to:
  /// **'Mampir dulu'**
  String get homeByChildAckReasonStoppedBy;

  /// No description provided for @homeByChildAckReasonSchool.
  ///
  /// In id, this message translates to:
  /// **'Ada kegiatan sekolah'**
  String get homeByChildAckReasonSchool;

  /// No description provided for @homeByChildAckReasonOther.
  ///
  /// In id, this message translates to:
  /// **'Lainnya'**
  String get homeByChildAckReasonOther;

  /// No description provided for @homeByChildAckNoteHint.
  ///
  /// In id, this message translates to:
  /// **'Catatan singkat (opsional)'**
  String get homeByChildAckNoteHint;

  /// No description provided for @homeByChildAckSubmit.
  ///
  /// In id, this message translates to:
  /// **'Kirim ke orang tua'**
  String get homeByChildAckSubmit;

  /// No description provided for @homeByChildAckTitle.
  ///
  /// In id, this message translates to:
  /// **'Beri kabar ke orang tua'**
  String get homeByChildAckTitle;

  /// No description provided for @homeByNoChildren.
  ///
  /// In id, this message translates to:
  /// **'Belum ada anak terhubung'**
  String get homeByNoChildren;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
