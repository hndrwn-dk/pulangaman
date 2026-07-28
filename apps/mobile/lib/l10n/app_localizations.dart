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

  /// No description provided for @homeBySummaryNotTurnedOn.
  ///
  /// In id, this message translates to:
  /// **'Belum dinyalakan'**
  String get homeBySummaryNotTurnedOn;

  /// No description provided for @homeBySummaryMaghrib.
  ///
  /// In id, this message translates to:
  /// **'Mode Maghrib dipilih · {status}'**
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
  /// **'Tambah minimal dua lokasi dulu'**
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
  /// **'Lokasi bertemu saat kondisi darurat'**
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
  /// **'Nama lokasi (mis. Rumah Nenek)'**
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

  /// No description provided for @listAnd.
  ///
  /// In id, this message translates to:
  /// **'dan'**
  String get listAnd;

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

  /// No description provided for @settingsSectionApp.
  ///
  /// In id, this message translates to:
  /// **'Aplikasi'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In id, this message translates to:
  /// **'Akun'**
  String get settingsSectionAccount;

  /// No description provided for @settingsLanguage.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In id, this message translates to:
  /// **'Pilih bahasa tampilan aplikasi'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageId.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get settingsLanguageId;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsAbout.
  ///
  /// In id, this message translates to:
  /// **'Tentang'**
  String get settingsAbout;

  /// No description provided for @settingsAboutHint.
  ///
  /// In id, this message translates to:
  /// **'Bagikan, nilai, dan info aplikasi'**
  String get settingsAboutHint;

  /// No description provided for @settingsVersion.
  ///
  /// In id, this message translates to:
  /// **'Versi'**
  String get settingsVersion;

  /// No description provided for @settingsVersionValue.
  ///
  /// In id, this message translates to:
  /// **'{version} ({build})'**
  String settingsVersionValue(String version, String build);

  /// No description provided for @settingsShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan aplikasi ini'**
  String get settingsShare;

  /// No description provided for @settingsShareHint.
  ///
  /// In id, this message translates to:
  /// **'Ajak keluarga mencoba PulangAman'**
  String get settingsShareHint;

  /// No description provided for @settingsShareMessage.
  ///
  /// In id, this message translates to:
  /// **'Coba PulangAman — jaringan keselamatan untuk orang tua dan anak.\nhttps://www.tursinalabs.com'**
  String get settingsShareMessage;

  /// No description provided for @settingsRate.
  ///
  /// In id, this message translates to:
  /// **'Nilai aplikasi ini'**
  String get settingsRate;

  /// No description provided for @settingsRateHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis ulasan di Google Play'**
  String get settingsRateHint;

  /// No description provided for @settingsPrivacy.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan Privasi'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyHint.
  ///
  /// In id, this message translates to:
  /// **'Baca kebijakan privasi kami'**
  String get settingsPrivacyHint;

  /// No description provided for @settingsTerms.
  ///
  /// In id, this message translates to:
  /// **'Syarat & Ketentuan'**
  String get settingsTerms;

  /// No description provided for @settingsTermsHint.
  ///
  /// In id, this message translates to:
  /// **'Baca syarat penggunaan kami'**
  String get settingsTermsHint;

  /// No description provided for @settingsNotifications.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In id, this message translates to:
  /// **'Kabar, SOS, dan zona aman'**
  String get settingsNotificationsHint;

  /// No description provided for @brand.
  ///
  /// In id, this message translates to:
  /// **'Pulang Aman'**
  String get brand;

  /// No description provided for @tagline.
  ///
  /// In id, this message translates to:
  /// **'Pulang dengan tenang, sampai dengan aman.'**
  String get tagline;

  /// No description provided for @roleParent.
  ///
  /// In id, this message translates to:
  /// **'Saya orang tua'**
  String get roleParent;

  /// No description provided for @roleChild.
  ///
  /// In id, this message translates to:
  /// **'Saya anak'**
  String get roleChild;

  /// No description provided for @roleGuardian.
  ///
  /// In id, this message translates to:
  /// **'Saya wali terpercaya'**
  String get roleGuardian;

  /// No description provided for @roleLabel.
  ///
  /// In id, this message translates to:
  /// **'Peran'**
  String get roleLabel;

  /// No description provided for @roleParentShort.
  ///
  /// In id, this message translates to:
  /// **'Orang Tua'**
  String get roleParentShort;

  /// No description provided for @roleChildShort.
  ///
  /// In id, this message translates to:
  /// **'Anak'**
  String get roleChildShort;

  /// No description provided for @roleGuardianShort.
  ///
  /// In id, this message translates to:
  /// **'Wali'**
  String get roleGuardianShort;

  /// No description provided for @continueLabel.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get continueLabel;

  /// No description provided for @loginTitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get loginTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In id, this message translates to:
  /// **'Nomor telepon'**
  String get phoneLabel;

  /// No description provided for @nameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In id, this message translates to:
  /// **'Masukkan nama lengkap'**
  String get nameHint;

  /// No description provided for @phoneHint.
  ///
  /// In id, this message translates to:
  /// **'+62812...'**
  String get phoneHint;

  /// No description provided for @loginAction.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get loginAction;

  /// No description provided for @otpLabel.
  ///
  /// In id, this message translates to:
  /// **'Kode OTP'**
  String get otpLabel;

  /// No description provided for @otpHint.
  ///
  /// In id, this message translates to:
  /// **'6 digit dari SMS'**
  String get otpHint;

  /// No description provided for @otpSentHint.
  ///
  /// In id, this message translates to:
  /// **'Kode verifikasi dikirim ke nomor Anda'**
  String get otpSentHint;

  /// No description provided for @verifyOtpAction.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi'**
  String get verifyOtpAction;

  /// No description provided for @otpVerifyingHint.
  ///
  /// In id, this message translates to:
  /// **'Memverifikasi kode. Mohon tunggu sebentar.'**
  String get otpVerifyingHint;

  /// No description provided for @otpSendingHint.
  ///
  /// In id, this message translates to:
  /// **'Mengirim kode verifikasi. Mohon tunggu…'**
  String get otpSendingHint;

  /// No description provided for @resendOtp.
  ///
  /// In id, this message translates to:
  /// **'Kirim ulang kode'**
  String get resendOtp;

  /// No description provided for @changeNumber.
  ///
  /// In id, this message translates to:
  /// **'Ubah nomor'**
  String get changeNumber;

  /// No description provided for @sendOtpAction.
  ///
  /// In id, this message translates to:
  /// **'Kirim kode OTP'**
  String get sendOtpAction;

  /// No description provided for @inviteCodeHintChild.
  ///
  /// In id, this message translates to:
  /// **'Minta kode 6 digit dari orang tua'**
  String get inviteCodeHintChild;

  /// No description provided for @connecting.
  ///
  /// In id, this message translates to:
  /// **'Menghubungkan...'**
  String get connecting;

  /// No description provided for @sending.
  ///
  /// In id, this message translates to:
  /// **'Mengirim...'**
  String get sending;

  /// No description provided for @featureCheckIn.
  ///
  /// In id, this message translates to:
  /// **'Check-in'**
  String get featureCheckIn;

  /// No description provided for @featureRewards.
  ///
  /// In id, this message translates to:
  /// **'Hadiah'**
  String get featureRewards;

  /// No description provided for @featureScreenTime.
  ///
  /// In id, this message translates to:
  /// **'Waktu Layar'**
  String get featureScreenTime;

  /// No description provided for @childrenTitle.
  ///
  /// In id, this message translates to:
  /// **'Anak saya'**
  String get childrenTitle;

  /// No description provided for @addChild.
  ///
  /// In id, this message translates to:
  /// **'Undang anak'**
  String get addChild;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In id, this message translates to:
  /// **'Kode undangan'**
  String get inviteCodeLabel;

  /// No description provided for @createInvite.
  ///
  /// In id, this message translates to:
  /// **'Buat kode undangan'**
  String get createInvite;

  /// No description provided for @inviteShareHint.
  ///
  /// In id, this message translates to:
  /// **'Bagikan kode ini ke HP anak. Berlaku 24 jam.'**
  String get inviteShareHint;

  /// No description provided for @liveMap.
  ///
  /// In id, this message translates to:
  /// **'Peta langsung'**
  String get liveMap;

  /// No description provided for @zonesTitle.
  ///
  /// In id, this message translates to:
  /// **'Zona Aman'**
  String get zonesTitle;

  /// No description provided for @guardiansTitle.
  ///
  /// In id, this message translates to:
  /// **'Wali terpercaya'**
  String get guardiansTitle;

  /// No description provided for @panicButton.
  ///
  /// In id, this message translates to:
  /// **'TOMBOL PANIK'**
  String get panicButton;

  /// No description provided for @panicConfirm.
  ///
  /// In id, this message translates to:
  /// **'Ketuk 3 kali untuk mengirim peringatan'**
  String get panicConfirm;

  /// No description provided for @panicHoldConfirm.
  ///
  /// In id, this message translates to:
  /// **'Tekan & tahan 3 detik untuk kirim peringatan'**
  String get panicHoldConfirm;

  /// No description provided for @panicSent.
  ///
  /// In id, this message translates to:
  /// **'Peringatan panik terkirim'**
  String get panicSent;

  /// No description provided for @trackingOn.
  ///
  /// In id, this message translates to:
  /// **'Pelacakan aktif'**
  String get trackingOn;

  /// No description provided for @bgLocationDisclosureTitle.
  ///
  /// In id, this message translates to:
  /// **'Kenapa butuh akses lokasi selalu?'**
  String get bgLocationDisclosureTitle;

  /// No description provided for @bgLocationDisclosureBody.
  ///
  /// In id, this message translates to:
  /// **'Biar orang tua bisa lihat lokasi kamu dan dapat kabar zona aman meskipun aplikasi ditutup.'**
  String get bgLocationDisclosureBody;

  /// No description provided for @bgLocationDisclosureContinue.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get bgLocationDisclosureContinue;

  /// No description provided for @trackingOff.
  ///
  /// In id, this message translates to:
  /// **'Pelacakan berhenti'**
  String get trackingOff;

  /// No description provided for @staleLocation.
  ///
  /// In id, this message translates to:
  /// **'Lokasi anak tidak diperbarui'**
  String get staleLocation;

  /// No description provided for @ackAlert.
  ///
  /// In id, this message translates to:
  /// **'Saya sudah merespons'**
  String get ackAlert;

  /// No description provided for @resolveAlert.
  ///
  /// In id, this message translates to:
  /// **'Selesai / aman'**
  String get resolveAlert;

  /// No description provided for @inviteGuardian.
  ///
  /// In id, this message translates to:
  /// **'Undang wali'**
  String get inviteGuardian;

  /// No description provided for @acceptInvite.
  ///
  /// In id, this message translates to:
  /// **'Terima undangan'**
  String get acceptInvite;

  /// No description provided for @shareLocation.
  ///
  /// In id, this message translates to:
  /// **'Bagikan lokasi saya'**
  String get shareLocation;

  /// No description provided for @needBackup.
  ///
  /// In id, this message translates to:
  /// **'Butuh bantuan cadangan'**
  String get needBackup;

  /// No description provided for @guardianGuidance.
  ///
  /// In id, this message translates to:
  /// **'Hubungi orang tua atau layanan darurat. Jangan mengejar orang asing.'**
  String get guardianGuidance;

  /// No description provided for @offlineQueued.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan offline — akan dikirim saat online'**
  String get offlineQueued;

  /// No description provided for @homeZone.
  ///
  /// In id, this message translates to:
  /// **'Rumah'**
  String get homeZone;

  /// No description provided for @schoolZone.
  ///
  /// In id, this message translates to:
  /// **'Sekolah'**
  String get schoolZone;

  /// No description provided for @save.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get save;

  /// No description provided for @logout.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @emergencyContacts.
  ///
  /// In id, this message translates to:
  /// **'Kontak darurat'**
  String get emergencyContacts;

  /// No description provided for @noChildren.
  ///
  /// In id, this message translates to:
  /// **'Belum ada anak terhubung'**
  String get noChildren;

  /// No description provided for @noInvites.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada undangan'**
  String get noInvites;

  /// No description provided for @activeAlerts.
  ///
  /// In id, this message translates to:
  /// **'Peringatan aktif'**
  String get activeAlerts;

  /// No description provided for @mapKeyMissing.
  ///
  /// In id, this message translates to:
  /// **'Peta Google belum dikonfigurasi. Tambahkan GOOGLE_MAPS_API_KEY di android/local.properties lalu rebuild.'**
  String get mapKeyMissing;

  /// No description provided for @lastKnownCoords.
  ///
  /// In id, this message translates to:
  /// **'Koordinat terakhir'**
  String get lastKnownCoords;

  /// No description provided for @childTabHome.
  ///
  /// In id, this message translates to:
  /// **'Beranda'**
  String get childTabHome;

  /// No description provided for @childTabScreen.
  ///
  /// In id, this message translates to:
  /// **'Layar'**
  String get childTabScreen;

  /// No description provided for @childTabMessages.
  ///
  /// In id, this message translates to:
  /// **'Kabar'**
  String get childTabMessages;

  /// No description provided for @childMessageSent.
  ///
  /// In id, this message translates to:
  /// **'Kabar terkirim'**
  String get childMessageSent;

  /// No description provided for @childMessageFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengirim kabar. Coba lagi.'**
  String get childMessageFailed;

  /// No description provided for @errorWithDetail.
  ///
  /// In id, this message translates to:
  /// **'Gagal: {error}'**
  String errorWithDetail(String error);

  /// No description provided for @panicAckedByParent.
  ///
  /// In id, this message translates to:
  /// **'Orang tua sudah merespons panik'**
  String get panicAckedByParent;

  /// No description provided for @panicResolvedSafe.
  ///
  /// In id, this message translates to:
  /// **'Panik ditandai selesai / aman'**
  String get panicResolvedSafe;

  /// No description provided for @panicConfirmCount.
  ///
  /// In id, this message translates to:
  /// **'Ketuk 3 kali untuk mengirim peringatan ({count}/3)'**
  String panicConfirmCount(int count);

  /// No description provided for @panicSendFailedRetrying.
  ///
  /// In id, this message translates to:
  /// **'Gagal kirim panik. Dicoba lagi otomatis.'**
  String get panicSendFailedRetrying;

  /// No description provided for @smsFallbackPanicBody.
  ///
  /// In id, this message translates to:
  /// **'PulangAman PANIK — butuh bantuan sekarang.'**
  String get smsFallbackPanicBody;

  /// No description provided for @empDefaultPlaceName.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul'**
  String get empDefaultPlaceName;

  /// No description provided for @empAlertBodyWithNote.
  ///
  /// In id, this message translates to:
  /// **'{note} — menuju {place}'**
  String empAlertBodyWithNote(String note, String place);

  /// No description provided for @empAlertBodyPlain.
  ///
  /// In id, this message translates to:
  /// **'Segera menuju titik kumpul: {place}'**
  String empAlertBodyPlain(String place);

  /// No description provided for @homeByPreviewTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktunya pulang'**
  String get homeByPreviewTitle;

  /// No description provided for @homeByPreviewBody.
  ///
  /// In id, this message translates to:
  /// **'{name}, sebentar lagi waktu pulang ya'**
  String homeByPreviewBody(String name);

  /// No description provided for @greetingDefaultName.
  ///
  /// In id, this message translates to:
  /// **'Sahabat'**
  String get greetingDefaultName;

  /// No description provided for @homeByDefaultChildName.
  ///
  /// In id, this message translates to:
  /// **'Anak'**
  String get homeByDefaultChildName;

  /// No description provided for @tripNotEnoughPlaces.
  ///
  /// In id, this message translates to:
  /// **'Belum ada cukup lokasi tersimpan'**
  String get tripNotEnoughPlaces;

  /// No description provided for @zoneGenericLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi'**
  String get zoneGenericLabel;

  /// No description provided for @startAction.
  ///
  /// In id, this message translates to:
  /// **'Mulai'**
  String get startAction;

  /// No description provided for @tripArrivedNotified.
  ///
  /// In id, this message translates to:
  /// **'Tiba di {place} — ortu sudah diberitahu'**
  String tripArrivedNotified(String place);

  /// No description provided for @destinationFallback.
  ///
  /// In id, this message translates to:
  /// **'tujuan'**
  String get destinationFallback;

  /// No description provided for @locationSendFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal kirim lokasi'**
  String get locationSendFailed;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In id, this message translates to:
  /// **'Izin lokasi ditolak'**
  String get locationPermissionDenied;

  /// No description provided for @sessionNotReady.
  ///
  /// In id, this message translates to:
  /// **'Sesi belum siap'**
  String get sessionNotReady;

  /// No description provided for @allowExactAlarmMessage.
  ///
  /// In id, this message translates to:
  /// **'Izinkan alarm tepat waktu agar pengingat ortu muncul.'**
  String get allowExactAlarmMessage;

  /// No description provided for @openAction.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get openAction;

  /// No description provided for @trackingOnNeedsAlways.
  ///
  /// In id, this message translates to:
  /// **'Lokasi aktif — izinkan \"Selalu\" agar tetap jalan di background'**
  String get trackingOnNeedsAlways;

  /// No description provided for @refreshTooltip.
  ///
  /// In id, this message translates to:
  /// **'Segarkan (kirim daftar app & aturan)'**
  String get refreshTooltip;

  /// No description provided for @refreshSentWithApps.
  ///
  /// In id, this message translates to:
  /// **'Lokasi & daftar app dikirim ke ortu'**
  String get refreshSentWithApps;

  /// No description provided for @refreshSentNoApps.
  ///
  /// In id, this message translates to:
  /// **'Lokasi dikirim. Daftar app kosong — cek izin Usage Access.'**
  String get refreshSentNoApps;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari akun anak?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In id, this message translates to:
  /// **'Untuk masuk lagi, minta kode masuk ulang dari HP ortu.'**
  String get logoutConfirmBody;

  /// No description provided for @childMessageSentWithLabel.
  ///
  /// In id, this message translates to:
  /// **'Kabar terkirim: {label}'**
  String childMessageSentWithLabel(String label);

  /// No description provided for @homeSubtitleTagline.
  ///
  /// In id, this message translates to:
  /// **'Tetap aman, kumpulkan poin, dan beri kabar keluarga.'**
  String get homeSubtitleTagline;

  /// No description provided for @pillLocationOn.
  ///
  /// In id, this message translates to:
  /// **'Lokasi aktif'**
  String get pillLocationOn;

  /// No description provided for @pillLocationOff.
  ///
  /// In id, this message translates to:
  /// **'Lokasi mati'**
  String get pillLocationOff;

  /// No description provided for @pointsStreakLabel.
  ///
  /// In id, this message translates to:
  /// **'{points} poin · {streak} hari'**
  String pointsStreakLabel(int points, int streak);

  /// No description provided for @screenRulesActive.
  ///
  /// In id, this message translates to:
  /// **'Aturan layar aktif'**
  String get screenRulesActive;

  /// No description provided for @screenPermissionIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Izin layar belum lengkap'**
  String get screenPermissionIncomplete;

  /// No description provided for @alarmPermissionIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Izin alarm belum lengkap'**
  String get alarmPermissionIncomplete;

  /// No description provided for @reminderActiveCount.
  ///
  /// In id, this message translates to:
  /// **'Pengingat aktif ({count})'**
  String reminderActiveCount(int count);

  /// No description provided for @noRemindersYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada pengingat'**
  String get noRemindersYet;

  /// No description provided for @sendingAlert.
  ///
  /// In id, this message translates to:
  /// **'Mengirim peringatan...'**
  String get sendingAlert;

  /// No description provided for @panicCooldownMessage.
  ///
  /// In id, this message translates to:
  /// **'Panik terkirim. Tunggu sebentar sebelum bisa dikirim lagi.'**
  String get panicCooldownMessage;

  /// No description provided for @panicModeActiveWaiting.
  ///
  /// In id, this message translates to:
  /// **'Mode panik aktif — menunggu respons orang tua'**
  String get panicModeActiveWaiting;

  /// No description provided for @enableScreenProtectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan perlindungan waktu layar'**
  String get enableScreenProtectionTitle;

  /// No description provided for @neverBlockedAppsNote.
  ///
  /// In id, this message translates to:
  /// **'PulangAman, Telepon, dan Pesan tidak pernah diblokir.'**
  String get neverBlockedAppsNote;

  /// No description provided for @allowUsageAccess.
  ///
  /// In id, this message translates to:
  /// **'Izinkan akses pemakaian'**
  String get allowUsageAccess;

  /// No description provided for @enableAppBlocking.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan pemblokiran aplikasi'**
  String get enableAppBlocking;

  /// No description provided for @restrictedSettingsHelp.
  ///
  /// In id, this message translates to:
  /// **'Tombolnya terkunci (\"Setelan dibatasi\")? Buka Info aplikasi, ketuk menu titik tiga di kanan atas, lalu pilih \"Izinkan setelan yang dibatasi\". Setelah itu coba lagi.'**
  String get restrictedSettingsHelp;

  /// No description provided for @openAppInfo.
  ///
  /// In id, this message translates to:
  /// **'Buka Info aplikasi'**
  String get openAppInfo;

  /// No description provided for @empActiveNowLabel.
  ///
  /// In id, this message translates to:
  /// **'Darurat — segera ke sini'**
  String get empActiveNowLabel;

  /// No description provided for @empFamilyMeetingPoint.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul keluarga'**
  String get empFamilyMeetingPoint;

  /// No description provided for @followParentInstructions.
  ///
  /// In id, this message translates to:
  /// **'Ikuti arahan orang tua'**
  String get followParentInstructions;

  /// No description provided for @memorizeEmpPlace.
  ///
  /// In id, this message translates to:
  /// **'Hafalkan lokasi ini untuk kondisi darurat'**
  String get memorizeEmpPlace;

  /// No description provided for @tripArrivedAt.
  ///
  /// In id, this message translates to:
  /// **'Tiba di {place}'**
  String tripArrivedAt(String place);

  /// No description provided for @tripRouteReady.
  ///
  /// In id, this message translates to:
  /// **'Rute siap'**
  String get tripRouteReady;

  /// No description provided for @tripGenericLabel.
  ///
  /// In id, this message translates to:
  /// **'Perjalanan'**
  String get tripGenericLabel;

  /// No description provided for @tripParentNotified.
  ///
  /// In id, this message translates to:
  /// **'Orang tua sudah diberi tahu'**
  String get tripParentNotified;

  /// No description provided for @tripReadyToStart.
  ///
  /// In id, this message translates to:
  /// **'Siap dimulai'**
  String get tripReadyToStart;

  /// No description provided for @tripInProgress.
  ///
  /// In id, this message translates to:
  /// **'Sedang berjalan'**
  String get tripInProgress;

  /// No description provided for @tripChooseSafeDestination.
  ///
  /// In id, this message translates to:
  /// **'Pilih tujuan aman ke lokasi tersimpan'**
  String get tripChooseSafeDestination;

  /// No description provided for @screenTimeToday.
  ///
  /// In id, this message translates to:
  /// **'Layar hari ini'**
  String get screenTimeToday;

  /// No description provided for @yourPoints.
  ///
  /// In id, this message translates to:
  /// **'Poin kamu'**
  String get yourPoints;

  /// No description provided for @kabarTitle.
  ///
  /// In id, this message translates to:
  /// **'Kabar ke ortu'**
  String get kabarTitle;

  /// No description provided for @kabarSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Ketuk sekali — pesan langsung terkirim.'**
  String get kabarSubtitle;

  /// No description provided for @kabarInfoNote.
  ///
  /// In id, this message translates to:
  /// **'Pesan dikirim ke orang tua yang terhubung. Untuk darurat, gunakan tombol panik di Beranda.'**
  String get kabarInfoNote;

  /// No description provided for @kabarHeroTitle.
  ///
  /// In id, this message translates to:
  /// **'Kirim kabar cepat'**
  String get kabarHeroTitle;

  /// No description provided for @kabarHeroSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Tidak perlu mengetik. Pilih salah satu pesan di bawah.'**
  String get kabarHeroSubtitle;

  /// No description provided for @presetAtSchoolLabel.
  ///
  /// In id, this message translates to:
  /// **'Sudah sampai sekolah'**
  String get presetAtSchoolLabel;

  /// No description provided for @presetAtSchoolSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Beri tahu ortu kamu sudah aman di sekolah'**
  String get presetAtSchoolSubtitle;

  /// No description provided for @presetAtHomeLabel.
  ///
  /// In id, this message translates to:
  /// **'Sudah di rumah'**
  String get presetAtHomeLabel;

  /// No description provided for @presetAtHomeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kabari kalau kamu sudah pulang'**
  String get presetAtHomeSubtitle;

  /// No description provided for @presetNeedHelpLabel.
  ///
  /// In id, this message translates to:
  /// **'Butuh bantuan'**
  String get presetNeedHelpLabel;

  /// No description provided for @presetNeedHelpSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Minta ortu segera menghubungi kamu'**
  String get presetNeedHelpSubtitle;

  /// No description provided for @screenTimeTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktu layar'**
  String get screenTimeTitle;

  /// No description provided for @screenTimeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Lihat berapa lama kamu main HP hari ini.'**
  String get screenTimeSubtitle;

  /// No description provided for @screenTimeOverTargetStatus.
  ///
  /// In id, this message translates to:
  /// **'{period} · lewat target'**
  String screenTimeOverTargetStatus(String period);

  /// No description provided for @appsLabel.
  ///
  /// In id, this message translates to:
  /// **'Aplikasi'**
  String get appsLabel;

  /// No description provided for @appCountLabel.
  ///
  /// In id, this message translates to:
  /// **'{count} app'**
  String appCountLabel(int count);

  /// No description provided for @usageAccessInactiveTitle.
  ///
  /// In id, this message translates to:
  /// **'Akses pemakaian belum aktif'**
  String get usageAccessInactiveTitle;

  /// No description provided for @usageAccessInactiveBody.
  ///
  /// In id, this message translates to:
  /// **'Izinkan PulangAman melihat pemakaian layar agar statistik muncul di sini.'**
  String get usageAccessInactiveBody;

  /// No description provided for @openPermissionSettings.
  ///
  /// In id, this message translates to:
  /// **'Buka pengaturan izin'**
  String get openPermissionSettings;

  /// No description provided for @totalLabel.
  ///
  /// In id, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @targetLabel.
  ///
  /// In id, this message translates to:
  /// **'Target'**
  String get targetLabel;

  /// No description provided for @noDataYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data'**
  String get noDataYet;

  /// No description provided for @useAsUsualStatsAppear.
  ///
  /// In id, this message translates to:
  /// **'Gunakan HP seperti biasa — statistik akan muncul di sini.'**
  String get useAsUsualStatsAppear;

  /// No description provided for @delete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get add;

  /// No description provided for @understood.
  ///
  /// In id, this message translates to:
  /// **'Mengerti'**
  String get understood;

  /// No description provided for @editAction.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get editAction;

  /// No description provided for @retryAction.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get retryAction;

  /// No description provided for @okAction.
  ///
  /// In id, this message translates to:
  /// **'OK'**
  String get okAction;

  /// No description provided for @closeAction.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get closeAction;

  /// No description provided for @viewAllAction.
  ///
  /// In id, this message translates to:
  /// **'Lihat semua ›'**
  String get viewAllAction;

  /// No description provided for @noChildrenTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada anak'**
  String get noChildrenTitle;

  /// No description provided for @addChildFirstMessage.
  ///
  /// In id, this message translates to:
  /// **'Tambah anak dulu di tab Anak.'**
  String get addChildFirstMessage;

  /// No description provided for @reloadTooltip.
  ///
  /// In id, this message translates to:
  /// **'Muat ulang'**
  String get reloadTooltip;

  /// No description provided for @deleteFailedWithDetail.
  ///
  /// In id, this message translates to:
  /// **'Gagal hapus: {error}'**
  String deleteFailedWithDetail(String error);

  /// No description provided for @saveFailedWithDetail.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan: {error}'**
  String saveFailedWithDetail(String error);

  /// No description provided for @markAllReadAction.
  ///
  /// In id, this message translates to:
  /// **'Tandai semua dibaca'**
  String get markAllReadAction;

  /// No description provided for @markReadAction.
  ///
  /// In id, this message translates to:
  /// **'Tandai dibaca'**
  String get markReadAction;

  /// No description provided for @allFilterLabel.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get allFilterLabel;

  /// No description provided for @parentFallbackName.
  ///
  /// In id, this message translates to:
  /// **'Orang tua'**
  String get parentFallbackName;

  /// No description provided for @weekdayMonShort.
  ///
  /// In id, this message translates to:
  /// **'Sen'**
  String get weekdayMonShort;

  /// No description provided for @weekdayTueShort.
  ///
  /// In id, this message translates to:
  /// **'Sel'**
  String get weekdayTueShort;

  /// No description provided for @weekdayWedShort.
  ///
  /// In id, this message translates to:
  /// **'Rab'**
  String get weekdayWedShort;

  /// No description provided for @weekdayThuShort.
  ///
  /// In id, this message translates to:
  /// **'Kam'**
  String get weekdayThuShort;

  /// No description provided for @weekdayFriShort.
  ///
  /// In id, this message translates to:
  /// **'Jum'**
  String get weekdayFriShort;

  /// No description provided for @weekdaySatShort.
  ///
  /// In id, this message translates to:
  /// **'Sab'**
  String get weekdaySatShort;

  /// No description provided for @weekdaySunShort.
  ///
  /// In id, this message translates to:
  /// **'Min'**
  String get weekdaySunShort;

  /// No description provided for @durationHoursLabel.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam'**
  String durationHoursLabel(int hours);

  /// No description provided for @durationMinutesLabel.
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit'**
  String durationMinutesLabel(int minutes);

  /// No description provided for @durationHoursMinutesLabel.
  ///
  /// In id, this message translates to:
  /// **'{hours}j {minutes}m'**
  String durationHoursMinutesLabel(int hours, int minutes);

  /// No description provided for @settingsAccountTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan Akun'**
  String get settingsAccountTitle;

  /// No description provided for @parentAccountSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Akun orang tua PulangAman'**
  String get parentAccountSubtitle;

  /// No description provided for @notificationsSheetTitle.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi PulangAman'**
  String get notificationsSheetTitle;

  /// No description provided for @notificationsSheetBody.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi dipakai untuk Kabar, SOS, dan zona aman. Atur izinnya di Pengaturan sistem HP (Aplikasi > PulangAman > Notifikasi).'**
  String get notificationsSheetBody;

  /// No description provided for @remindersTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengingat Jadwal'**
  String get remindersTitle;

  /// No description provided for @remindersLoadError.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat jadwal. Periksa koneksi, lalu coba lagi.'**
  String get remindersLoadError;

  /// No description provided for @reminderPresetSaved.
  ///
  /// In id, this message translates to:
  /// **'Pengingat \"{title}\" disimpan.\nBuka PulangAman di HP anak supaya jadwal aktif.'**
  String reminderPresetSaved(String title);

  /// No description provided for @reminderEditTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah pengingat'**
  String get reminderEditTitle;

  /// No description provided for @reminderCustomTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengingat kustom'**
  String get reminderCustomTitle;

  /// No description provided for @reminderTitleFieldLabel.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get reminderTitleFieldLabel;

  /// No description provided for @reminderMessageFieldLabel.
  ///
  /// In id, this message translates to:
  /// **'Pesan'**
  String get reminderMessageFieldLabel;

  /// No description provided for @reminderTimeQuestion.
  ///
  /// In id, this message translates to:
  /// **'Jam berapa?'**
  String get reminderTimeQuestion;

  /// No description provided for @reminderPickTimeHelp.
  ///
  /// In id, this message translates to:
  /// **'Pilih jam pengingat'**
  String get reminderPickTimeHelp;

  /// No description provided for @reminderUseThisTime.
  ///
  /// In id, this message translates to:
  /// **'Pakai jam ini'**
  String get reminderUseThisTime;

  /// No description provided for @reminderHourLabel.
  ///
  /// In id, this message translates to:
  /// **'Jam'**
  String get reminderHourLabel;

  /// No description provided for @reminderMinuteLabel.
  ///
  /// In id, this message translates to:
  /// **'Menit'**
  String get reminderMinuteLabel;

  /// No description provided for @reminderStyleFullscreen.
  ///
  /// In id, this message translates to:
  /// **'Layar penuh'**
  String get reminderStyleFullscreen;

  /// No description provided for @reminderStyleNotification.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get reminderStyleNotification;

  /// No description provided for @reminderEveryDay.
  ///
  /// In id, this message translates to:
  /// **'Setiap hari'**
  String get reminderEveryDay;

  /// No description provided for @reminderSaveChanges.
  ///
  /// In id, this message translates to:
  /// **'Simpan perubahan'**
  String get reminderSaveChanges;

  /// No description provided for @reminderTitleBodyRequired.
  ///
  /// In id, this message translates to:
  /// **'Judul dan pesan wajib diisi'**
  String get reminderTitleBodyRequired;

  /// No description provided for @reminderInfoBanner.
  ///
  /// In id, this message translates to:
  /// **'HP anak akan menampilkan pesan besar di jam tertentu. Anak cukup tekan “Mengerti” untuk menutup.'**
  String get reminderInfoBanner;

  /// No description provided for @reminderNoChildrenMessage.
  ///
  /// In id, this message translates to:
  /// **'Hubungkan anak dulu sebelum membuat pengingat.'**
  String get reminderNoChildrenMessage;

  /// No description provided for @sectionForChild.
  ///
  /// In id, this message translates to:
  /// **'UNTUK ANAK'**
  String get sectionForChild;

  /// No description provided for @sectionQuickAdd.
  ///
  /// In id, this message translates to:
  /// **'TAMBAH CEPAT'**
  String get sectionQuickAdd;

  /// No description provided for @reminderActiveScheduleTitle.
  ///
  /// In id, this message translates to:
  /// **'Jadwal Aktif'**
  String get reminderActiveScheduleTitle;

  /// No description provided for @reminderAddShort.
  ///
  /// In id, this message translates to:
  /// **'+ Tambah'**
  String get reminderAddShort;

  /// No description provided for @reminderEmptyMessage.
  ///
  /// In id, this message translates to:
  /// **'Belum ada pengingat. Pakai tambah cepat di atas.'**
  String get reminderEmptyMessage;

  /// No description provided for @reminderPresetAlreadyExists.
  ///
  /// In id, this message translates to:
  /// **'Jadwal \"{title}\" sudah ada untuk anak ini.'**
  String reminderPresetAlreadyExists(String title);

  /// No description provided for @reminderStudyChipLabel.
  ///
  /// In id, this message translates to:
  /// **'Belajar 19:00'**
  String get reminderStudyChipLabel;

  /// No description provided for @reminderSleepChipLabel.
  ///
  /// In id, this message translates to:
  /// **'Tidur 21:00'**
  String get reminderSleepChipLabel;

  /// No description provided for @reminderStudyPresetTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktunya Belajar'**
  String get reminderStudyPresetTitle;

  /// No description provided for @reminderStudyPresetBody.
  ///
  /// In id, this message translates to:
  /// **'Sekarang jam belajar. Matikan game dulu ya.'**
  String get reminderStudyPresetBody;

  /// No description provided for @reminderSleepPresetTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktunya Tidur'**
  String get reminderSleepPresetTitle;

  /// No description provided for @reminderSleepPresetBody.
  ///
  /// In id, this message translates to:
  /// **'Sudah malam. Waktunya istirahat agar besok semangat.'**
  String get reminderSleepPresetBody;

  /// No description provided for @parentHomeNoChildrenMessage.
  ///
  /// In id, this message translates to:
  /// **'Ketuk “Tambah anak” di bawah untuk buat kode, lalu masukkan di HP anak. Jika ganti cara masuk, pulihkan dulu dari nomor lama.'**
  String get parentHomeNoChildrenMessage;

  /// No description provided for @recoverChildrenButton.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan anak dari nomor lama'**
  String get recoverChildrenButton;

  /// No description provided for @childLocationSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Lokasi Anak'**
  String get childLocationSectionTitle;

  /// No description provided for @viewMapAction.
  ///
  /// In id, this message translates to:
  /// **'Lihat peta ›'**
  String get viewMapAction;

  /// No description provided for @todaySummaryTitle.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan Hari Ini'**
  String get todaySummaryTitle;

  /// No description provided for @placesVisitedLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi dikunjungi'**
  String get placesVisitedLabel;

  /// No description provided for @totalTripDistanceLabel.
  ///
  /// In id, this message translates to:
  /// **'Total perjalanan'**
  String get totalTripDistanceLabel;

  /// No description provided for @pendingCodesTitle.
  ///
  /// In id, this message translates to:
  /// **'Kode menunggu'**
  String get pendingCodesTitle;

  /// No description provided for @dismissPendingCodeTooltip.
  ///
  /// In id, this message translates to:
  /// **'Buang kode'**
  String get dismissPendingCodeTooltip;

  /// No description provided for @dismissPendingCodeConfirm.
  ///
  /// In id, this message translates to:
  /// **'Buang kode menunggu ini? Kode tidak akan berlaku lagi.'**
  String get dismissPendingCodeConfirm;

  /// No description provided for @pendingCodeDismissedSnack.
  ///
  /// In id, this message translates to:
  /// **'Kode menunggu dibuang'**
  String get pendingCodeDismissedSnack;

  /// No description provided for @dismissPendingCodeFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal buang kode: {error}'**
  String dismissPendingCodeFailed(String error);

  /// No description provided for @relinkReplaceConfirmBody.
  ///
  /// In id, this message translates to:
  /// **'Sudah ada kode menunggu untuk {name}. Buat kode baru? Kode lama tidak akan berlaku lagi.'**
  String relinkReplaceConfirmBody(String name);

  /// No description provided for @generateNewCodeAction.
  ///
  /// In id, this message translates to:
  /// **'Buat baru'**
  String get generateNewCodeAction;

  /// No description provided for @recoverChildrenTitle.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan anak'**
  String get recoverChildrenTitle;

  /// No description provided for @recoverChildrenPrompt.
  ///
  /// In id, this message translates to:
  /// **'Masukkan nomor yang dipakai akun orang tua sebelumnya.'**
  String get recoverChildrenPrompt;

  /// No description provided for @oldPhoneNumberLabel.
  ///
  /// In id, this message translates to:
  /// **'Nomor lama'**
  String get oldPhoneNumberLabel;

  /// No description provided for @recoverAction.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan'**
  String get recoverAction;

  /// No description provided for @recoverChildrenSuccess.
  ///
  /// In id, this message translates to:
  /// **'Berhasil memulihkan {count} anak. Lalu buat kode masuk ulang di menu anak.'**
  String recoverChildrenSuccess(int count);

  /// No description provided for @recoverChildrenNone.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada anak yang dipindahkan. Cek nomor lama.'**
  String get recoverChildrenNone;

  /// No description provided for @recoverChildrenFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memulihkan: {error}'**
  String recoverChildrenFailed(String error);

  /// No description provided for @relinkCodeTitle.
  ///
  /// In id, this message translates to:
  /// **'Kode masuk ulang {name}'**
  String relinkCodeTitle(String name);

  /// No description provided for @createCodeFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal buat kode: {error}'**
  String createCodeFailed(String error);

  /// No description provided for @removeChildConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus {name}?'**
  String removeChildConfirmTitle(String name);

  /// No description provided for @removeChildConfirmBody.
  ///
  /// In id, this message translates to:
  /// **'{name} akan dihapus dari daftar Anda. Berbagi lokasi berhenti sampai Anda menambahkannya lagi dengan kode masuk baru.'**
  String removeChildConfirmBody(String name);

  /// No description provided for @childRemoved.
  ///
  /// In id, this message translates to:
  /// **'{name} dihapus'**
  String childRemoved(String name);

  /// No description provided for @addChildTitle.
  ///
  /// In id, this message translates to:
  /// **'Tambah anak'**
  String get addChildTitle;

  /// No description provided for @createCodeAction.
  ///
  /// In id, this message translates to:
  /// **'Buat kode'**
  String get createCodeAction;

  /// No description provided for @codeTitle.
  ///
  /// In id, this message translates to:
  /// **'Kode'**
  String get codeTitle;

  /// No description provided for @tapToViewStatus.
  ///
  /// In id, this message translates to:
  /// **'Ketuk untuk lihat status'**
  String get tapToViewStatus;

  /// No description provided for @allChildrenArrived.
  ///
  /// In id, this message translates to:
  /// **'Semua anak sudah sampai'**
  String get allChildrenArrived;

  /// No description provided for @arrivedWaitingSummary.
  ///
  /// In id, this message translates to:
  /// **'{arrived}/{total} sudah sampai - menunggu {names}'**
  String arrivedWaitingSummary(int arrived, int total, String names);

  /// No description provided for @empBannerActiveTitle.
  ///
  /// In id, this message translates to:
  /// **'Titik kumpul darurat aktif'**
  String get empBannerActiveTitle;

  /// No description provided for @childNeedsHelp.
  ///
  /// In id, this message translates to:
  /// **'{name} butuh bantuan'**
  String childNeedsHelp(String name);

  /// No description provided for @withTapDetail.
  ///
  /// In id, this message translates to:
  /// **'{time} · Tap untuk detail'**
  String withTapDetail(String time);

  /// No description provided for @navChildrenLabel.
  ///
  /// In id, this message translates to:
  /// **'Anak'**
  String get navChildrenLabel;

  /// No description provided for @navZonesLabel.
  ///
  /// In id, this message translates to:
  /// **'Zona'**
  String get navZonesLabel;

  /// No description provided for @navMoreLabel.
  ///
  /// In id, this message translates to:
  /// **'Lainnya'**
  String get navMoreLabel;

  /// No description provided for @moreScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Fitur Lainnya'**
  String get moreScreenTitle;

  /// No description provided for @moreScreenSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kelola pengaturan & tambahan'**
  String get moreScreenSubtitle;

  /// No description provided for @activeRemindersStatLabel.
  ///
  /// In id, this message translates to:
  /// **'Pengingat Aktif'**
  String get activeRemindersStatLabel;

  /// No description provided for @totalPointsStatLabel.
  ///
  /// In id, this message translates to:
  /// **'Total Poin'**
  String get totalPointsStatLabel;

  /// No description provided for @sectionScheduleActivity.
  ///
  /// In id, this message translates to:
  /// **'JADWAL & AKTIVITAS'**
  String get sectionScheduleActivity;

  /// No description provided for @sectionSafety.
  ///
  /// In id, this message translates to:
  /// **'KEAMANAN'**
  String get sectionSafety;

  /// No description provided for @sectionSettings.
  ///
  /// In id, this message translates to:
  /// **'PENGATURAN'**
  String get sectionSettings;

  /// No description provided for @noPointsNoStreak.
  ///
  /// In id, this message translates to:
  /// **'0 poin · Belum ada streak'**
  String get noPointsNoStreak;

  /// No description provided for @pointsCountLabel.
  ///
  /// In id, this message translates to:
  /// **'{points} poin'**
  String pointsCountLabel(int points);

  /// No description provided for @noGuardiansYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada wali'**
  String get noGuardiansYet;

  /// No description provided for @guardiansCountLabel.
  ///
  /// In id, this message translates to:
  /// **'{count} wali'**
  String guardiansCountLabel(int count);

  /// No description provided for @noReportsYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada laporan'**
  String get noReportsYet;

  /// No description provided for @reportsCountLabel.
  ///
  /// In id, this message translates to:
  /// **'{count} laporan'**
  String reportsCountLabel(int count);

  /// No description provided for @emergencyMeetingMenuSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Lokasi bertemu saat darurat'**
  String get emergencyMeetingMenuSubtitle;

  /// No description provided for @accountSettingsMenuSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi, privasi, keluar'**
  String get accountSettingsMenuSubtitle;

  /// No description provided for @allKabarMarkedRead.
  ///
  /// In id, this message translates to:
  /// **'Semua kabar ditandai sudah dibaca'**
  String get allKabarMarkedRead;

  /// No description provided for @kabarHistoryTitle.
  ///
  /// In id, this message translates to:
  /// **'Riwayat Kabar'**
  String get kabarHistoryTitle;

  /// No description provided for @noKabarYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada kabar'**
  String get noKabarYet;

  /// No description provided for @kabarSummaryUnread.
  ///
  /// In id, this message translates to:
  /// **'{unread} belum dibaca · {total} kabar · 24 jam terakhir'**
  String kabarSummaryUnread(int unread, int total);

  /// No description provided for @kabarSummaryAll.
  ///
  /// In id, this message translates to:
  /// **'{total} kabar · 24 jam terakhir'**
  String kabarSummaryAll(int total);

  /// No description provided for @noKabarForFilter.
  ///
  /// In id, this message translates to:
  /// **'Belum ada kabar untuk filter ini.'**
  String get noKabarForFilter;

  /// No description provided for @giveRewardTitle.
  ///
  /// In id, this message translates to:
  /// **'Kasih pujian'**
  String get giveRewardTitle;

  /// No description provided for @rewardReasonLabel.
  ///
  /// In id, this message translates to:
  /// **'Alasan (opsional)'**
  String get rewardReasonLabel;

  /// No description provided for @rewardReasonHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Rajin belajar hari ini'**
  String get rewardReasonHint;

  /// No description provided for @addFivePointsAction.
  ///
  /// In id, this message translates to:
  /// **'Tambah +5'**
  String get addFivePointsAction;

  /// No description provided for @defaultPraiseReason.
  ///
  /// In id, this message translates to:
  /// **'Pujian dari orang tua'**
  String get defaultPraiseReason;

  /// No description provided for @pointsAddedSnackbar.
  ///
  /// In id, this message translates to:
  /// **'+5 poin ditambahkan'**
  String get pointsAddedSnackbar;

  /// No description provided for @pickChildTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih anak'**
  String get pickChildTitle;

  /// No description provided for @rewardsTitle.
  ///
  /// In id, this message translates to:
  /// **'Hadiah & Poin'**
  String get rewardsTitle;

  /// No description provided for @givePraiseFabLabel.
  ///
  /// In id, this message translates to:
  /// **'Kasih Pujian (+5)'**
  String get givePraiseFabLabel;

  /// No description provided for @rewardsIntro.
  ///
  /// In id, this message translates to:
  /// **'Poin dikumpulkan saat anak tiba di sekolah tepat waktu. Bisa juga ditambah manual sebagai pujian.'**
  String get rewardsIntro;

  /// No description provided for @howToEarnPointsTitle.
  ///
  /// In id, this message translates to:
  /// **'Cara Mendapat Poin'**
  String get howToEarnPointsTitle;

  /// No description provided for @howToEarnPointsReferenceTitle.
  ///
  /// In id, this message translates to:
  /// **'Cara poin didapat (referensi)'**
  String get howToEarnPointsReferenceTitle;

  /// No description provided for @earnSchoolOnTimeTitle.
  ///
  /// In id, this message translates to:
  /// **'Tiba di Sekolah Tepat Waktu'**
  String get earnSchoolOnTimeTitle;

  /// No description provided for @earnSchoolOnTimeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'+10 poin per hari'**
  String get earnSchoolOnTimeSubtitle;

  /// No description provided for @earnHomeOnTimeTitle.
  ///
  /// In id, this message translates to:
  /// **'Pulang Tepat Waktu'**
  String get earnHomeOnTimeTitle;

  /// No description provided for @earnHomeOnTimeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'+5 poin per hari'**
  String get earnHomeOnTimeSubtitle;

  /// No description provided for @earnParentPraiseTitle.
  ///
  /// In id, this message translates to:
  /// **'Pujian dari Orang Tua'**
  String get earnParentPraiseTitle;

  /// No description provided for @earnParentPraiseSubtitle.
  ///
  /// In id, this message translates to:
  /// **'+5 poin manual'**
  String get earnParentPraiseSubtitle;

  /// No description provided for @earnPerDayLabel.
  ///
  /// In id, this message translates to:
  /// **'per hari'**
  String get earnPerDayLabel;

  /// No description provided for @earnManualLabel.
  ///
  /// In id, this message translates to:
  /// **'manual'**
  String get earnManualLabel;

  /// No description provided for @pointsHistoryTitle.
  ///
  /// In id, this message translates to:
  /// **'Riwayat Poin'**
  String get pointsHistoryTitle;

  /// No description provided for @noPointsHistoryTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada riwayat poin'**
  String get noPointsHistoryTitle;

  /// No description provided for @noPointsHistoryMessage.
  ///
  /// In id, this message translates to:
  /// **'Setelah anak check-in sekolah, poin muncul di sini.'**
  String get noPointsHistoryMessage;

  /// No description provided for @totalPointsForChild.
  ///
  /// In id, this message translates to:
  /// **'Total Poin {name}'**
  String totalPointsForChild(String name);

  /// No description provided for @noStreakYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada streak harian'**
  String get noStreakYet;

  /// No description provided for @streakDaysLabel.
  ///
  /// In id, this message translates to:
  /// **'Rajin {streak} hari berturut-turut'**
  String streakDaysLabel(int streak);

  /// No description provided for @earnExampleHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: tiba di sekolah +10 poin'**
  String get earnExampleHint;

  /// No description provided for @weeklyStreakTitle.
  ///
  /// In id, this message translates to:
  /// **'Streak Minggu Ini'**
  String get weeklyStreakTitle;

  /// No description provided for @screenTimeMonitorSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pantau penggunaan harian'**
  String get screenTimeMonitorSubtitle;

  /// No description provided for @noAppDataToday.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data app hari ini.'**
  String get noAppDataToday;

  /// No description provided for @appUsageTitle.
  ///
  /// In id, this message translates to:
  /// **'Penggunaan Aplikasi'**
  String get appUsageTitle;

  /// No description provided for @thisWeekTitle.
  ///
  /// In id, this message translates to:
  /// **'Minggu Ini'**
  String get thisWeekTitle;

  /// No description provided for @thisMonthTitle.
  ///
  /// In id, this message translates to:
  /// **'Bulan Ini'**
  String get thisMonthTitle;

  /// No description provided for @heatmapLegendLow.
  ///
  /// In id, this message translates to:
  /// **'Sedikit'**
  String get heatmapLegendLow;

  /// No description provided for @heatmapLegendOver.
  ///
  /// In id, this message translates to:
  /// **'Lewat limit'**
  String get heatmapLegendOver;

  /// No description provided for @topAppCallout.
  ///
  /// In id, this message translates to:
  /// **'Paling sering dipakai {period}: {app}, total {time}'**
  String topAppCallout(String period, String app, String time);

  /// No description provided for @periodLabelToday.
  ///
  /// In id, this message translates to:
  /// **'hari ini'**
  String get periodLabelToday;

  /// No description provided for @periodLabelThisWeek.
  ///
  /// In id, this message translates to:
  /// **'minggu ini'**
  String get periodLabelThisWeek;

  /// No description provided for @periodLabelThisMonth.
  ///
  /// In id, this message translates to:
  /// **'bulan ini'**
  String get periodLabelThisMonth;

  /// No description provided for @appTrendNew.
  ///
  /// In id, this message translates to:
  /// **'Baru {period}'**
  String appTrendNew(String period);

  /// No description provided for @noAppDataForPeriod.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data app untuk periode ini.'**
  String get noAppDataForPeriod;

  /// No description provided for @weekdayPatternInsight.
  ///
  /// In id, this message translates to:
  /// **'Pola kelihatan: {dayNames} konsisten lebih tinggi {weekCount} minggu terakhir.'**
  String weekdayPatternInsight(String dayNames, int weekCount);

  /// No description provided for @weekendPatternInsight.
  ///
  /// In id, this message translates to:
  /// **'Akhir pekan konsisten lebih tinggi {weekCount} minggu terakhir.'**
  String weekendPatternInsight(int weekCount);

  /// No description provided for @weekdayMonFull.
  ///
  /// In id, this message translates to:
  /// **'Senin'**
  String get weekdayMonFull;

  /// No description provided for @weekdayTueFull.
  ///
  /// In id, this message translates to:
  /// **'Selasa'**
  String get weekdayTueFull;

  /// No description provided for @weekdayWedFull.
  ///
  /// In id, this message translates to:
  /// **'Rabu'**
  String get weekdayWedFull;

  /// No description provided for @weekdayThuFull.
  ///
  /// In id, this message translates to:
  /// **'Kamis'**
  String get weekdayThuFull;

  /// No description provided for @weekdayFriFull.
  ///
  /// In id, this message translates to:
  /// **'Jumat'**
  String get weekdayFriFull;

  /// No description provided for @weekdaySatFull.
  ///
  /// In id, this message translates to:
  /// **'Sabtu'**
  String get weekdaySatFull;

  /// No description provided for @weekdaySunFull.
  ///
  /// In id, this message translates to:
  /// **'Minggu'**
  String get weekdaySunFull;

  /// No description provided for @insightThisWeekTitle.
  ///
  /// In id, this message translates to:
  /// **'Insight minggu ini'**
  String get insightThisWeekTitle;

  /// No description provided for @insightAddReminderPrompt.
  ///
  /// In id, this message translates to:
  /// **'Tambah pengingat jam {time}?'**
  String insightAddReminderPrompt(String time);

  /// No description provided for @insightDaysUnderLimit.
  ///
  /// In id, this message translates to:
  /// **'{days} dari {total} hari di bawah limit'**
  String insightDaysUnderLimit(int days, int total);

  /// No description provided for @insightRewardsAutoHint.
  ///
  /// In id, this message translates to:
  /// **'Rewards menghitung ini otomatis'**
  String get insightRewardsAutoHint;

  /// No description provided for @insightReminderBodyDefault.
  ///
  /// In id, this message translates to:
  /// **'Saatnya istirahat dari HP dan bersiap istirahat.'**
  String get insightReminderBodyDefault;

  /// No description provided for @limitScheduleTitle.
  ///
  /// In id, this message translates to:
  /// **'Jadwal Batasan'**
  String get limitScheduleTitle;

  /// No description provided for @editInRulesHint.
  ///
  /// In id, this message translates to:
  /// **'Ubah di Aturan'**
  String get editInRulesHint;

  /// No description provided for @todayLabel.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get todayLabel;

  /// No description provided for @limitOffLabel.
  ///
  /// In id, this message translates to:
  /// **'Batas dimatikan'**
  String get limitOffLabel;

  /// No description provided for @outOfLimitLabel.
  ///
  /// In id, this message translates to:
  /// **'dari batas {limit}'**
  String outOfLimitLabel(String limit);

  /// No description provided for @remainingTimeLabel.
  ///
  /// In id, this message translates to:
  /// **'Sisa {remaining}'**
  String remainingTimeLabel(String remaining);

  /// No description provided for @overLimitLegend.
  ///
  /// In id, this message translates to:
  /// **'Melebihi batas ({limit})'**
  String overLimitLegend(String limit);

  /// No description provided for @safeLegendLabel.
  ///
  /// In id, this message translates to:
  /// **'Aman'**
  String get safeLegendLabel;

  /// No description provided for @noActiveScheduleLabel.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada jadwal aktif'**
  String get noActiveScheduleLabel;

  /// No description provided for @screenTimeRulesTitle.
  ///
  /// In id, this message translates to:
  /// **'Aturan · {name}'**
  String screenTimeRulesTitle(String name);

  /// No description provided for @limitScreenUsageLabel.
  ///
  /// In id, this message translates to:
  /// **'Batasi main HP'**
  String get limitScreenUsageLabel;

  /// No description provided for @noLimitLabel.
  ///
  /// In id, this message translates to:
  /// **'Tanpa batas'**
  String get noLimitLabel;

  /// No description provided for @schoolDaysTitle.
  ///
  /// In id, this message translates to:
  /// **'Hari Sekolah'**
  String get schoolDaysTitle;

  /// No description provided for @schoolDaysRangeLabel.
  ///
  /// In id, this message translates to:
  /// **'Sen–Jum'**
  String get schoolDaysRangeLabel;

  /// No description provided for @weekendDaysTitle.
  ///
  /// In id, this message translates to:
  /// **'Akhir Pekan'**
  String get weekendDaysTitle;

  /// No description provided for @weekendDaysRangeLabel.
  ///
  /// In id, this message translates to:
  /// **'Sab–Min'**
  String get weekendDaysRangeLabel;

  /// No description provided for @maxLimitLabel.
  ///
  /// In id, this message translates to:
  /// **'Maks {limit}'**
  String maxLimitLabel(String limit);

  /// No description provided for @blockedAppsTitle.
  ///
  /// In id, this message translates to:
  /// **'App yang ditahan'**
  String get blockedAppsTitle;

  /// No description provided for @noAppListYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada daftar app.'**
  String get noAppListYet;

  /// No description provided for @notUsedTodayLabel.
  ///
  /// In id, this message translates to:
  /// **'Belum dipakai hari ini'**
  String get notUsedTodayLabel;

  /// No description provided for @usedDurationLabel.
  ///
  /// In id, this message translates to:
  /// **'Dipakai {duration}'**
  String usedDurationLabel(String duration);

  /// No description provided for @schoolLimitPickerTitle.
  ///
  /// In id, this message translates to:
  /// **'Batas hari sekolah'**
  String get schoolLimitPickerTitle;

  /// No description provided for @weekendLimitPickerTitle.
  ///
  /// In id, this message translates to:
  /// **'Batas akhir pekan'**
  String get weekendLimitPickerTitle;

  /// No description provided for @savingLabel.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan...'**
  String get savingLabel;

  /// No description provided for @rulesSavedMessage.
  ///
  /// In id, this message translates to:
  /// **'Aturan tersimpan untuk {name}. Buka PulangAman di HP anak supaya aktif.'**
  String rulesSavedMessage(String name);

  /// No description provided for @limitsDisabledMessage.
  ///
  /// In id, this message translates to:
  /// **'Batas waktu dimatikan untuk {name}.'**
  String limitsDisabledMessage(String name);

  /// No description provided for @whereTitle.
  ///
  /// In id, this message translates to:
  /// **'Di mana'**
  String get whereTitle;

  /// No description provided for @childPositionsTodayTitle.
  ///
  /// In id, this message translates to:
  /// **'Posisi anak hari ini'**
  String get childPositionsTodayTitle;

  /// No description provided for @whereScreenIntro.
  ///
  /// In id, this message translates to:
  /// **'Bukan cuma sekolah — rumah, perjalanan, dan zona aman lain ikut terlihat. Ketuk anak untuk lihat catatan masuk/pulang sekolah.'**
  String get whereScreenIntro;

  /// No description provided for @locationUnclear.
  ///
  /// In id, this message translates to:
  /// **'Lokasi belum jelas'**
  String get locationUnclear;

  /// No description provided for @inHomeZoneHint.
  ///
  /// In id, this message translates to:
  /// **'Di zona rumah yang kamu atur'**
  String get inHomeZoneHint;

  /// No description provided for @inSchoolZoneHint.
  ///
  /// In id, this message translates to:
  /// **'Di zona sekolah yang kamu atur'**
  String get inSchoolZoneHint;

  /// No description provided for @commutingHint.
  ///
  /// In id, this message translates to:
  /// **'Sedang di perjalanan'**
  String get commutingHint;

  /// No description provided for @locationHintDefault.
  ///
  /// In id, this message translates to:
  /// **'Pastikan lokasi anak aktif & lokasi penting sudah diisi'**
  String get locationHintDefault;

  /// No description provided for @whereDetailTitle.
  ///
  /// In id, this message translates to:
  /// **'Di mana · {name}'**
  String whereDetailTitle(String name);

  /// No description provided for @zoneStatusExplain.
  ///
  /// In id, this message translates to:
  /// **'Status dari zona aman yang kamu atur (rumah, sekolah, atau lainnya).'**
  String get zoneStatusExplain;

  /// No description provided for @schoolNotesToday.
  ///
  /// In id, this message translates to:
  /// **'Catatan sekolah hari ini'**
  String get schoolNotesToday;

  /// No description provided for @schoolNotesHint.
  ///
  /// In id, this message translates to:
  /// **'Muncul otomatis saat anak masuk/keluar zona sekolah.'**
  String get schoolNotesHint;

  /// No description provided for @noSchoolNotesTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan sekolah'**
  String get noSchoolNotesTitle;

  /// No description provided for @noSchoolNotesMessage.
  ///
  /// In id, this message translates to:
  /// **'Kalau zona sekolah sudah diatur dan lokasi anak aktif, catatan tiba/pulang akan muncul di sini.'**
  String get noSchoolNotesMessage;

  /// No description provided for @arrivedAtSchool.
  ///
  /// In id, this message translates to:
  /// **'Tiba di sekolah'**
  String get arrivedAtSchool;

  /// No description provided for @departedFromSchool.
  ///
  /// In id, this message translates to:
  /// **'Pulang dari sekolah'**
  String get departedFromSchool;

  /// No description provided for @statusHomeLabel.
  ///
  /// In id, this message translates to:
  /// **'Di rumah'**
  String get statusHomeLabel;

  /// No description provided for @statusSchoolLabel.
  ///
  /// In id, this message translates to:
  /// **'Di sekolah'**
  String get statusSchoolLabel;

  /// No description provided for @statusSafeZoneLabel.
  ///
  /// In id, this message translates to:
  /// **'Di zona aman'**
  String get statusSafeZoneLabel;

  /// No description provided for @statusCommutingLabel.
  ///
  /// In id, this message translates to:
  /// **'Dalam perjalanan'**
  String get statusCommutingLabel;

  /// No description provided for @categoryHazardTitle.
  ///
  /// In id, this message translates to:
  /// **'Bahaya / Jalan Rusak'**
  String get categoryHazardTitle;

  /// No description provided for @categoryTrafficTitle.
  ///
  /// In id, this message translates to:
  /// **'Lalu Lintas'**
  String get categoryTrafficTitle;

  /// No description provided for @categoryCrowdTitle.
  ///
  /// In id, this message translates to:
  /// **'Kerumunan'**
  String get categoryCrowdTitle;

  /// No description provided for @categoryOtherTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporan Lain'**
  String get categoryOtherTitle;

  /// No description provided for @categoryHazardShort.
  ///
  /// In id, this message translates to:
  /// **'Hazard'**
  String get categoryHazardShort;

  /// No description provided for @categoryTrafficShort.
  ///
  /// In id, this message translates to:
  /// **'Lalu lintas'**
  String get categoryTrafficShort;

  /// No description provided for @categoryCrowdShort.
  ///
  /// In id, this message translates to:
  /// **'Kerumunan'**
  String get categoryCrowdShort;

  /// No description provided for @categoryOtherShort.
  ///
  /// In id, this message translates to:
  /// **'Lainnya'**
  String get categoryOtherShort;

  /// No description provided for @addPinTitle.
  ///
  /// In id, this message translates to:
  /// **'Tambah Pin'**
  String get addPinTitle;

  /// No description provided for @reportTypeLabel.
  ///
  /// In id, this message translates to:
  /// **'Jenis'**
  String get reportTypeLabel;

  /// No description provided for @reportTypeHazard.
  ///
  /// In id, this message translates to:
  /// **'Bahaya / Jalan rusak'**
  String get reportTypeHazard;

  /// No description provided for @reportNoteLabel.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get reportNoteLabel;

  /// No description provided for @reportNoteHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Jalan rusak'**
  String get reportNoteHint;

  /// No description provided for @reportNoteHintVr.
  ///
  /// In id, this message translates to:
  /// **'cth. Lubang di dekat zebra cross'**
  String get reportNoteHintVr;

  /// No description provided for @reportLocationDefault.
  ///
  /// In id, this message translates to:
  /// **'Lokasi: memakai titik default (izin GPS belum ada)'**
  String get reportLocationDefault;

  /// No description provided for @reportLocationCoords.
  ///
  /// In id, this message translates to:
  /// **'Lokasi: {lat}, {lng}'**
  String reportLocationCoords(String lat, String lng);

  /// No description provided for @savePinAction.
  ///
  /// In id, this message translates to:
  /// **'Simpan Pin'**
  String get savePinAction;

  /// No description provided for @pinAddedSnackbar.
  ///
  /// In id, this message translates to:
  /// **'Pin ditambahkan'**
  String get pinAddedSnackbar;

  /// No description provided for @reportVerifiedSnackbar.
  ///
  /// In id, this message translates to:
  /// **'Laporan diverifikasi'**
  String get reportVerifiedSnackbar;

  /// No description provided for @verifyFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal verifikasi: {error}'**
  String verifyFailed(String error);

  /// No description provided for @alreadyVerifiedThanks.
  ///
  /// In id, this message translates to:
  /// **'Sudah terverifikasi. Terima kasih.'**
  String get alreadyVerifiedThanks;

  /// No description provided for @fixedSuggestionNoted.
  ///
  /// In id, this message translates to:
  /// **'Terima kasih. Saran “sudah diperbaiki” dicatat untuk ditinjau.'**
  String get fixedSuggestionNoted;

  /// No description provided for @communityReportsTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporan Komunitas'**
  String get communityReportsTitle;

  /// No description provided for @reportsInfoBanner.
  ///
  /// In id, this message translates to:
  /// **'Pin kadaluarsa 72 jam kecuali diverifikasi. Tidak ada marketplace orang asing.'**
  String get reportsInfoBanner;

  /// No description provided for @totalReportsLabel.
  ///
  /// In id, this message translates to:
  /// **'Total Laporan'**
  String get totalReportsLabel;

  /// No description provided for @verifiedLabel.
  ///
  /// In id, this message translates to:
  /// **'Terverifikasi'**
  String get verifiedLabel;

  /// No description provided for @expiredLabel.
  ///
  /// In id, this message translates to:
  /// **'Kadaluarsa'**
  String get expiredLabel;

  /// No description provided for @areaMapTitle.
  ///
  /// In id, this message translates to:
  /// **'Peta Area'**
  String get areaMapTitle;

  /// No description provided for @reportsListTitle.
  ///
  /// In id, this message translates to:
  /// **'Daftar Laporan'**
  String get reportsListTitle;

  /// No description provided for @activeLabel.
  ///
  /// In id, this message translates to:
  /// **'Aktif'**
  String get activeLabel;

  /// No description provided for @filterLabel.
  ///
  /// In id, this message translates to:
  /// **'Filter'**
  String get filterLabel;

  /// No description provided for @noActiveReports.
  ///
  /// In id, this message translates to:
  /// **'Belum ada laporan aktif'**
  String get noActiveReports;

  /// No description provided for @noCoordinatesLabel.
  ///
  /// In id, this message translates to:
  /// **'Tanpa koordinat'**
  String get noCoordinatesLabel;

  /// No description provided for @coordinatesAvailableLabel.
  ///
  /// In id, this message translates to:
  /// **'Koordinat tersedia'**
  String get coordinatesAvailableLabel;

  /// No description provided for @expiresAtLabel.
  ///
  /// In id, this message translates to:
  /// **'Kadaluarsa {date}'**
  String expiresAtLabel(String date);

  /// No description provided for @stillThereAction.
  ///
  /// In id, this message translates to:
  /// **'Masih Ada'**
  String get stillThereAction;

  /// No description provided for @fixedAction.
  ///
  /// In id, this message translates to:
  /// **'Sudah Diperbaiki'**
  String get fixedAction;

  /// No description provided for @pinLocationLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi'**
  String get pinLocationLabel;

  /// No description provided for @usingCurrentLocation.
  ///
  /// In id, this message translates to:
  /// **'Menggunakan lokasi saat ini'**
  String get usingCurrentLocation;

  /// No description provided for @changeLocationAction.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get changeLocationAction;

  /// No description provided for @whatAreYouReporting.
  ///
  /// In id, this message translates to:
  /// **'Apa yang kamu laporkan?'**
  String get whatAreYouReporting;

  /// No description provided for @shortNoteOptional.
  ///
  /// In id, this message translates to:
  /// **'Catatan singkat (opsional)'**
  String get shortNoteOptional;

  /// No description provided for @verifiedBadge.
  ///
  /// In id, this message translates to:
  /// **'VERIFIED'**
  String get verifiedBadge;

  /// No description provided for @nearPlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'dekat {place}'**
  String nearPlaceLabel(String place);

  /// No description provided for @approxMetersFromPlace.
  ///
  /// In id, this message translates to:
  /// **'~{meters}m dari {place}'**
  String approxMetersFromPlace(int meters, String place);

  /// No description provided for @pickPinLocationTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih lokasi pin'**
  String get pickPinLocationTitle;

  /// No description provided for @resolvingLocation.
  ///
  /// In id, this message translates to:
  /// **'Mencari lokasi...'**
  String get resolvingLocation;

  /// No description provided for @locationUnknown.
  ///
  /// In id, this message translates to:
  /// **'Lokasi tidak tersedia'**
  String get locationUnknown;

  /// No description provided for @presetAtSchoolText.
  ///
  /// In id, this message translates to:
  /// **'Sudah sampai sekolah!'**
  String get presetAtSchoolText;

  /// No description provided for @presetAtHomeText.
  ///
  /// In id, this message translates to:
  /// **'Sudah sampai di rumah.'**
  String get presetAtHomeText;

  /// No description provided for @presetNeedHelpText.
  ///
  /// In id, this message translates to:
  /// **'Butuh bantuan — tolong hubungi saya.'**
  String get presetNeedHelpText;

  /// No description provided for @homeArrivedStatus.
  ///
  /// In id, this message translates to:
  /// **'Di rumah · Sudah sampai'**
  String get homeArrivedStatus;

  /// No description provided for @hereAtTime.
  ///
  /// In id, this message translates to:
  /// **'Di sini · {time}'**
  String hereAtTime(String time);

  /// No description provided for @waitingGpsSignal.
  ///
  /// In id, this message translates to:
  /// **'Menunggu sinyal lokasi...'**
  String get waitingGpsSignal;

  /// No description provided for @atHomeTrackingStopped.
  ///
  /// In id, this message translates to:
  /// **'Di rumah · jejak dihentikan'**
  String get atHomeTrackingStopped;

  /// No description provided for @locationNotUpdatedRecently.
  ///
  /// In id, this message translates to:
  /// **'Lokasi tidak diperbarui baru-baru ini'**
  String get locationNotUpdatedRecently;

  /// No description provided for @movingNow.
  ///
  /// In id, this message translates to:
  /// **'Sedang bergerak'**
  String get movingNow;

  /// No description provided for @liveJustNow.
  ///
  /// In id, this message translates to:
  /// **'Live · baru saja'**
  String get liveJustNow;

  /// No description provided for @liveSecondsAgo.
  ///
  /// In id, this message translates to:
  /// **'Live · {seconds} dtk lalu'**
  String liveSecondsAgo(int seconds);

  /// No description provided for @liveMinutesAgo.
  ///
  /// In id, this message translates to:
  /// **'Live · {minutes} mnt lalu'**
  String liveMinutesAgo(int minutes);

  /// No description provided for @zoneNameActive.
  ///
  /// In id, this message translates to:
  /// **'{name} · aktif'**
  String zoneNameActive(String name);

  /// No description provided for @zoneNameWithCount.
  ///
  /// In id, this message translates to:
  /// **'{name} · {count} zona'**
  String zoneNameWithCount(String name, int count);

  /// No description provided for @safeZonesCount.
  ///
  /// In id, this message translates to:
  /// **'{count} zona aman'**
  String safeZonesCount(int count);

  /// No description provided for @zonesSummaryActiveCount.
  ///
  /// In id, this message translates to:
  /// **'{count} zona · {active} aktif sekarang'**
  String zonesSummaryActiveCount(int count, int active);

  /// No description provided for @noZonesYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada zona'**
  String get noZonesYet;

  /// No description provided for @addHomeOrSchoolHint.
  ///
  /// In id, this message translates to:
  /// **'Tambah rumah atau sekolah'**
  String get addHomeOrSchoolHint;

  /// No description provided for @remindersNoneActive.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang aktif'**
  String get remindersNoneActive;

  /// No description provided for @remindersActiveCount.
  ///
  /// In id, this message translates to:
  /// **'{count} aktif'**
  String remindersActiveCount(int count);

  /// No description provided for @remindersActiveNext.
  ///
  /// In id, this message translates to:
  /// **'{count} aktif · berikutnya {title} {time}'**
  String remindersActiveNext(int count, String title, String time);

  /// No description provided for @chargingShortSuffix.
  ///
  /// In id, this message translates to:
  /// **' · cas'**
  String get chargingShortSuffix;

  /// No description provided for @batteryPercentLabel.
  ///
  /// In id, this message translates to:
  /// **'Baterai {value}%'**
  String batteryPercentLabel(int value);

  /// No description provided for @batteryPercentCharging.
  ///
  /// In id, this message translates to:
  /// **'Baterai {value}% · di-cas'**
  String batteryPercentCharging(int value);

  /// No description provided for @batteryUnknown.
  ///
  /// In id, this message translates to:
  /// **'Baterai belum diketahui'**
  String get batteryUnknown;

  /// No description provided for @weakSignalRoute.
  ///
  /// In id, this message translates to:
  /// **'Sinyal lemah — rute kurang akurat.'**
  String get weakSignalRoute;

  /// No description provided for @beingMonitored.
  ///
  /// In id, this message translates to:
  /// **'Sedang dipantau'**
  String get beingMonitored;

  /// No description provided for @locationCannotUpdate.
  ///
  /// In id, this message translates to:
  /// **'Lokasi tidak bisa diperbarui'**
  String get locationCannotUpdate;

  /// No description provided for @adminAllChildren.
  ///
  /// In id, this message translates to:
  /// **'Admin · Semua anak'**
  String get adminAllChildren;

  /// No description provided for @waitingWithNames.
  ///
  /// In id, this message translates to:
  /// **'Menunggu · {names}'**
  String waitingWithNames(String names);

  /// No description provided for @activeWithNames.
  ///
  /// In id, this message translates to:
  /// **'Aktif · {names}'**
  String activeWithNames(String names);

  /// No description provided for @zeroGuardiansAdd.
  ///
  /// In id, this message translates to:
  /// **'0 wali · Tambah wali'**
  String get zeroGuardiansAdd;

  /// No description provided for @guardiansCountNamed.
  ///
  /// In id, this message translates to:
  /// **'{count} wali · {names}'**
  String guardiansCountNamed(int count, String names);

  /// No description provided for @guardiansCountOnly.
  ///
  /// In id, this message translates to:
  /// **'{count} wali'**
  String guardiansCountOnly(int count);

  /// No description provided for @guardiansForChildTitle.
  ///
  /// In id, this message translates to:
  /// **'Wali · {name}'**
  String guardiansForChildTitle(String name);

  /// No description provided for @noGuardiansForChild.
  ///
  /// In id, this message translates to:
  /// **'Belum ada wali untuk anak ini.'**
  String get noGuardiansForChild;

  /// No description provided for @youBadge.
  ///
  /// In id, this message translates to:
  /// **'ANDA'**
  String get youBadge;

  /// No description provided for @doneAction.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get doneAction;

  /// No description provided for @editChevron.
  ///
  /// In id, this message translates to:
  /// **'Edit ›'**
  String get editChevron;

  /// No description provided for @notConfiguredTapSearch.
  ///
  /// In id, this message translates to:
  /// **'Belum diatur — ketuk untuk cari'**
  String get notConfiguredTapSearch;

  /// No description provided for @noPlacesYetAddHomeSchool.
  ///
  /// In id, this message translates to:
  /// **'Belum ada lokasi. Tambah rumah atau sekolah.'**
  String get noPlacesYetAddHomeSchool;

  /// No description provided for @noPlacesMatch.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada lokasi yang cocok.'**
  String get noPlacesMatch;

  /// No description provided for @homePlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Rumah'**
  String get homePlaceLabel;

  /// No description provided for @schoolPlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Sekolah'**
  String get schoolPlaceLabel;

  /// No description provided for @parentRoleFallback.
  ///
  /// In id, this message translates to:
  /// **'Orang tua'**
  String get parentRoleFallback;

  /// No description provided for @hereNowLabel.
  ///
  /// In id, this message translates to:
  /// **'Di sini'**
  String get hereNowLabel;

  /// No description provided for @waitingLocationDots.
  ///
  /// In id, this message translates to:
  /// **'Menunggu lokasi...'**
  String get waitingLocationDots;

  /// No description provided for @seenOnMap.
  ///
  /// In id, this message translates to:
  /// **'Terlihat di peta'**
  String get seenOnMap;

  /// No description provided for @signalStrong.
  ///
  /// In id, this message translates to:
  /// **'Kuat'**
  String get signalStrong;

  /// No description provided for @signalMedium.
  ///
  /// In id, this message translates to:
  /// **'Sedang'**
  String get signalMedium;

  /// No description provided for @signalWeak.
  ///
  /// In id, this message translates to:
  /// **'Lemah'**
  String get signalWeak;

  /// No description provided for @signalLost.
  ///
  /// In id, this message translates to:
  /// **'Hilang'**
  String get signalLost;

  /// No description provided for @activeBadgeShort.
  ///
  /// In id, this message translates to:
  /// **'AKTIF'**
  String get activeBadgeShort;

  /// No description provided for @staleBadgeShort.
  ///
  /// In id, this message translates to:
  /// **'LAMA'**
  String get staleBadgeShort;

  /// No description provided for @batteryMetricLabel.
  ///
  /// In id, this message translates to:
  /// **'Baterai'**
  String get batteryMetricLabel;

  /// No description provided for @signalMetricLabel.
  ///
  /// In id, this message translates to:
  /// **'Sinyal'**
  String get signalMetricLabel;

  /// No description provided for @timeMetricLabel.
  ///
  /// In id, this message translates to:
  /// **'Waktu'**
  String get timeMetricLabel;

  /// No description provided for @optionsTooltip.
  ///
  /// In id, this message translates to:
  /// **'Opsi'**
  String get optionsTooltip;

  /// No description provided for @removeFromList.
  ///
  /// In id, this message translates to:
  /// **'Hapus dari daftar'**
  String get removeFromList;

  /// No description provided for @relinkCodeMenu.
  ///
  /// In id, this message translates to:
  /// **'Kode masuk ulang {name}'**
  String relinkCodeMenu(String name);

  /// No description provided for @noSignalYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada sinyal'**
  String get noSignalYet;

  /// No description provided for @updatedAtTime.
  ///
  /// In id, this message translates to:
  /// **'Update {time}'**
  String updatedAtTime(String time);

  /// No description provided for @batteryDeadBanner.
  ///
  /// In id, this message translates to:
  /// **'HP anak hampir habis / mati. Lokasi mungkin tidak diperbarui.'**
  String get batteryDeadBanner;

  /// No description provided for @batteryLowBanner.
  ///
  /// In id, this message translates to:
  /// **'Baterai HP anak lemah ({level}%).'**
  String batteryLowBanner(String level);

  /// No description provided for @locationStaleBanner.
  ///
  /// In id, this message translates to:
  /// **'Sinyal lokasi lama. HP anak mungkin mati atau tanpa jaringan.'**
  String get locationStaleBanner;

  /// No description provided for @screenLimitsOff.
  ///
  /// In id, this message translates to:
  /// **'Batasan dimatikan'**
  String get screenLimitsOff;

  /// No description provided for @screenUsedToday.
  ///
  /// In id, this message translates to:
  /// **'{used} / {limit} hari ini'**
  String screenUsedToday(String used, String limit);

  /// No description provided for @limitCaptionShort.
  ///
  /// In id, this message translates to:
  /// **'batas {limit}'**
  String limitCaptionShort(String limit);

  /// No description provided for @unreadKabarCount.
  ///
  /// In id, this message translates to:
  /// **'{count} belum dibaca'**
  String unreadKabarCount(int count);

  /// No description provided for @noTrailToday.
  ///
  /// In id, this message translates to:
  /// **'Belum ada jejak hari ini.'**
  String get noTrailToday;

  /// No description provided for @safeZoneFeatureTitle.
  ///
  /// In id, this message translates to:
  /// **'Zona aman'**
  String get safeZoneFeatureTitle;

  /// No description provided for @parentKabarFeatureTitle.
  ///
  /// In id, this message translates to:
  /// **'Kabar'**
  String get parentKabarFeatureTitle;

  /// No description provided for @remindersFeatureTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengingat'**
  String get remindersFeatureTitle;

  /// No description provided for @todaySectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get todaySectionTitle;

  /// No description provided for @safePlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi aman'**
  String get safePlaceLabel;

  /// No description provided for @placesCountLabel.
  ///
  /// In id, this message translates to:
  /// **'lokasi'**
  String get placesCountLabel;

  /// No description provided for @girlChildLabel.
  ///
  /// In id, this message translates to:
  /// **'Anak perempuan'**
  String get girlChildLabel;

  /// No description provided for @boyChildLabel.
  ///
  /// In id, this message translates to:
  /// **'Anak laki-laki'**
  String get boyChildLabel;

  /// No description provided for @noActiveAlerts.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada peringatan aktif'**
  String get noActiveAlerts;

  /// No description provided for @invitesSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Undangan'**
  String get invitesSectionTitle;

  /// No description provided for @childIdLabel.
  ///
  /// In id, this message translates to:
  /// **'Anak: {id}'**
  String childIdLabel(String id);

  /// No description provided for @childFallbackName.
  ///
  /// In id, this message translates to:
  /// **'Anak'**
  String get childFallbackName;

  /// No description provided for @guardianFallbackName.
  ///
  /// In id, this message translates to:
  /// **'Wali'**
  String get guardianFallbackName;

  /// No description provided for @needExtraHelpNote.
  ///
  /// In id, this message translates to:
  /// **'Memerlukan bantuan tambahan'**
  String get needExtraHelpNote;

  /// No description provided for @resolvedByParentNote.
  ///
  /// In id, this message translates to:
  /// **'Diselesaikan orang tua'**
  String get resolvedByParentNote;

  /// No description provided for @sendResponseFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengirim respons. Coba lagi.'**
  String get sendResponseFailed;

  /// No description provided for @resolvePanicFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyelesaikan panik. Coba lagi.'**
  String get resolvePanicFailed;

  /// No description provided for @panicBadge.
  ///
  /// In id, this message translates to:
  /// **'PANIK'**
  String get panicBadge;

  /// No description provided for @childInSafeZoneTitle.
  ///
  /// In id, this message translates to:
  /// **'Anak di zona aman'**
  String get childInSafeZoneTitle;

  /// No description provided for @zoneUpdateTitle.
  ///
  /// In id, this message translates to:
  /// **'Update zona'**
  String get zoneUpdateTitle;

  /// No description provided for @arrivedAtZoneMsg.
  ///
  /// In id, this message translates to:
  /// **'{childName} sudah sampai di {zoneLabel}'**
  String arrivedAtZoneMsg(String childName, String zoneLabel);

  /// No description provided for @childInSafeZoneMsg.
  ///
  /// In id, this message translates to:
  /// **'{childName} sudah di zona aman'**
  String childInSafeZoneMsg(String childName);

  /// No description provided for @leftSafeZoneMsg.
  ///
  /// In id, this message translates to:
  /// **'{childName} meninggalkan zona aman'**
  String leftSafeZoneMsg(String childName);

  /// No description provided for @newKabarBanner.
  ///
  /// In id, this message translates to:
  /// **'Kabar baru'**
  String get newKabarBanner;

  /// No description provided for @shortTrailLabel.
  ///
  /// In id, this message translates to:
  /// **'Jejak singkat'**
  String get shortTrailLabel;

  /// No description provided for @importantPlacesLabel.
  ///
  /// In id, this message translates to:
  /// **'Zona Aman'**
  String get importantPlacesLabel;

  /// No description provided for @zonesHubTitle.
  ///
  /// In id, this message translates to:
  /// **'Zona Aman'**
  String get zonesHubTitle;

  /// No description provided for @zonesHubSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Rumah, sekolah, dan lokasi sering dikunjungi'**
  String get zonesHubSubtitle;

  /// No description provided for @searchPlaceHint.
  ///
  /// In id, this message translates to:
  /// **'Cari lokasi...'**
  String get searchPlaceHint;

  /// No description provided for @addNewPlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Tambah lokasi baru'**
  String get addNewPlaceLabel;

  /// No description provided for @estimateMinutes.
  ///
  /// In id, this message translates to:
  /// **'Estimasi {minutes} menit'**
  String estimateMinutes(int minutes);

  /// No description provided for @noAddressYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada alamat'**
  String get noAddressYet;

  /// No description provided for @extraSafePlace.
  ///
  /// In id, this message translates to:
  /// **'Lokasi aman tambahan'**
  String get extraSafePlace;

  /// No description provided for @searchHomeAddress.
  ///
  /// In id, this message translates to:
  /// **'Cari alamat rumah'**
  String get searchHomeAddress;

  /// No description provided for @searchSchoolName.
  ///
  /// In id, this message translates to:
  /// **'Cari nama sekolah'**
  String get searchSchoolName;

  /// No description provided for @searchCustomPlace.
  ///
  /// In id, this message translates to:
  /// **'Cari lokasi: {label}'**
  String searchCustomPlace(String label);

  /// No description provided for @homeSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Marine Parade, kode pos, nama kompleks'**
  String get homeSearchHint;

  /// No description provided for @schoolSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Tao Nan School, nama sekolah'**
  String get schoolSearchHint;

  /// No description provided for @customSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: nama les, mall, taman, alamat'**
  String get customSearchHint;

  /// No description provided for @placeSavedSnack.
  ///
  /// In id, this message translates to:
  /// **'Disimpan: {name}'**
  String placeSavedSnack(String name);

  /// No description provided for @failedSavePlace.
  ///
  /// In id, this message translates to:
  /// **'Gagal simpan lokasi: {error}'**
  String failedSavePlace(String error);

  /// No description provided for @placeLessonSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Lokasi les'**
  String get placeLessonSuggestion;

  /// No description provided for @placeGrandmaSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Rumah nenek'**
  String get placeGrandmaSuggestion;

  /// No description provided for @newPlaceDefault.
  ///
  /// In id, this message translates to:
  /// **'Lokasi baru'**
  String get newPlaceDefault;

  /// No description provided for @addSafePlaceTitle.
  ///
  /// In id, this message translates to:
  /// **'Tambah lokasi aman'**
  String get addSafePlaceTitle;

  /// No description provided for @customPlaceHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Les piano Blok M'**
  String get customPlaceHint;

  /// No description provided for @continueSearchAddress.
  ///
  /// In id, this message translates to:
  /// **'Lanjut cari alamat'**
  String get continueSearchAddress;

  /// No description provided for @otherPlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi lain'**
  String get otherPlaceLabel;

  /// No description provided for @deletePlaceTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus lokasi?'**
  String get deletePlaceTitle;

  /// No description provided for @deletePlaceConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus \"{name}\"? Rute aman yang terhubung ke lokasi ini juga akan dihapus.'**
  String deletePlaceConfirm(String name);

  /// No description provided for @deletePlaceCascadeNote.
  ///
  /// In id, this message translates to:
  /// **'Rute aman yang terhubung ke lokasi ini juga akan dihapus.'**
  String get deletePlaceCascadeNote;

  /// No description provided for @placeDeletedSnack.
  ///
  /// In id, this message translates to:
  /// **'Lokasi dihapus'**
  String get placeDeletedSnack;

  /// No description provided for @failedDeletePlace.
  ///
  /// In id, this message translates to:
  /// **'Gagal hapus: {error}'**
  String failedDeletePlace(String error);

  /// No description provided for @placesForChildLabel.
  ///
  /// In id, this message translates to:
  /// **'Lokasi {name}'**
  String placesForChildLabel(String name);

  /// No description provided for @addChildBeforeInvite.
  ///
  /// In id, this message translates to:
  /// **'Tambah anak dulu sebelum undang wali'**
  String get addChildBeforeInvite;

  /// No description provided for @inviteViaWhatsApp.
  ///
  /// In id, this message translates to:
  /// **'Undang via WhatsApp'**
  String get inviteViaWhatsApp;

  /// No description provided for @inviteViaEmail.
  ///
  /// In id, this message translates to:
  /// **'Undang via Email'**
  String get inviteViaEmail;

  /// No description provided for @inviteViaLink.
  ///
  /// In id, this message translates to:
  /// **'Undang via Link'**
  String get inviteViaLink;

  /// No description provided for @guardianNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama wali'**
  String get guardianNameLabel;

  /// No description provided for @phoneWhatsAppLabel.
  ///
  /// In id, this message translates to:
  /// **'Nomor WhatsApp / telepon'**
  String get phoneWhatsAppLabel;

  /// No description provided for @emailOptionalLabel.
  ///
  /// In id, this message translates to:
  /// **'Email (opsional)'**
  String get emailOptionalLabel;

  /// No description provided for @namePhoneRequired.
  ///
  /// In id, this message translates to:
  /// **'Nama dan nomor wajib diisi'**
  String get namePhoneRequired;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In id, this message translates to:
  /// **'Link undangan disalin'**
  String get inviteLinkCopied;

  /// No description provided for @inviteFailedDetail.
  ///
  /// In id, this message translates to:
  /// **'Gagal undang: {error}'**
  String inviteFailedDetail(String error);

  /// No description provided for @failedGenericDetail.
  ///
  /// In id, this message translates to:
  /// **'Gagal: {error}'**
  String failedGenericDetail(String error);

  /// No description provided for @guardiansInviteHint.
  ///
  /// In id, this message translates to:
  /// **'Undang wali yang sudah dikenal. Tidak ada pencarian orang asing — hanya orang yang kamu percaya.'**
  String get guardiansInviteHint;

  /// No description provided for @activeGuardiansSection.
  ///
  /// In id, this message translates to:
  /// **'WALI AKTIF'**
  String get activeGuardiansSection;

  /// No description provided for @inviteNewSection.
  ///
  /// In id, this message translates to:
  /// **'UNDANG WALI BARU'**
  String get inviteNewSection;

  /// No description provided for @addTrustedGuardian.
  ///
  /// In id, this message translates to:
  /// **'Tambah Wali Terpercaya'**
  String get addTrustedGuardian;

  /// No description provided for @guardianInviteChannelHint.
  ///
  /// In id, this message translates to:
  /// **'Wali akan menerima undangan via WhatsApp atau email'**
  String get guardianInviteChannelHint;

  /// No description provided for @guardianInviteBody.
  ///
  /// In id, this message translates to:
  /// **'Halo {name}, kamu diundang jadi Wali Terpercaya untuk {children} di PulangAman. Buka undangan: {link}'**
  String guardianInviteBody(String name, String children, String link);

  /// No description provided for @guardianInviteSubject.
  ///
  /// In id, this message translates to:
  /// **'Undangan Wali Terpercaya PulangAman'**
  String get guardianInviteSubject;

  /// No description provided for @activeGuardiansCount.
  ///
  /// In id, this message translates to:
  /// **'{count} wali aktif'**
  String activeGuardiansCount(int count);

  /// No description provided for @channelWhatsApp.
  ///
  /// In id, this message translates to:
  /// **'WhatsApp'**
  String get channelWhatsApp;

  /// No description provided for @channelEmail.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get channelEmail;

  /// No description provided for @channelLink.
  ///
  /// In id, this message translates to:
  /// **'Link'**
  String get channelLink;

  /// No description provided for @justNowRelative.
  ///
  /// In id, this message translates to:
  /// **'baru saja'**
  String get justNowRelative;

  /// No description provided for @minutesAgoRelative.
  ///
  /// In id, this message translates to:
  /// **'{minutes} mnt lalu'**
  String minutesAgoRelative(int minutes);

  /// No description provided for @noLocationYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada lokasi'**
  String get noLocationYet;

  /// No description provided for @sessionTokenFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengambil token sesi. Coba lagi.'**
  String get sessionTokenFailed;

  /// No description provided for @phoneNotFoundRelogin.
  ///
  /// In id, this message translates to:
  /// **'Nomor telepon tidak ditemukan. Keluar lalu masuk ulang.'**
  String get phoneNotFoundRelogin;

  /// No description provided for @phoneInvalidFormat.
  ///
  /// In id, this message translates to:
  /// **'Nomor telepon tidak valid. Gunakan format +62...'**
  String get phoneInvalidFormat;

  /// No description provided for @placesApiKeyHint.
  ///
  /// In id, this message translates to:
  /// **'Perlu key server terpisah: aktifkan Places API + Geocoding.'**
  String get placesApiKeyHint;

  /// No description provided for @forChildLabel.
  ///
  /// In id, this message translates to:
  /// **'Untuk anak'**
  String get forChildLabel;

  /// No description provided for @phoneCountryCode.
  ///
  /// In id, this message translates to:
  /// **'+62'**
  String get phoneCountryCode;

  /// No description provided for @accessPerChildSection.
  ///
  /// In id, this message translates to:
  /// **'AKSES PER ANAK'**
  String get accessPerChildSection;

  /// No description provided for @revokeAccessTooltip.
  ///
  /// In id, this message translates to:
  /// **'Cabut akses'**
  String get revokeAccessTooltip;

  /// No description provided for @alertAcknowledged.
  ///
  /// In id, this message translates to:
  /// **'Peringatan direspons'**
  String get alertAcknowledged;

  /// No description provided for @alertAcknowledgedCascadeStopped.
  ///
  /// In id, this message translates to:
  /// **'Peringatan direspons. Cascade dihentikan.'**
  String get alertAcknowledgedCascadeStopped;

  /// No description provided for @alertLabelWithId.
  ///
  /// In id, this message translates to:
  /// **'Peringatan {id}'**
  String alertLabelWithId(String id);

  /// No description provided for @fromParentLabel.
  ///
  /// In id, this message translates to:
  /// **'Dari {name}'**
  String fromParentLabel(String name);

  /// No description provided for @pickAvatarTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih wajah untuk {name}'**
  String pickAvatarTitle(String name);

  /// No description provided for @pickAvatarHint.
  ///
  /// In id, this message translates to:
  /// **'Pilih laki-laki atau perempuan. Foto anak tidak dipakai demi privasi.'**
  String get pickAvatarHint;

  /// No description provided for @changeAvatarAction.
  ///
  /// In id, this message translates to:
  /// **'Ubah wajah avatar'**
  String get changeAvatarAction;

  /// No description provided for @placeFriendSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Teman'**
  String get placeFriendSuggestion;

  /// No description provided for @placeMallSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Mall / lokasi main'**
  String get placeMallSuggestion;

  /// No description provided for @customPlaceDialogHint.
  ///
  /// In id, this message translates to:
  /// **'Pilih jenis, atau tulis sendiri. Lalu cari alamatnya.'**
  String get customPlaceDialogHint;

  /// No description provided for @routeBadge.
  ///
  /// In id, this message translates to:
  /// **'RUTE'**
  String get routeBadge;

  /// No description provided for @trailPointsCount.
  ///
  /// In id, this message translates to:
  /// **'{count} titik jalur'**
  String trailPointsCount(int count);

  /// No description provided for @hoursAgoRelative.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam lalu'**
  String hoursAgoRelative(int hours);

  /// No description provided for @daysAgoRelative.
  ///
  /// In id, this message translates to:
  /// **'{days} hari lalu'**
  String daysAgoRelative(int days);

  /// No description provided for @yesterdayLabel.
  ///
  /// In id, this message translates to:
  /// **'Kemarin'**
  String get yesterdayLabel;

  /// No description provided for @lastSeenLabel.
  ///
  /// In id, this message translates to:
  /// **'Terakhir terlihat: {when}'**
  String lastSeenLabel(String when);

  /// No description provided for @tooManyAttempts.
  ///
  /// In id, this message translates to:
  /// **'Terlalu banyak percobaan. Coba lagi nanti.'**
  String get tooManyAttempts;

  /// No description provided for @invalidOtpCode.
  ///
  /// In id, this message translates to:
  /// **'Kode OTP salah.'**
  String get invalidOtpCode;

  /// No description provided for @otpExpiredResend.
  ///
  /// In id, this message translates to:
  /// **'Kode OTP kedaluwarsa. Kirim ulang.'**
  String get otpExpiredResend;

  /// No description provided for @appConfigIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Konfigurasi aplikasi belum lengkap. Hubungi pengembang.'**
  String get appConfigIncomplete;

  /// No description provided for @serverMissingCustomToken.
  ///
  /// In id, this message translates to:
  /// **'Server tidak mengembalikan customToken. Deploy API terbaru dulu.'**
  String get serverMissingCustomToken;

  /// No description provided for @startMonitoringAction.
  ///
  /// In id, this message translates to:
  /// **'Mulai pantau'**
  String get startMonitoringAction;

  /// No description provided for @openLocationAction.
  ///
  /// In id, this message translates to:
  /// **'Buka lokasi'**
  String get openLocationAction;

  /// No description provided for @orTypeOwnNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Atau tulis nama sendiri'**
  String get orTypeOwnNameLabel;

  /// No description provided for @todayShortLabel.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get todayShortLabel;

  /// No description provided for @thisWeekLabel.
  ///
  /// In id, this message translates to:
  /// **'Minggu ini'**
  String get thisWeekLabel;

  /// No description provided for @thisMonthLabel.
  ///
  /// In id, this message translates to:
  /// **'Bulan ini'**
  String get thisMonthLabel;

  /// No description provided for @weekShortLabel.
  ///
  /// In id, this message translates to:
  /// **'Minggu'**
  String get weekShortLabel;

  /// No description provided for @monthShortLabel.
  ///
  /// In id, this message translates to:
  /// **'Bulan'**
  String get monthShortLabel;

  /// No description provided for @dayShortLabel.
  ///
  /// In id, this message translates to:
  /// **'Hari'**
  String get dayShortLabel;

  /// No description provided for @durationMinutesOnly.
  ///
  /// In id, this message translates to:
  /// **'{minutes} mnt'**
  String durationMinutesOnly(int minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam {minutes} mnt'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @otpSendTimedOut.
  ///
  /// In id, this message translates to:
  /// **'Pengiriman kode terlalu lama. Coba lagi.'**
  String get otpSendTimedOut;

  /// No description provided for @recoverParentsOnly.
  ///
  /// In id, this message translates to:
  /// **'Hanya orang tua yang sedang masuk yang bisa memulihkan.'**
  String get recoverParentsOnly;

  /// No description provided for @activityLoadFailed.
  ///
  /// In id, this message translates to:
  /// **'Riwayat hari ini belum bisa dimuat'**
  String get activityLoadFailed;

  /// No description provided for @greetingMorning.
  ///
  /// In id, this message translates to:
  /// **'Selamat pagi'**
  String get greetingMorning;

  /// No description provided for @greetingMidday.
  ///
  /// In id, this message translates to:
  /// **'Selamat siang'**
  String get greetingMidday;

  /// No description provided for @greetingAfternoon.
  ///
  /// In id, this message translates to:
  /// **'Selamat sore'**
  String get greetingAfternoon;

  /// No description provided for @greetingNight.
  ///
  /// In id, this message translates to:
  /// **'Selamat malam'**
  String get greetingNight;

  /// No description provided for @periodMorningShort.
  ///
  /// In id, this message translates to:
  /// **'Pagi'**
  String get periodMorningShort;

  /// No description provided for @periodMiddayShort.
  ///
  /// In id, this message translates to:
  /// **'Siang'**
  String get periodMiddayShort;

  /// No description provided for @periodAfternoonShort.
  ///
  /// In id, this message translates to:
  /// **'Sore'**
  String get periodAfternoonShort;

  /// No description provided for @periodNightShort.
  ///
  /// In id, this message translates to:
  /// **'Malam'**
  String get periodNightShort;

  /// No description provided for @menuLabel.
  ///
  /// In id, this message translates to:
  /// **'Menu'**
  String get menuLabel;

  /// No description provided for @brandNameUpper.
  ///
  /// In id, this message translates to:
  /// **'PULANGAMAN'**
  String get brandNameUpper;

  /// No description provided for @premiumFamilyMapTitle.
  ///
  /// In id, this message translates to:
  /// **'PETA KELUARGA'**
  String get premiumFamilyMapTitle;

  /// No description provided for @premiumLiveLabel.
  ///
  /// In id, this message translates to:
  /// **'Langsung'**
  String get premiumLiveLabel;

  /// No description provided for @premiumFamilyMapHint.
  ///
  /// In id, this message translates to:
  /// **'Satu panggung — semua anak'**
  String get premiumFamilyMapHint;

  /// No description provided for @premiumStatusSection.
  ///
  /// In id, this message translates to:
  /// **'STATUS'**
  String get premiumStatusSection;

  /// No description provided for @premiumGreetingWithName.
  ///
  /// In id, this message translates to:
  /// **'{greeting}, {name}'**
  String premiumGreetingWithName(String greeting, String name);

  /// No description provided for @premiumAllChildrenSafe.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{Satu anak dalam jangkauan aman.} other{Semua anak dalam jangkauan aman.}}'**
  String premiumAllChildrenSafe(int count);

  /// No description provided for @premiumChildrenTracked.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{1 anak dipantau.} other{{count} anak dipantau.}}'**
  String premiumChildrenTracked(int count);

  /// No description provided for @premiumBatteryLowDetail.
  ///
  /// In id, this message translates to:
  /// **'Baterai {percent}%'**
  String premiumBatteryLowDetail(int percent);

  /// No description provided for @premiumChargeSoonMeta.
  ///
  /// In id, this message translates to:
  /// **'segera dicas'**
  String get premiumChargeSoonMeta;

  /// No description provided for @settingsPremiumHomeShell.
  ///
  /// In id, this message translates to:
  /// **'Tampilan editorial (Alt A)'**
  String get settingsPremiumHomeShell;

  /// No description provided for @settingsPremiumHomeShellHint.
  ///
  /// In id, this message translates to:
  /// **'Tanpa bilah navigasi bawah. Nonaktifkan untuk kembali ke tampilan biasa.'**
  String get settingsPremiumHomeShellHint;

  /// No description provided for @updatedJustNowBadge.
  ///
  /// In id, this message translates to:
  /// **'Baru saja diperbarui'**
  String get updatedJustNowBadge;

  /// No description provided for @updatedMinutesAgoBadge.
  ///
  /// In id, this message translates to:
  /// **'Diperbarui {minutes} mnt lalu'**
  String updatedMinutesAgoBadge(int minutes);

  /// No description provided for @updatedHoursAgoBadge.
  ///
  /// In id, this message translates to:
  /// **'Diperbarui {hours} jam lalu'**
  String updatedHoursAgoBadge(int hours);

  /// No description provided for @relinkCodeShort.
  ///
  /// In id, this message translates to:
  /// **'Kode masuk ulang'**
  String get relinkCodeShort;

  /// No description provided for @newSignInCodeTitle.
  ///
  /// In id, this message translates to:
  /// **'Kode masuk baru untuk {name}'**
  String newSignInCodeTitle(String name);

  /// No description provided for @newSignInCodeBody.
  ///
  /// In id, this message translates to:
  /// **'Masukkan kode ini di aplikasi {name} saat memilih \"Sudah punya kode\" pada layar masuk.'**
  String newSignInCodeBody(String name);

  /// No description provided for @copyCodeAction.
  ///
  /// In id, this message translates to:
  /// **'Salin kode'**
  String get copyCodeAction;

  /// No description provided for @codeCopiedSnack.
  ///
  /// In id, this message translates to:
  /// **'Kode disalin'**
  String get codeCopiedSnack;

  /// No description provided for @codeValid24Hours.
  ///
  /// In id, this message translates to:
  /// **'Berlaku 24 jam'**
  String get codeValid24Hours;

  /// No description provided for @codeValidForHours.
  ///
  /// In id, this message translates to:
  /// **'Berlaku {hours} jam'**
  String codeValidForHours(int hours);
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
