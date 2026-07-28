// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'PulangAman';

  @override
  String get homeByTitle => 'Jam Pulang Aman';

  @override
  String get homeBySubtitle =>
      'Pantau apakah anak sudah di rumah pada jam yang ditentukan';

  @override
  String get homeByModeOff => 'Nonaktif';

  @override
  String get homeByModeMaghrib => 'Ikuti waktu Maghrib';

  @override
  String get homeByModeMaghribHint =>
      'Waktu berbeda tiap hari, dihitung dari lokasi rumah';

  @override
  String get homeByModeCustom => 'Jam tetap';

  @override
  String get homeByGraceLabel => 'Masa tenggang';

  @override
  String homeByGraceHint(int minutes) {
    return '$minutes menit setelah jam pulang';
  }

  @override
  String get homeByWeekendTitle => 'Akhir pekan';

  @override
  String get homeByWeekendOff => 'Nonaktifkan';

  @override
  String get homeByWeekendSame => 'Sama seperti hari biasa';

  @override
  String get homeByWeekendCustom => 'Jam berbeda';

  @override
  String get homeBySkipDatesTitle => 'Hari libur';

  @override
  String get homeBySkipDatesAdd => 'Tandai tanggal';

  @override
  String get homeBySkipDatesEmpty => 'Belum ada tanggal libur';

  @override
  String get homeByTodayStatus => 'Status hari ini';

  @override
  String get homeByStatusPending => 'Menunggu jam pulang';

  @override
  String get homeByStatusPreNotified => 'Pengingat pulang dikirim ke anak';

  @override
  String get homeByStatusTargetNotified =>
      'Belum di rumah — orang tua sudah diberitahu';

  @override
  String get homeByStatusGraceNotified =>
      'Masih belum di rumah setelah masa tenggang';

  @override
  String get homeByStatusResolved => 'Sudah di rumah';

  @override
  String get homeByStatusSkipped => 'Libur / tidak dipantau hari ini';

  @override
  String homeByTargetTime(String time) {
    return 'Jam pulang $time';
  }

  @override
  String get homeByOnceHomeNote =>
      'Setelah anak tiba di rumah, pantauan hari ini selesai meski anak keluar lagi.';

  @override
  String get homeBySave => 'Simpan';

  @override
  String get homeBySaved => 'Pengaturan jam pulang disimpan';

  @override
  String get homeBySeeAll => 'Lihat semua';

  @override
  String get homeBySummaryOff => 'Belum diaktifkan';

  @override
  String get homeBySummaryNotTurnedOn => 'Belum dinyalakan';

  @override
  String homeBySummaryMaghrib(String status) {
    return 'Mode Maghrib dipilih · $status';
  }

  @override
  String homeBySummaryCustom(String time, String status) {
    return 'Jam $time · $status';
  }

  @override
  String get homeByChildAckButton => 'Aku otw pulang';

  @override
  String get homeByChildAckSent => 'Sudah dikirim ke orang tua';

  @override
  String get homeByChildAckReasonInTransit => 'Di jalan';

  @override
  String get homeByChildAckReasonStoppedBy => 'Mampir dulu';

  @override
  String get homeByChildAckReasonSchool => 'Ada kegiatan sekolah';

  @override
  String get homeByChildAckReasonOther => 'Lainnya';

  @override
  String get homeByChildAckNoteHint => 'Catatan singkat (opsional)';

  @override
  String get homeByChildAckSubmit => 'Kirim ke orang tua';

  @override
  String get homeByChildAckTitle => 'Beri kabar ke orang tua';

  @override
  String get homeByNoChildren => 'Belum ada anak terhubung';

  @override
  String get tripSectionTitle => 'Rute Aman';

  @override
  String get tripCreateCta => 'Buat rute aman';

  @override
  String get tripSuggestSchoolHome => 'Sekolah → Rumah';

  @override
  String get tripPickFrom => 'Dari';

  @override
  String get tripPickTo => 'Ke';

  @override
  String get tripCreate => 'Buat rute';

  @override
  String get tripStart => 'Mulai pantau';

  @override
  String get tripCancel => 'Batalkan';

  @override
  String get tripActive => 'Dalam perjalanan';

  @override
  String get tripPlanned => 'Direncanakan';

  @override
  String get tripArrived => 'Sudah sampai';

  @override
  String get tripNeedTwoPlaces => 'Tambah minimal dua lokasi dulu';

  @override
  String get tripNeedDistinct => 'Asal dan tujuan harus berbeda';

  @override
  String get tripCreated => 'Rute aman dibuat';

  @override
  String get tripChildStart => 'Mulai perjalanan';

  @override
  String get tripChildPickDest => 'Pilih tujuan';

  @override
  String tripChildActiveTo(String place) {
    return 'Menuju $place';
  }

  @override
  String get tripChildCancel => 'Batalkan perjalanan';

  @override
  String tripProgressMeta(String distance, String eta) {
    return '$distance · $eta';
  }

  @override
  String get empTitle => 'Titik Kumpul Darurat';

  @override
  String get empSubtitle => 'Lokasi bertemu saat kondisi darurat';

  @override
  String empEmpty(String childName) {
    return 'Belum ada titik kumpul untuk $childName';
  }

  @override
  String get empEmptyGeneric => 'Belum ada titik kumpul';

  @override
  String get empLoadError => 'Gagal memuat titik kumpul';

  @override
  String get empRetry => 'Coba lagi';

  @override
  String get empAdd => '+ Tambah titik kumpul';

  @override
  String get empAddBackup => 'Titik cadangan';

  @override
  String get empPrimaryLabel => 'Titik kumpul utama';

  @override
  String get empPrimary => 'Utama';

  @override
  String get empBackup => 'Cadangan';

  @override
  String get empInstructionsHint =>
      'Contoh: Kalau kondisi darurat dan gak bisa saling hubungi, ketemu di sini';

  @override
  String get empNameHint => 'Nama lokasi (mis. Rumah Nenek)';

  @override
  String get empSave => 'Simpan';

  @override
  String get empDelete => 'Hapus';

  @override
  String get empDeleteConfirm => 'Hapus titik kumpul untuk semua anak?';

  @override
  String get empEdit => 'Ubah titik kumpul';

  @override
  String get empMapPreview => 'Preview peta';

  @override
  String get empApplyToOthers => 'Terapkan ke anak lain juga?';

  @override
  String get empApply => 'Terapkan';

  @override
  String get empActivate => 'Aktifkan titik kumpul';

  @override
  String get empActivateConfirm =>
      'Semua anak dan wali akan dapat notifikasi untuk segera menuju titik kumpul masing-masing. Lanjutkan?';

  @override
  String get empActivateNoteHint => 'Catatan singkat (opsional)';

  @override
  String get empActivateContinue => 'Aktifkan sekarang';

  @override
  String get empActivateCancel => 'Batal';

  @override
  String get listAnd => 'dan';

  @override
  String empActivateCaption(String names) {
    return 'Berlaku untuk $names, juga wali mereka';
  }

  @override
  String empSummarySent(int count) {
    return 'Terkirim ke $count anak';
  }

  @override
  String empSummarySkipped(String childName) {
    return '$childName belum punya titik kumpul';
  }

  @override
  String get empRateLimited => 'Aktivasi dibatasi — coba lagi nanti';

  @override
  String get empOpenMaps => 'Buka di Peta';

  @override
  String get empDistanceUnknown => 'Jarak belum diketahui';

  @override
  String empDistanceLive(String childName, String distance) {
    return '$childName sekarang $distance dari sini';
  }

  @override
  String empDistanceFromChild(String distance) {
    return 'Jarak anak: $distance';
  }

  @override
  String get empAlertTitle => 'Titik Kumpul Darurat';

  @override
  String empAlertBody(String place) {
    return 'Segera menuju $place';
  }

  @override
  String empMyDistance(String distance) {
    return 'Jarakmu: $distance';
  }

  @override
  String get empActiveTitle => 'Titik kumpul sedang aktif';

  @override
  String empActiveSince(String time) {
    return 'Diaktifkan $time';
  }

  @override
  String get empArrived => 'Sudah sampai';

  @override
  String get empOnTheWay => 'Masih di jalan';

  @override
  String get empChildLocationUnknown => 'Lokasi belum diketahui';

  @override
  String get empActiveNoPoint => 'Belum punya titik kumpul';

  @override
  String get empRefresh => 'Perbarui';

  @override
  String get empDeactivate => 'Matikan titik kumpul';

  @override
  String get empDeactivateConfirm =>
      'Matikan titik kumpul darurat? Anak dan wali akan diberi tahu kalau kondisi darurat sudah selesai.';

  @override
  String get empDeactivated => 'Titik kumpul dinonaktifkan';

  @override
  String get empMenuHint => 'Titik bertemu saat darurat';

  @override
  String get empPickPlace => 'Cari lokasi titik kumpul';

  @override
  String get empNoChildren => 'Belum ada anak terhubung';

  @override
  String get settingsSectionApp => 'Aplikasi';

  @override
  String get settingsSectionAccount => 'Akun';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsLanguageHint => 'Pilih bahasa tampilan aplikasi';

  @override
  String get settingsLanguageId => 'Bahasa Indonesia';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsAboutHint => 'Bagikan, nilai, dan info aplikasi';

  @override
  String get settingsVersion => 'Versi';

  @override
  String settingsVersionValue(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get settingsShare => 'Bagikan aplikasi ini';

  @override
  String get settingsShareHint => 'Ajak keluarga mencoba PulangAman';

  @override
  String get settingsShareMessage =>
      'Coba PulangAman — jaringan keselamatan untuk orang tua dan anak.\nhttps://www.tursinalabs.com';

  @override
  String get settingsRate => 'Nilai aplikasi ini';

  @override
  String get settingsRateHint => 'Tulis ulasan di Google Play';

  @override
  String get settingsPrivacy => 'Kebijakan Privasi';

  @override
  String get settingsPrivacyHint => 'Baca kebijakan privasi kami';

  @override
  String get settingsTerms => 'Syarat & Ketentuan';

  @override
  String get settingsTermsHint => 'Baca syarat penggunaan kami';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsNotificationsHint => 'Kabar, SOS, dan zona aman';

  @override
  String get brand => 'Pulang Aman';

  @override
  String get tagline => 'Pulang dengan tenang, sampai dengan aman.';

  @override
  String get roleParent => 'Saya orang tua';

  @override
  String get roleChild => 'Saya anak';

  @override
  String get roleGuardian => 'Saya wali terpercaya';

  @override
  String get roleLabel => 'Peran';

  @override
  String get roleParentShort => 'Orang Tua';

  @override
  String get roleChildShort => 'Anak';

  @override
  String get roleGuardianShort => 'Wali';

  @override
  String get continueLabel => 'Lanjut';

  @override
  String get loginTitle => 'Masuk';

  @override
  String get phoneLabel => 'Nomor telepon';

  @override
  String get nameLabel => 'Nama';

  @override
  String get nameHint => 'Masukkan nama lengkap';

  @override
  String get phoneHint => '+62812...';

  @override
  String get loginAction => 'Masuk';

  @override
  String get otpLabel => 'Kode OTP';

  @override
  String get otpHint => '6 digit dari SMS';

  @override
  String get otpSentHint => 'Kode verifikasi dikirim ke nomor Anda';

  @override
  String get verifyOtpAction => 'Verifikasi';

  @override
  String get otpVerifyingHint => 'Memverifikasi kode. Mohon tunggu sebentar.';

  @override
  String get otpSendingHint => 'Mengirim kode verifikasi. Mohon tunggu…';

  @override
  String get resendOtp => 'Kirim ulang kode';

  @override
  String get changeNumber => 'Ubah nomor';

  @override
  String get sendOtpAction => 'Kirim kode OTP';

  @override
  String get inviteCodeHintChild => 'Minta kode 6 digit dari orang tua';

  @override
  String get connecting => 'Menghubungkan...';

  @override
  String get sending => 'Mengirim...';

  @override
  String get featureCheckIn => 'Check-in';

  @override
  String get featureRewards => 'Hadiah';

  @override
  String get featureScreenTime => 'Waktu Layar';

  @override
  String get childrenTitle => 'Anak saya';

  @override
  String get addChild => 'Undang anak';

  @override
  String get inviteCodeLabel => 'Kode undangan';

  @override
  String get createInvite => 'Buat kode undangan';

  @override
  String get inviteShareHint => 'Bagikan kode ini ke HP anak. Berlaku 24 jam.';

  @override
  String get liveMap => 'Peta langsung';

  @override
  String get zonesTitle => 'Zona Aman';

  @override
  String get guardiansTitle => 'Wali terpercaya';

  @override
  String get panicButton => 'TOMBOL PANIK';

  @override
  String get panicConfirm => 'Ketuk 3 kali untuk mengirim peringatan';

  @override
  String get panicHoldConfirm => 'Tekan & tahan 3 detik untuk kirim peringatan';

  @override
  String get panicSent => 'Peringatan panik terkirim';

  @override
  String get trackingOn => 'Pelacakan aktif';

  @override
  String get bgLocationDisclosureTitle => 'Kenapa butuh akses lokasi selalu?';

  @override
  String get bgLocationDisclosureBody =>
      'Biar orang tua bisa lihat lokasi kamu dan dapat kabar zona aman meskipun aplikasi ditutup.';

  @override
  String get bgLocationDisclosureContinue => 'Lanjutkan';

  @override
  String get trackingOff => 'Pelacakan berhenti';

  @override
  String get staleLocation => 'Lokasi anak tidak diperbarui';

  @override
  String get ackAlert => 'Saya sudah merespons';

  @override
  String get resolveAlert => 'Selesai / aman';

  @override
  String get inviteGuardian => 'Undang wali';

  @override
  String get acceptInvite => 'Terima undangan';

  @override
  String get shareLocation => 'Bagikan lokasi saya';

  @override
  String get needBackup => 'Butuh bantuan cadangan';

  @override
  String get guardianGuidance =>
      'Hubungi orang tua atau layanan darurat. Jangan mengejar orang asing.';

  @override
  String get offlineQueued => 'Tersimpan offline — akan dikirim saat online';

  @override
  String get homeZone => 'Rumah';

  @override
  String get schoolZone => 'Sekolah';

  @override
  String get save => 'Simpan';

  @override
  String get logout => 'Keluar';

  @override
  String get cancel => 'Batal';

  @override
  String get emergencyContacts => 'Kontak darurat';

  @override
  String get noChildren => 'Belum ada anak terhubung';

  @override
  String get noInvites => 'Tidak ada undangan';

  @override
  String get activeAlerts => 'Peringatan aktif';

  @override
  String get mapKeyMissing =>
      'Peta Google belum dikonfigurasi. Tambahkan GOOGLE_MAPS_API_KEY di android/local.properties lalu rebuild.';

  @override
  String get lastKnownCoords => 'Koordinat terakhir';

  @override
  String get childTabHome => 'Beranda';

  @override
  String get childTabScreen => 'Layar';

  @override
  String get childTabMessages => 'Kabar';

  @override
  String get childMessageSent => 'Kabar terkirim';

  @override
  String get childMessageFailed => 'Gagal mengirim kabar. Coba lagi.';

  @override
  String errorWithDetail(String error) {
    return 'Gagal: $error';
  }

  @override
  String get panicAckedByParent => 'Orang tua sudah merespons panik';

  @override
  String get panicResolvedSafe => 'Panik ditandai selesai / aman';

  @override
  String panicConfirmCount(int count) {
    return 'Ketuk 3 kali untuk mengirim peringatan ($count/3)';
  }

  @override
  String get panicSendFailedRetrying =>
      'Gagal kirim panik. Dicoba lagi otomatis.';

  @override
  String get smsFallbackPanicBody =>
      'PulangAman PANIK — butuh bantuan sekarang.';

  @override
  String get empDefaultPlaceName => 'Titik kumpul';

  @override
  String empAlertBodyWithNote(String note, String place) {
    return '$note — menuju $place';
  }

  @override
  String empAlertBodyPlain(String place) {
    return 'Segera menuju titik kumpul: $place';
  }

  @override
  String get homeByPreviewTitle => 'Waktunya pulang';

  @override
  String homeByPreviewBody(String name) {
    return '$name, sebentar lagi waktu pulang ya';
  }

  @override
  String get greetingDefaultName => 'Sahabat';

  @override
  String get homeByDefaultChildName => 'Anak';

  @override
  String get tripNotEnoughPlaces => 'Belum ada cukup lokasi tersimpan';

  @override
  String get zoneGenericLabel => 'Lokasi';

  @override
  String get startAction => 'Mulai';

  @override
  String tripArrivedNotified(String place) {
    return 'Tiba di $place — ortu sudah diberitahu';
  }

  @override
  String get destinationFallback => 'tujuan';

  @override
  String get locationSendFailed => 'Gagal kirim lokasi';

  @override
  String get locationPermissionDenied => 'Izin lokasi ditolak';

  @override
  String get sessionNotReady => 'Sesi belum siap';

  @override
  String get allowExactAlarmMessage =>
      'Izinkan alarm tepat waktu agar pengingat ortu muncul.';

  @override
  String get openAction => 'Buka';

  @override
  String get trackingOnNeedsAlways =>
      'Lokasi aktif — izinkan \"Selalu\" agar tetap jalan di background';

  @override
  String get refreshTooltip => 'Segarkan (kirim daftar app & aturan)';

  @override
  String get refreshSentWithApps => 'Lokasi & daftar app dikirim ke ortu';

  @override
  String get refreshSentNoApps =>
      'Lokasi dikirim. Daftar app kosong — cek izin Usage Access.';

  @override
  String get logoutConfirmTitle => 'Keluar dari akun anak?';

  @override
  String get logoutConfirmBody =>
      'Untuk masuk lagi, minta kode masuk ulang dari HP ortu.';

  @override
  String childMessageSentWithLabel(String label) {
    return 'Kabar terkirim: $label';
  }

  @override
  String get homeSubtitleTagline =>
      'Tetap aman, kumpulkan poin, dan beri kabar keluarga.';

  @override
  String get pillLocationOn => 'Lokasi aktif';

  @override
  String get pillLocationOff => 'Lokasi mati';

  @override
  String pointsStreakLabel(int points, int streak) {
    return '$points poin · $streak hari';
  }

  @override
  String get screenRulesActive => 'Aturan layar aktif';

  @override
  String get screenPermissionIncomplete => 'Izin layar belum lengkap';

  @override
  String get alarmPermissionIncomplete => 'Izin alarm belum lengkap';

  @override
  String reminderActiveCount(int count) {
    return 'Pengingat aktif ($count)';
  }

  @override
  String get noRemindersYet => 'Belum ada pengingat';

  @override
  String get sendingAlert => 'Mengirim peringatan...';

  @override
  String get panicCooldownMessage =>
      'Panik terkirim. Tunggu sebentar sebelum bisa dikirim lagi.';

  @override
  String get panicModeActiveWaiting =>
      'Mode panik aktif — menunggu respons orang tua';

  @override
  String get enableScreenProtectionTitle => 'Aktifkan perlindungan waktu layar';

  @override
  String get neverBlockedAppsNote =>
      'PulangAman, Telepon, dan Pesan tidak pernah diblokir.';

  @override
  String get allowUsageAccess => 'Izinkan akses pemakaian';

  @override
  String get enableAppBlocking => 'Aktifkan pemblokiran aplikasi';

  @override
  String get restrictedSettingsHelp =>
      'Tombolnya terkunci (\"Setelan dibatasi\")? Buka Info aplikasi, ketuk menu titik tiga di kanan atas, lalu pilih \"Izinkan setelan yang dibatasi\". Setelah itu coba lagi.';

  @override
  String get openAppInfo => 'Buka Info aplikasi';

  @override
  String get empActiveNowLabel => 'Darurat — segera ke sini';

  @override
  String get empFamilyMeetingPoint => 'Titik kumpul keluarga';

  @override
  String get followParentInstructions => 'Ikuti arahan orang tua';

  @override
  String get memorizeEmpPlace => 'Hafalkan lokasi ini untuk kondisi darurat';

  @override
  String tripArrivedAt(String place) {
    return 'Tiba di $place';
  }

  @override
  String get tripRouteReady => 'Rute siap';

  @override
  String get tripGenericLabel => 'Perjalanan';

  @override
  String get tripParentNotified => 'Orang tua sudah diberi tahu';

  @override
  String get tripReadyToStart => 'Siap dimulai';

  @override
  String get tripInProgress => 'Sedang berjalan';

  @override
  String get tripChooseSafeDestination =>
      'Pilih tujuan aman ke lokasi tersimpan';

  @override
  String get screenTimeToday => 'Layar hari ini';

  @override
  String get yourPoints => 'Poin kamu';

  @override
  String get kabarTitle => 'Kabar ke ortu';

  @override
  String get kabarSubtitle => 'Ketuk sekali — pesan langsung terkirim.';

  @override
  String get kabarInfoNote =>
      'Pesan dikirim ke orang tua yang terhubung. Untuk darurat, gunakan tombol panik di Beranda.';

  @override
  String get kabarHeroTitle => 'Kirim kabar cepat';

  @override
  String get kabarHeroSubtitle =>
      'Tidak perlu mengetik. Pilih salah satu pesan di bawah.';

  @override
  String get presetAtSchoolLabel => 'Sudah sampai sekolah';

  @override
  String get presetAtSchoolSubtitle =>
      'Beri tahu ortu kamu sudah aman di sekolah';

  @override
  String get presetAtHomeLabel => 'Sudah di rumah';

  @override
  String get presetAtHomeSubtitle => 'Kabari kalau kamu sudah pulang';

  @override
  String get presetNeedHelpLabel => 'Butuh bantuan';

  @override
  String get presetNeedHelpSubtitle => 'Minta ortu segera menghubungi kamu';

  @override
  String get screenTimeTitle => 'Waktu layar';

  @override
  String get screenTimeSubtitle => 'Lihat berapa lama kamu main HP hari ini.';

  @override
  String screenTimeOverTargetStatus(String period) {
    return '$period · lewat target';
  }

  @override
  String get appsLabel => 'Aplikasi';

  @override
  String appCountLabel(int count) {
    return '$count app';
  }

  @override
  String get usageAccessInactiveTitle => 'Akses pemakaian belum aktif';

  @override
  String get usageAccessInactiveBody =>
      'Izinkan PulangAman melihat pemakaian layar agar statistik muncul di sini.';

  @override
  String get openPermissionSettings => 'Buka pengaturan izin';

  @override
  String get totalLabel => 'Total';

  @override
  String get targetLabel => 'Target';

  @override
  String get noDataYet => 'Belum ada data';

  @override
  String get useAsUsualStatsAppear =>
      'Gunakan HP seperti biasa — statistik akan muncul di sini.';

  @override
  String get delete => 'Hapus';

  @override
  String get add => 'Tambah';

  @override
  String get understood => 'Mengerti';

  @override
  String get editAction => 'Ubah';

  @override
  String get retryAction => 'Coba lagi';

  @override
  String get okAction => 'OK';

  @override
  String get closeAction => 'Tutup';

  @override
  String get viewAllAction => 'Lihat semua ›';

  @override
  String get noChildrenTitle => 'Belum ada anak';

  @override
  String get addChildFirstMessage => 'Tambah anak dulu di tab Anak.';

  @override
  String get reloadTooltip => 'Muat ulang';

  @override
  String deleteFailedWithDetail(String error) {
    return 'Gagal hapus: $error';
  }

  @override
  String saveFailedWithDetail(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get markAllReadAction => 'Tandai semua dibaca';

  @override
  String get markReadAction => 'Tandai dibaca';

  @override
  String get allFilterLabel => 'Semua';

  @override
  String get parentFallbackName => 'Orang tua';

  @override
  String get weekdayMonShort => 'Sen';

  @override
  String get weekdayTueShort => 'Sel';

  @override
  String get weekdayWedShort => 'Rab';

  @override
  String get weekdayThuShort => 'Kam';

  @override
  String get weekdayFriShort => 'Jum';

  @override
  String get weekdaySatShort => 'Sab';

  @override
  String get weekdaySunShort => 'Min';

  @override
  String durationHoursLabel(int hours) {
    return '$hours jam';
  }

  @override
  String durationMinutesLabel(int minutes) {
    return '$minutes menit';
  }

  @override
  String durationHoursMinutesLabel(int hours, int minutes) {
    return '${hours}j ${minutes}m';
  }

  @override
  String get settingsAccountTitle => 'Pengaturan Akun';

  @override
  String get parentAccountSubtitle => 'Akun orang tua PulangAman';

  @override
  String get notificationsSheetTitle => 'Notifikasi PulangAman';

  @override
  String get notificationsSheetBody =>
      'Notifikasi dipakai untuk Kabar, SOS, dan zona aman. Atur izinnya di Pengaturan sistem HP (Aplikasi > PulangAman > Notifikasi).';

  @override
  String get remindersTitle => 'Pengingat Jadwal';

  @override
  String get remindersLoadError =>
      'Gagal memuat jadwal. Periksa koneksi, lalu coba lagi.';

  @override
  String reminderPresetSaved(String title) {
    return 'Pengingat \"$title\" disimpan.\nBuka PulangAman di HP anak supaya jadwal aktif.';
  }

  @override
  String get reminderEditTitle => 'Ubah pengingat';

  @override
  String get reminderCustomTitle => 'Pengingat kustom';

  @override
  String get reminderTitleFieldLabel => 'Judul';

  @override
  String get reminderMessageFieldLabel => 'Pesan';

  @override
  String get reminderTimeQuestion => 'Jam berapa?';

  @override
  String get reminderPickTimeHelp => 'Pilih jam pengingat';

  @override
  String get reminderUseThisTime => 'Pakai jam ini';

  @override
  String get reminderHourLabel => 'Jam';

  @override
  String get reminderMinuteLabel => 'Menit';

  @override
  String get reminderStyleFullscreen => 'Layar penuh';

  @override
  String get reminderStyleNotification => 'Notifikasi';

  @override
  String get reminderEveryDay => 'Setiap hari';

  @override
  String get reminderSaveChanges => 'Simpan perubahan';

  @override
  String get reminderTitleBodyRequired => 'Judul dan pesan wajib diisi';

  @override
  String get reminderInfoBanner =>
      'HP anak akan menampilkan pesan besar di jam tertentu. Anak cukup tekan “Mengerti” untuk menutup.';

  @override
  String get reminderNoChildrenMessage =>
      'Hubungkan anak dulu sebelum membuat pengingat.';

  @override
  String get sectionForChild => 'UNTUK ANAK';

  @override
  String get sectionQuickAdd => 'TAMBAH CEPAT';

  @override
  String get reminderActiveScheduleTitle => 'Jadwal Aktif';

  @override
  String get reminderAddShort => '+ Tambah';

  @override
  String get reminderEmptyMessage =>
      'Belum ada pengingat. Pakai tambah cepat di atas.';

  @override
  String get reminderStudyChipLabel => 'Belajar 19:00';

  @override
  String get reminderSleepChipLabel => 'Tidur 21:00';

  @override
  String get reminderStudyPresetTitle => 'Waktunya Belajar';

  @override
  String get reminderStudyPresetBody =>
      'Sekarang jam belajar. Matikan game dulu ya.';

  @override
  String get reminderSleepPresetTitle => 'Waktunya Tidur';

  @override
  String get reminderSleepPresetBody =>
      'Sudah malam. Waktunya istirahat agar besok semangat.';

  @override
  String get parentHomeNoChildrenMessage =>
      'Ketuk “Tambah anak” di bawah untuk buat kode, lalu masukkan di HP anak. Jika ganti cara masuk, pulihkan dulu dari nomor lama.';

  @override
  String get recoverChildrenButton => 'Pulihkan anak dari nomor lama';

  @override
  String get childLocationSectionTitle => 'Lokasi Anak';

  @override
  String get viewMapAction => 'Lihat peta ›';

  @override
  String get todaySummaryTitle => 'Ringkasan Hari Ini';

  @override
  String get placesVisitedLabel => 'Lokasi dikunjungi';

  @override
  String get totalTripDistanceLabel => 'Total perjalanan';

  @override
  String get pendingCodesTitle => 'Kode menunggu';

  @override
  String relinkReplaceConfirmBody(String name) {
    return 'Sudah ada kode menunggu untuk $name. Buat kode baru? Kode lama tidak akan berlaku lagi.';
  }

  @override
  String get generateNewCodeAction => 'Buat baru';

  @override
  String get recoverChildrenTitle => 'Pulihkan anak';

  @override
  String get recoverChildrenPrompt =>
      'Masukkan nomor yang dipakai akun orang tua sebelumnya.';

  @override
  String get oldPhoneNumberLabel => 'Nomor lama';

  @override
  String get recoverAction => 'Pulihkan';

  @override
  String recoverChildrenSuccess(int count) {
    return 'Berhasil memulihkan $count anak. Lalu buat kode masuk ulang di menu anak.';
  }

  @override
  String get recoverChildrenNone =>
      'Tidak ada anak yang dipindahkan. Cek nomor lama.';

  @override
  String recoverChildrenFailed(String error) {
    return 'Gagal memulihkan: $error';
  }

  @override
  String relinkCodeTitle(String name) {
    return 'Kode masuk ulang $name';
  }

  @override
  String createCodeFailed(String error) {
    return 'Gagal buat kode: $error';
  }

  @override
  String removeChildConfirmTitle(String name) {
    return 'Hapus $name?';
  }

  @override
  String removeChildConfirmBody(String name) {
    return '$name akan dihapus dari daftar Anda. Berbagi lokasi berhenti sampai Anda menambahkannya lagi dengan kode masuk baru.';
  }

  @override
  String childRemoved(String name) {
    return '$name dihapus';
  }

  @override
  String get addChildTitle => 'Tambah anak';

  @override
  String get createCodeAction => 'Buat kode';

  @override
  String get codeTitle => 'Kode';

  @override
  String get tapToViewStatus => 'Ketuk untuk lihat status';

  @override
  String get allChildrenArrived => 'Semua anak sudah sampai';

  @override
  String arrivedWaitingSummary(int arrived, int total, String names) {
    return '$arrived/$total sudah sampai - menunggu $names';
  }

  @override
  String get empBannerActiveTitle => 'Titik kumpul darurat aktif';

  @override
  String childNeedsHelp(String name) {
    return '$name butuh bantuan';
  }

  @override
  String withTapDetail(String time) {
    return '$time · Tap untuk detail';
  }

  @override
  String get navChildrenLabel => 'Anak';

  @override
  String get navZonesLabel => 'Zona';

  @override
  String get navMoreLabel => 'Lainnya';

  @override
  String get moreScreenTitle => 'Fitur Lainnya';

  @override
  String get moreScreenSubtitle => 'Kelola pengaturan & tambahan';

  @override
  String get activeRemindersStatLabel => 'Pengingat Aktif';

  @override
  String get totalPointsStatLabel => 'Total Poin';

  @override
  String get sectionScheduleActivity => 'JADWAL & AKTIVITAS';

  @override
  String get sectionSafety => 'KEAMANAN';

  @override
  String get sectionSettings => 'PENGATURAN';

  @override
  String get noPointsNoStreak => '0 poin · Belum ada streak';

  @override
  String pointsCountLabel(int points) {
    return '$points poin';
  }

  @override
  String get noGuardiansYet => 'Belum ada wali';

  @override
  String guardiansCountLabel(int count) {
    return '$count wali';
  }

  @override
  String get noReportsYet => 'Belum ada laporan';

  @override
  String reportsCountLabel(int count) {
    return '$count laporan';
  }

  @override
  String get emergencyMeetingMenuSubtitle => 'Lokasi bertemu saat darurat';

  @override
  String get accountSettingsMenuSubtitle => 'Notifikasi, privasi, keluar';

  @override
  String get allKabarMarkedRead => 'Semua kabar ditandai sudah dibaca';

  @override
  String get kabarHistoryTitle => 'Riwayat Kabar';

  @override
  String get noKabarYet => 'Belum ada kabar';

  @override
  String kabarSummaryUnread(int unread, int total) {
    return '$unread belum dibaca · $total kabar · 24 jam terakhir';
  }

  @override
  String kabarSummaryAll(int total) {
    return '$total kabar · 24 jam terakhir';
  }

  @override
  String get noKabarForFilter => 'Belum ada kabar untuk filter ini.';

  @override
  String get giveRewardTitle => 'Kasih pujian';

  @override
  String get rewardReasonLabel => 'Alasan (opsional)';

  @override
  String get rewardReasonHint => 'Contoh: Rajin belajar hari ini';

  @override
  String get addFivePointsAction => 'Tambah +5';

  @override
  String get defaultPraiseReason => 'Pujian dari orang tua';

  @override
  String get pointsAddedSnackbar => '+5 poin ditambahkan';

  @override
  String get pickChildTitle => 'Pilih anak';

  @override
  String get rewardsTitle => 'Hadiah & Poin';

  @override
  String get givePraiseFabLabel => 'Kasih Pujian (+5)';

  @override
  String get rewardsIntro =>
      'Poin dikumpulkan saat anak tiba di sekolah tepat waktu. Bisa juga ditambah manual sebagai pujian.';

  @override
  String get howToEarnPointsTitle => 'Cara Mendapat Poin';

  @override
  String get howToEarnPointsReferenceTitle => 'Cara poin didapat (referensi)';

  @override
  String get earnSchoolOnTimeTitle => 'Tiba di Sekolah Tepat Waktu';

  @override
  String get earnSchoolOnTimeSubtitle => '+10 poin per hari';

  @override
  String get earnHomeOnTimeTitle => 'Pulang Tepat Waktu';

  @override
  String get earnHomeOnTimeSubtitle => '+5 poin per hari';

  @override
  String get earnParentPraiseTitle => 'Pujian dari Orang Tua';

  @override
  String get earnParentPraiseSubtitle => '+5 poin manual';

  @override
  String get earnPerDayLabel => 'per hari';

  @override
  String get earnManualLabel => 'manual';

  @override
  String get pointsHistoryTitle => 'Riwayat Poin';

  @override
  String get noPointsHistoryTitle => 'Belum ada riwayat poin';

  @override
  String get noPointsHistoryMessage =>
      'Setelah anak check-in sekolah, poin muncul di sini.';

  @override
  String totalPointsForChild(String name) {
    return 'Total Poin $name';
  }

  @override
  String get noStreakYet => 'Belum ada streak harian';

  @override
  String streakDaysLabel(int streak) {
    return 'Rajin $streak hari berturut-turut';
  }

  @override
  String get earnExampleHint => 'Contoh: tiba di sekolah +10 poin';

  @override
  String get weeklyStreakTitle => 'Streak Minggu Ini';

  @override
  String get screenTimeMonitorSubtitle => 'Pantau penggunaan harian';

  @override
  String get noAppDataToday => 'Belum ada data app hari ini.';

  @override
  String get appUsageTitle => 'Penggunaan Aplikasi';

  @override
  String get thisWeekTitle => 'Minggu Ini';

  @override
  String get limitScheduleTitle => 'Jadwal Batasan';

  @override
  String get editInRulesHint => 'Ubah di Aturan';

  @override
  String get todayLabel => 'Hari ini';

  @override
  String get limitOffLabel => 'Batas dimatikan';

  @override
  String outOfLimitLabel(String limit) {
    return 'dari batas $limit';
  }

  @override
  String remainingTimeLabel(String remaining) {
    return 'Sisa $remaining';
  }

  @override
  String overLimitLegend(String limit) {
    return 'Melebihi batas ($limit)';
  }

  @override
  String get safeLegendLabel => 'Aman';

  @override
  String get noActiveScheduleLabel => 'Tidak ada jadwal aktif';

  @override
  String screenTimeRulesTitle(String name) {
    return 'Aturan · $name';
  }

  @override
  String get limitScreenUsageLabel => 'Batasi main HP';

  @override
  String get noLimitLabel => 'Tanpa batas';

  @override
  String get schoolDaysTitle => 'Hari Sekolah';

  @override
  String get schoolDaysRangeLabel => 'Sen–Jum';

  @override
  String get weekendDaysTitle => 'Akhir Pekan';

  @override
  String get weekendDaysRangeLabel => 'Sab–Min';

  @override
  String maxLimitLabel(String limit) {
    return 'Maks $limit';
  }

  @override
  String get blockedAppsTitle => 'App yang ditahan';

  @override
  String get noAppListYet => 'Belum ada daftar app.';

  @override
  String get notUsedTodayLabel => 'Belum dipakai hari ini';

  @override
  String usedDurationLabel(String duration) {
    return 'Dipakai $duration';
  }

  @override
  String get schoolLimitPickerTitle => 'Batas hari sekolah';

  @override
  String get weekendLimitPickerTitle => 'Batas akhir pekan';

  @override
  String get savingLabel => 'Menyimpan...';

  @override
  String rulesSavedMessage(String name) {
    return 'Aturan tersimpan untuk $name. Buka PulangAman di HP anak supaya aktif.';
  }

  @override
  String limitsDisabledMessage(String name) {
    return 'Batas waktu dimatikan untuk $name.';
  }

  @override
  String get whereTitle => 'Di mana';

  @override
  String get childPositionsTodayTitle => 'Posisi anak hari ini';

  @override
  String get whereScreenIntro =>
      'Bukan cuma sekolah — rumah, perjalanan, dan zona aman lain ikut terlihat. Ketuk anak untuk lihat catatan masuk/pulang sekolah.';

  @override
  String get locationUnclear => 'Lokasi belum jelas';

  @override
  String get inHomeZoneHint => 'Di zona rumah yang kamu atur';

  @override
  String get inSchoolZoneHint => 'Di zona sekolah yang kamu atur';

  @override
  String get commutingHint => 'Sedang di perjalanan';

  @override
  String get locationHintDefault =>
      'Pastikan lokasi anak aktif & lokasi penting sudah diisi';

  @override
  String whereDetailTitle(String name) {
    return 'Di mana · $name';
  }

  @override
  String get zoneStatusExplain =>
      'Status dari zona aman yang kamu atur (rumah, sekolah, atau lainnya).';

  @override
  String get schoolNotesToday => 'Catatan sekolah hari ini';

  @override
  String get schoolNotesHint =>
      'Muncul otomatis saat anak masuk/keluar zona sekolah.';

  @override
  String get noSchoolNotesTitle => 'Belum ada catatan sekolah';

  @override
  String get noSchoolNotesMessage =>
      'Kalau zona sekolah sudah diatur dan lokasi anak aktif, catatan tiba/pulang akan muncul di sini.';

  @override
  String get arrivedAtSchool => 'Tiba di sekolah';

  @override
  String get departedFromSchool => 'Pulang dari sekolah';

  @override
  String get statusHomeLabel => 'Di rumah';

  @override
  String get statusSchoolLabel => 'Di sekolah';

  @override
  String get statusSafeZoneLabel => 'Di zona aman';

  @override
  String get statusCommutingLabel => 'Dalam perjalanan';

  @override
  String get categoryHazardTitle => 'Bahaya / Jalan Rusak';

  @override
  String get categoryTrafficTitle => 'Lalu Lintas';

  @override
  String get categoryCrowdTitle => 'Kerumunan';

  @override
  String get categoryOtherTitle => 'Laporan Lain';

  @override
  String get categoryHazardShort => 'Hazard';

  @override
  String get categoryTrafficShort => 'Lalu lintas';

  @override
  String get categoryCrowdShort => 'Kerumunan';

  @override
  String get categoryOtherShort => 'Lainnya';

  @override
  String get addPinTitle => 'Tambah Pin';

  @override
  String get reportTypeLabel => 'Jenis';

  @override
  String get reportTypeHazard => 'Bahaya / Jalan rusak';

  @override
  String get reportNoteLabel => 'Catatan';

  @override
  String get reportNoteHint => 'Contoh: Jalan rusak';

  @override
  String get reportNoteHintVr => 'cth. Lubang di dekat zebra cross';

  @override
  String get reportLocationDefault =>
      'Lokasi: memakai titik default (izin GPS belum ada)';

  @override
  String reportLocationCoords(String lat, String lng) {
    return 'Lokasi: $lat, $lng';
  }

  @override
  String get savePinAction => 'Simpan Pin';

  @override
  String get pinAddedSnackbar => 'Pin ditambahkan';

  @override
  String get reportVerifiedSnackbar => 'Laporan diverifikasi';

  @override
  String verifyFailed(String error) {
    return 'Gagal verifikasi: $error';
  }

  @override
  String get alreadyVerifiedThanks => 'Sudah terverifikasi. Terima kasih.';

  @override
  String get fixedSuggestionNoted =>
      'Terima kasih. Saran “sudah diperbaiki” dicatat untuk ditinjau.';

  @override
  String get communityReportsTitle => 'Laporan Komunitas';

  @override
  String get reportsInfoBanner =>
      'Pin kadaluarsa 72 jam kecuali diverifikasi. Tidak ada marketplace orang asing.';

  @override
  String get totalReportsLabel => 'Total Laporan';

  @override
  String get verifiedLabel => 'Terverifikasi';

  @override
  String get expiredLabel => 'Kadaluarsa';

  @override
  String get areaMapTitle => 'Peta Area';

  @override
  String get reportsListTitle => 'Daftar Laporan';

  @override
  String get activeLabel => 'Aktif';

  @override
  String get filterLabel => 'Filter';

  @override
  String get noActiveReports => 'Belum ada laporan aktif';

  @override
  String get noCoordinatesLabel => 'Tanpa koordinat';

  @override
  String get coordinatesAvailableLabel => 'Koordinat tersedia';

  @override
  String expiresAtLabel(String date) {
    return 'Kadaluarsa $date';
  }

  @override
  String get stillThereAction => 'Masih Ada';

  @override
  String get fixedAction => 'Sudah Diperbaiki';

  @override
  String get pinLocationLabel => 'Lokasi';

  @override
  String get usingCurrentLocation => 'Menggunakan lokasi saat ini';

  @override
  String get changeLocationAction => 'Ubah';

  @override
  String get whatAreYouReporting => 'Apa yang kamu laporkan?';

  @override
  String get shortNoteOptional => 'Catatan singkat (opsional)';

  @override
  String get verifiedBadge => 'VERIFIED';

  @override
  String nearPlaceLabel(String place) {
    return 'dekat $place';
  }

  @override
  String approxMetersFromPlace(int meters, String place) {
    return '~${meters}m dari $place';
  }

  @override
  String get pickPinLocationTitle => 'Pilih lokasi pin';

  @override
  String get resolvingLocation => 'Mencari lokasi...';

  @override
  String get locationUnknown => 'Lokasi tidak tersedia';

  @override
  String get presetAtSchoolText => 'Sudah sampai sekolah!';

  @override
  String get presetAtHomeText => 'Sudah sampai di rumah.';

  @override
  String get presetNeedHelpText => 'Butuh bantuan — tolong hubungi saya.';

  @override
  String get homeArrivedStatus => 'Di rumah · Sudah sampai';

  @override
  String hereAtTime(String time) {
    return 'Di sini · $time';
  }

  @override
  String get waitingGpsSignal => 'Menunggu sinyal lokasi...';

  @override
  String get atHomeTrackingStopped => 'Di rumah · jejak dihentikan';

  @override
  String get locationNotUpdatedRecently =>
      'Lokasi tidak diperbarui baru-baru ini';

  @override
  String get movingNow => 'Sedang bergerak';

  @override
  String get liveJustNow => 'Live · baru saja';

  @override
  String liveSecondsAgo(int seconds) {
    return 'Live · $seconds dtk lalu';
  }

  @override
  String liveMinutesAgo(int minutes) {
    return 'Live · $minutes mnt lalu';
  }

  @override
  String zoneNameActive(String name) {
    return '$name · aktif';
  }

  @override
  String zoneNameWithCount(String name, int count) {
    return '$name · $count zona';
  }

  @override
  String safeZonesCount(int count) {
    return '$count zona aman';
  }

  @override
  String zonesSummaryActiveCount(int count, int active) {
    return '$count zona · $active aktif sekarang';
  }

  @override
  String get noZonesYet => 'Belum ada zona';

  @override
  String get addHomeOrSchoolHint => 'Tambah rumah atau sekolah';

  @override
  String get remindersNoneActive => 'Tidak ada yang aktif';

  @override
  String remindersActiveCount(int count) {
    return '$count aktif';
  }

  @override
  String remindersActiveNext(int count, String title, String time) {
    return '$count aktif · berikutnya $title $time';
  }

  @override
  String get chargingShortSuffix => ' · cas';

  @override
  String batteryPercentLabel(int value) {
    return 'Baterai $value%';
  }

  @override
  String batteryPercentCharging(int value) {
    return 'Baterai $value% · di-cas';
  }

  @override
  String get batteryUnknown => 'Baterai belum diketahui';

  @override
  String get weakSignalRoute => 'Sinyal lemah — rute kurang akurat.';

  @override
  String get beingMonitored => 'Sedang dipantau';

  @override
  String get locationCannotUpdate => 'Lokasi tidak bisa diperbarui';

  @override
  String get adminAllChildren => 'Admin · Semua anak';

  @override
  String waitingWithNames(String names) {
    return 'Menunggu · $names';
  }

  @override
  String activeWithNames(String names) {
    return 'Aktif · $names';
  }

  @override
  String get zeroGuardiansAdd => '0 wali · Tambah wali';

  @override
  String guardiansCountNamed(int count, String names) {
    return '$count wali · $names';
  }

  @override
  String guardiansCountOnly(int count) {
    return '$count wali';
  }

  @override
  String guardiansForChildTitle(String name) {
    return 'Wali · $name';
  }

  @override
  String get noGuardiansForChild => 'Belum ada wali untuk anak ini.';

  @override
  String get youBadge => 'ANDA';

  @override
  String get doneAction => 'Selesai';

  @override
  String get editChevron => 'Edit ›';

  @override
  String get notConfiguredTapSearch => 'Belum diatur — ketuk untuk cari';

  @override
  String get noPlacesYetAddHomeSchool =>
      'Belum ada lokasi. Tambah rumah atau sekolah.';

  @override
  String get noPlacesMatch => 'Tidak ada lokasi yang cocok.';

  @override
  String get homePlaceLabel => 'Rumah';

  @override
  String get schoolPlaceLabel => 'Sekolah';

  @override
  String get parentRoleFallback => 'Orang tua';

  @override
  String get hereNowLabel => 'Di sini';

  @override
  String get waitingLocationDots => 'Menunggu lokasi...';

  @override
  String get seenOnMap => 'Terlihat di peta';

  @override
  String get signalStrong => 'Kuat';

  @override
  String get signalMedium => 'Sedang';

  @override
  String get signalWeak => 'Lemah';

  @override
  String get signalLost => 'Hilang';

  @override
  String get activeBadgeShort => 'AKTIF';

  @override
  String get staleBadgeShort => 'LAMA';

  @override
  String get batteryMetricLabel => 'Baterai';

  @override
  String get signalMetricLabel => 'Sinyal';

  @override
  String get timeMetricLabel => 'Waktu';

  @override
  String get optionsTooltip => 'Opsi';

  @override
  String get removeFromList => 'Hapus dari daftar';

  @override
  String relinkCodeMenu(String name) {
    return 'Kode masuk ulang $name';
  }

  @override
  String get noSignalYet => 'Belum ada sinyal';

  @override
  String updatedAtTime(String time) {
    return 'Update $time';
  }

  @override
  String get batteryDeadBanner =>
      'HP anak hampir habis / mati. Lokasi mungkin tidak diperbarui.';

  @override
  String batteryLowBanner(String level) {
    return 'Baterai HP anak lemah ($level%).';
  }

  @override
  String get locationStaleBanner =>
      'Sinyal lokasi lama. HP anak mungkin mati atau tanpa jaringan.';

  @override
  String get screenLimitsOff => 'Batasan dimatikan';

  @override
  String screenUsedToday(String used, String limit) {
    return '$used / $limit hari ini';
  }

  @override
  String limitCaptionShort(String limit) {
    return 'batas $limit';
  }

  @override
  String unreadKabarCount(int count) {
    return '$count belum dibaca';
  }

  @override
  String get noTrailToday => 'Belum ada jejak hari ini.';

  @override
  String get safeZoneFeatureTitle => 'Zona aman';

  @override
  String get parentKabarFeatureTitle => 'Kabar';

  @override
  String get remindersFeatureTitle => 'Pengingat';

  @override
  String get todaySectionTitle => 'Hari ini';

  @override
  String get safePlaceLabel => 'Lokasi aman';

  @override
  String get placesCountLabel => 'lokasi';

  @override
  String get girlChildLabel => 'Anak perempuan';

  @override
  String get boyChildLabel => 'Anak laki-laki';

  @override
  String get noActiveAlerts => 'Tidak ada peringatan aktif';

  @override
  String get invitesSectionTitle => 'Undangan';

  @override
  String childIdLabel(String id) {
    return 'Anak: $id';
  }

  @override
  String get childFallbackName => 'Anak';

  @override
  String get guardianFallbackName => 'Wali';

  @override
  String get needExtraHelpNote => 'Memerlukan bantuan tambahan';

  @override
  String get resolvedByParentNote => 'Diselesaikan orang tua';

  @override
  String get sendResponseFailed => 'Gagal mengirim respons. Coba lagi.';

  @override
  String get resolvePanicFailed => 'Gagal menyelesaikan panik. Coba lagi.';

  @override
  String get panicBadge => 'PANIK';

  @override
  String get childInSafeZoneTitle => 'Anak di zona aman';

  @override
  String get zoneUpdateTitle => 'Update zona';

  @override
  String arrivedAtZoneMsg(String childName, String zoneLabel) {
    return '$childName sudah sampai di $zoneLabel';
  }

  @override
  String childInSafeZoneMsg(String childName) {
    return '$childName sudah di zona aman';
  }

  @override
  String leftSafeZoneMsg(String childName) {
    return '$childName meninggalkan zona aman';
  }

  @override
  String get newKabarBanner => 'Kabar baru';

  @override
  String get shortTrailLabel => 'Jejak singkat';

  @override
  String get importantPlacesLabel => 'Zona Aman';

  @override
  String get zonesHubTitle => 'Zona Aman';

  @override
  String get zonesHubSubtitle => 'Rumah, sekolah, dan lokasi sering dikunjungi';

  @override
  String get searchPlaceHint => 'Cari lokasi...';

  @override
  String get addNewPlaceLabel => 'Tambah lokasi baru';

  @override
  String estimateMinutes(int minutes) {
    return 'Estimasi $minutes menit';
  }

  @override
  String get noAddressYet => 'Belum ada alamat';

  @override
  String get extraSafePlace => 'Lokasi aman tambahan';

  @override
  String get searchHomeAddress => 'Cari alamat rumah';

  @override
  String get searchSchoolName => 'Cari nama sekolah';

  @override
  String searchCustomPlace(String label) {
    return 'Cari lokasi: $label';
  }

  @override
  String get homeSearchHint => 'Contoh: Marine Parade, kode pos, nama kompleks';

  @override
  String get schoolSearchHint => 'Contoh: Tao Nan School, nama sekolah';

  @override
  String get customSearchHint => 'Contoh: nama les, mall, taman, alamat';

  @override
  String placeSavedSnack(String name) {
    return 'Disimpan: $name';
  }

  @override
  String failedSavePlace(String error) {
    return 'Gagal simpan lokasi: $error';
  }

  @override
  String get placeLessonSuggestion => 'Lokasi les';

  @override
  String get placeGrandmaSuggestion => 'Rumah nenek';

  @override
  String get newPlaceDefault => 'Lokasi baru';

  @override
  String get addSafePlaceTitle => 'Tambah lokasi aman';

  @override
  String get customPlaceHint => 'Contoh: Les piano Blok M';

  @override
  String get continueSearchAddress => 'Lanjut cari alamat';

  @override
  String get otherPlaceLabel => 'Lokasi lain';

  @override
  String get deletePlaceTitle => 'Hapus lokasi?';

  @override
  String deletePlaceConfirm(String name) {
    return 'Hapus \"$name\"? Rute aman yang terhubung ke lokasi ini juga akan dihapus.';
  }

  @override
  String get deletePlaceCascadeNote =>
      'Rute aman yang terhubung ke lokasi ini juga akan dihapus.';

  @override
  String get placeDeletedSnack => 'Lokasi dihapus';

  @override
  String failedDeletePlace(String error) {
    return 'Gagal hapus: $error';
  }

  @override
  String placesForChildLabel(String name) {
    return 'Lokasi $name';
  }

  @override
  String get addChildBeforeInvite => 'Tambah anak dulu sebelum undang wali';

  @override
  String get inviteViaWhatsApp => 'Undang via WhatsApp';

  @override
  String get inviteViaEmail => 'Undang via Email';

  @override
  String get inviteViaLink => 'Undang via Link';

  @override
  String get guardianNameLabel => 'Nama wali';

  @override
  String get phoneWhatsAppLabel => 'Nomor WhatsApp / telepon';

  @override
  String get emailOptionalLabel => 'Email (opsional)';

  @override
  String get namePhoneRequired => 'Nama dan nomor wajib diisi';

  @override
  String get inviteLinkCopied => 'Link undangan disalin';

  @override
  String inviteFailedDetail(String error) {
    return 'Gagal undang: $error';
  }

  @override
  String failedGenericDetail(String error) {
    return 'Gagal: $error';
  }

  @override
  String get guardiansInviteHint =>
      'Undang wali yang sudah dikenal. Tidak ada pencarian orang asing — hanya orang yang kamu percaya.';

  @override
  String get activeGuardiansSection => 'WALI AKTIF';

  @override
  String get inviteNewSection => 'UNDANG WALI BARU';

  @override
  String get addTrustedGuardian => 'Tambah Wali Terpercaya';

  @override
  String get guardianInviteChannelHint =>
      'Wali akan menerima undangan via WhatsApp atau email';

  @override
  String guardianInviteBody(String name, String children, String link) {
    return 'Halo $name, kamu diundang jadi Wali Terpercaya untuk $children di PulangAman. Buka undangan: $link';
  }

  @override
  String get guardianInviteSubject => 'Undangan Wali Terpercaya PulangAman';

  @override
  String activeGuardiansCount(int count) {
    return '$count wali aktif';
  }

  @override
  String get channelWhatsApp => 'WhatsApp';

  @override
  String get channelEmail => 'Email';

  @override
  String get channelLink => 'Link';

  @override
  String get justNowRelative => 'baru saja';

  @override
  String minutesAgoRelative(int minutes) {
    return '$minutes mnt lalu';
  }

  @override
  String get noLocationYet => 'Belum ada lokasi';

  @override
  String get sessionTokenFailed => 'Gagal mengambil token sesi. Coba lagi.';

  @override
  String get phoneNotFoundRelogin =>
      'Nomor telepon tidak ditemukan. Keluar lalu masuk ulang.';

  @override
  String get phoneInvalidFormat =>
      'Nomor telepon tidak valid. Gunakan format +62...';

  @override
  String get placesApiKeyHint =>
      'Perlu key server terpisah: aktifkan Places API + Geocoding.';

  @override
  String get forChildLabel => 'Untuk anak';

  @override
  String get phoneCountryCode => '+62';

  @override
  String get accessPerChildSection => 'AKSES PER ANAK';

  @override
  String get revokeAccessTooltip => 'Cabut akses';

  @override
  String get alertAcknowledged => 'Peringatan direspons';

  @override
  String get alertAcknowledgedCascadeStopped =>
      'Peringatan direspons. Cascade dihentikan.';

  @override
  String alertLabelWithId(String id) {
    return 'Peringatan $id';
  }

  @override
  String fromParentLabel(String name) {
    return 'Dari $name';
  }

  @override
  String pickAvatarTitle(String name) {
    return 'Pilih wajah untuk $name';
  }

  @override
  String get pickAvatarHint =>
      'Pilih laki-laki atau perempuan. Foto anak tidak dipakai demi privasi.';

  @override
  String get changeAvatarAction => 'Ubah wajah avatar';

  @override
  String get placeFriendSuggestion => 'Teman';

  @override
  String get placeMallSuggestion => 'Mall / lokasi main';

  @override
  String get customPlaceDialogHint =>
      'Pilih jenis, atau tulis sendiri. Lalu cari alamatnya.';

  @override
  String get routeBadge => 'RUTE';

  @override
  String trailPointsCount(int count) {
    return '$count titik jalur';
  }

  @override
  String hoursAgoRelative(int hours) {
    return '$hours jam lalu';
  }

  @override
  String daysAgoRelative(int days) {
    return '$days hari lalu';
  }

  @override
  String get yesterdayLabel => 'Kemarin';

  @override
  String lastSeenLabel(String when) {
    return 'Terakhir terlihat: $when';
  }

  @override
  String get tooManyAttempts => 'Terlalu banyak percobaan. Coba lagi nanti.';

  @override
  String get invalidOtpCode => 'Kode OTP salah.';

  @override
  String get otpExpiredResend => 'Kode OTP kedaluwarsa. Kirim ulang.';

  @override
  String get appConfigIncomplete =>
      'Konfigurasi aplikasi belum lengkap. Hubungi pengembang.';

  @override
  String get serverMissingCustomToken =>
      'Server tidak mengembalikan customToken. Deploy API terbaru dulu.';

  @override
  String get startMonitoringAction => 'Mulai pantau';

  @override
  String get openLocationAction => 'Buka lokasi';

  @override
  String get orTypeOwnNameLabel => 'Atau tulis nama sendiri';

  @override
  String get todayShortLabel => 'Hari ini';

  @override
  String get thisWeekLabel => 'Minggu ini';

  @override
  String get thisMonthLabel => 'Bulan ini';

  @override
  String get weekShortLabel => 'Minggu';

  @override
  String get monthShortLabel => 'Bulan';

  @override
  String get dayShortLabel => 'Hari';

  @override
  String durationMinutesOnly(int minutes) {
    return '$minutes mnt';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours jam $minutes mnt';
  }

  @override
  String get otpSendTimedOut => 'Pengiriman kode terlalu lama. Coba lagi.';

  @override
  String get recoverParentsOnly =>
      'Hanya orang tua yang sedang masuk yang bisa memulihkan.';

  @override
  String get activityLoadFailed => 'Riwayat hari ini belum bisa dimuat';

  @override
  String get greetingMorning => 'Selamat pagi';

  @override
  String get greetingMidday => 'Selamat siang';

  @override
  String get greetingAfternoon => 'Selamat sore';

  @override
  String get greetingNight => 'Selamat malam';

  @override
  String get periodMorningShort => 'Pagi';

  @override
  String get periodMiddayShort => 'Siang';

  @override
  String get periodAfternoonShort => 'Sore';

  @override
  String get periodNightShort => 'Malam';

  @override
  String get menuLabel => 'Menu';

  @override
  String get brandNameUpper => 'PULANGAMAN';

  @override
  String get premiumFamilyMapTitle => 'PETA KELUARGA';

  @override
  String get premiumLiveLabel => 'Langsung';

  @override
  String get premiumFamilyMapHint => 'Satu panggung — semua anak';

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
      other: 'Semua anak dalam jangkauan aman.',
      one: 'Satu anak dalam jangkauan aman.',
    );
    return '$_temp0';
  }

  @override
  String premiumChildrenTracked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anak dipantau.',
      one: '1 anak dipantau.',
    );
    return '$_temp0';
  }

  @override
  String premiumBatteryLowDetail(int percent) {
    return 'Baterai $percent%';
  }

  @override
  String get premiumChargeSoonMeta => 'segera dicas';

  @override
  String get settingsPremiumHomeShell => 'Tampilan editorial (Alt A)';

  @override
  String get settingsPremiumHomeShellHint =>
      'Tanpa bilah navigasi bawah. Nonaktifkan untuk kembali ke tampilan biasa.';

  @override
  String get updatedJustNowBadge => 'Baru saja diperbarui';

  @override
  String updatedMinutesAgoBadge(int minutes) {
    return 'Diperbarui $minutes mnt lalu';
  }

  @override
  String updatedHoursAgoBadge(int hours) {
    return 'Diperbarui $hours jam lalu';
  }

  @override
  String get relinkCodeShort => 'Kode masuk ulang';

  @override
  String newSignInCodeTitle(String name) {
    return 'Kode masuk baru untuk $name';
  }

  @override
  String newSignInCodeBody(String name) {
    return 'Masukkan kode ini di aplikasi $name saat memilih \"Sudah punya kode\" pada layar masuk.';
  }

  @override
  String get copyCodeAction => 'Salin kode';

  @override
  String get codeCopiedSnack => 'Kode disalin';

  @override
  String get codeValid24Hours => 'Berlaku 24 jam';

  @override
  String codeValidForHours(int hours) {
    return 'Berlaku $hours jam';
  }
}
