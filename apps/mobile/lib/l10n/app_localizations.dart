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

  /// No description provided for @tripSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Rute Aman'**
  String get tripSectionTitle;

  /// No description provided for @tripCreateCta.
  ///
  /// In id, this message translates to:
  /// **'Buat rute aman'**
  String get tripCreateCta;

  /// No description provided for @tripSuggestSchoolHome.
  ///
  /// In id, this message translates to:
  /// **'Sekolah → Rumah'**
  String get tripSuggestSchoolHome;

  /// No description provided for @tripPickFrom.
  ///
  /// In id, this message translates to:
  /// **'Dari'**
  String get tripPickFrom;

  /// No description provided for @tripPickTo.
  ///
  /// In id, this message translates to:
  /// **'Ke'**
  String get tripPickTo;

  /// No description provided for @tripCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat rute'**
  String get tripCreate;

  /// No description provided for @tripStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai pantau'**
  String get tripStart;

  /// No description provided for @tripCancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan'**
  String get tripCancel;

  /// No description provided for @tripActive.
  ///
  /// In id, this message translates to:
  /// **'Dalam perjalanan'**
  String get tripActive;

  /// No description provided for @tripPlanned.
  ///
  /// In id, this message translates to:
  /// **'Direncanakan'**
  String get tripPlanned;

  /// No description provided for @tripArrived.
  ///
  /// In id, this message translates to:
  /// **'Sudah sampai'**
  String get tripArrived;

  /// No description provided for @tripNeedTwoPlaces.
  ///
  /// In id, this message translates to:
  /// **'Tambah minimal dua tempat dulu'**
  String get tripNeedTwoPlaces;

  /// No description provided for @tripNeedDistinct.
  ///
  /// In id, this message translates to:
  /// **'Asal dan tujuan harus berbeda'**
  String get tripNeedDistinct;

  /// No description provided for @tripCreated.
  ///
  /// In id, this message translates to:
  /// **'Rute aman dibuat'**
  String get tripCreated;

  /// No description provided for @tripChildStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai perjalanan'**
  String get tripChildStart;

  /// No description provided for @tripChildPickDest.
  ///
  /// In id, this message translates to:
  /// **'Pilih tujuan'**
  String get tripChildPickDest;

  /// No description provided for @tripChildActiveTo.
  ///
  /// In id, this message translates to:
  /// **'Menuju {place}'**
  String tripChildActiveTo(String place);

  /// No description provided for @tripChildCancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan perjalanan'**
  String get tripChildCancel;

  /// No description provided for @tripProgressMeta.
  ///
  /// In id, this message translates to:
  /// **'{distance} · {eta}'**
  String tripProgressMeta(String distance, String eta);

  /// No description provided for @empTitle.
  ///
  /// In id, this message translates to:
  /// **'Titik Kumpul Darurat'**
  String get empTitle;

  /// No description provided for @empSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Tempat bertemu saat kondisi darurat'**
  String get empSubtitle;

  /// No description provided for @empEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada titik kumpul untuk {childName}'**
  String empEmpty(String childName);

  /// No description provided for @empEmptyGeneric.
  ///
  /// In id, this message translates to:
  /// **'Belum ada titik kumpul'**
  String get empEmptyGeneric;

  /// No description provided for @empLoadError.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat titik kumpul'**
  String get empLoadError;

  /// No description provided for @empRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get empRetry;

  /// No description provided for @empAdd.
  ///
  /// In id, this message translates to:
  /// **'+ Tambah titik kumpul'**
  String get empAdd;

  /// No description provided for @empAddBackup.
  ///
  /// In id, this message translates to:
  /// **'Titik cadangan'**
  String get empAddBackup;

  /// No description provided for @empPrimaryLabel.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul utama'**
  String get empPrimaryLabel;

  /// No description provided for @empPrimary.
  ///
  /// In id, this message translates to:
  /// **'Utama'**
  String get empPrimary;

  /// No description provided for @empBackup.
  ///
  /// In id, this message translates to:
  /// **'Cadangan'**
  String get empBackup;

  /// No description provided for @empInstructionsHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Kalau kondisi darurat dan gak bisa saling hubungi, ketemu di sini'**
  String get empInstructionsHint;

  /// No description provided for @empNameHint.
  ///
  /// In id, this message translates to:
  /// **'Nama tempat (mis. Rumah Nenek)'**
  String get empNameHint;

  /// No description provided for @empSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get empSave;

  /// No description provided for @empDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get empDelete;

  /// No description provided for @empDeleteConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus titik kumpul untuk semua anak?'**
  String get empDeleteConfirm;

  /// No description provided for @empEdit.
  ///
  /// In id, this message translates to:
  /// **'Ubah titik kumpul'**
  String get empEdit;

  /// No description provided for @empMapPreview.
  ///
  /// In id, this message translates to:
  /// **'Preview peta'**
  String get empMapPreview;

  /// No description provided for @empApplyToOthers.
  ///
  /// In id, this message translates to:
  /// **'Terapkan ke anak lain juga?'**
  String get empApplyToOthers;

  /// No description provided for @empApply.
  ///
  /// In id, this message translates to:
  /// **'Terapkan'**
  String get empApply;

  /// No description provided for @empActivate.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan titik kumpul'**
  String get empActivate;

  /// No description provided for @empActivateConfirm.
  ///
  /// In id, this message translates to:
  /// **'Semua anak dan wali akan dapat notifikasi untuk segera menuju titik kumpul masing-masing. Lanjutkan?'**
  String get empActivateConfirm;

  /// No description provided for @empActivateNoteHint.
  ///
  /// In id, this message translates to:
  /// **'Catatan singkat (opsional)'**
  String get empActivateNoteHint;

  /// No description provided for @empActivateContinue.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan sekarang'**
  String get empActivateContinue;

  /// No description provided for @empActivateCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get empActivateCancel;

  /// No description provided for @empActivateCaption.
  ///
  /// In id, this message translates to:
  /// **'Berlaku untuk {names}, juga wali mereka'**
  String empActivateCaption(String names);

  /// No description provided for @empSummarySent.
  ///
  /// In id, this message translates to:
  /// **'Terkirim ke {count} anak'**
  String empSummarySent(int count);

  /// No description provided for @empSummarySkipped.
  ///
  /// In id, this message translates to:
  /// **'{childName} belum punya titik kumpul'**
  String empSummarySkipped(String childName);

  /// No description provided for @empRateLimited.
  ///
  /// In id, this message translates to:
  /// **'Aktivasi dibatasi — coba lagi nanti'**
  String get empRateLimited;

  /// No description provided for @empOpenMaps.
  ///
  /// In id, this message translates to:
  /// **'Buka di Peta'**
  String get empOpenMaps;

  /// No description provided for @empDistanceUnknown.
  ///
  /// In id, this message translates to:
  /// **'Jarak belum diketahui'**
  String get empDistanceUnknown;

  /// No description provided for @empDistanceLive.
  ///
  /// In id, this message translates to:
  /// **'{childName} sekarang {distance} dari sini'**
  String empDistanceLive(String childName, String distance);

  /// No description provided for @empDistanceFromChild.
  ///
  /// In id, this message translates to:
  /// **'Jarak anak: {distance}'**
  String empDistanceFromChild(String distance);

  /// No description provided for @empAlertTitle.
  ///
  /// In id, this message translates to:
  /// **'Titik Kumpul Darurat'**
  String get empAlertTitle;

  /// No description provided for @empAlertBody.
  ///
  /// In id, this message translates to:
  /// **'Segera menuju {place}'**
  String empAlertBody(String place);

  /// No description provided for @empMyDistance.
  ///
  /// In id, this message translates to:
  /// **'Jarakmu: {distance}'**
  String empMyDistance(String distance);

  /// No description provided for @empActiveTitle.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul sedang aktif'**
  String get empActiveTitle;

  /// No description provided for @empActiveSince.
  ///
  /// In id, this message translates to:
  /// **'Diaktifkan {time}'**
  String empActiveSince(String time);

  /// No description provided for @empArrived.
  ///
  /// In id, this message translates to:
  /// **'Sudah sampai'**
  String get empArrived;

  /// No description provided for @empOnTheWay.
  ///
  /// In id, this message translates to:
  /// **'Masih di jalan'**
  String get empOnTheWay;

  /// No description provided for @empChildLocationUnknown.
  ///
  /// In id, this message translates to:
  /// **'Lokasi belum diketahui'**
  String get empChildLocationUnknown;

  /// No description provided for @empActiveNoPoint.
  ///
  /// In id, this message translates to:
  /// **'Belum punya titik kumpul'**
  String get empActiveNoPoint;

  /// No description provided for @empRefresh.
  ///
  /// In id, this message translates to:
  /// **'Perbarui'**
  String get empRefresh;

  /// No description provided for @empDeactivate.
  ///
  /// In id, this message translates to:
  /// **'Matikan titik kumpul'**
  String get empDeactivate;

  /// No description provided for @empDeactivateConfirm.
  ///
  /// In id, this message translates to:
  /// **'Matikan titik kumpul darurat? Anak dan wali akan diberi tahu kalau kondisi darurat sudah selesai.'**
  String get empDeactivateConfirm;

  /// No description provided for @empDeactivated.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul dinonaktifkan'**
  String get empDeactivated;

  /// No description provided for @empMenuHint.
  ///
  /// In id, this message translates to:
  /// **'Titik bertemu saat darurat'**
  String get empMenuHint;

  /// No description provided for @empPickPlace.
  ///
  /// In id, this message translates to:
  /// **'Cari lokasi titik kumpul'**
  String get empPickPlace;

  /// No description provided for @empNoChildren.
  ///
  /// In id, this message translates to:
  /// **'Belum ada anak terhubung'**
  String get empNoChildren;
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
