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
  String homeBySummaryMaghrib(String status) {
    return 'Ikuti Maghrib · $status';
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
  String get tripNeedTwoPlaces => 'Tambah minimal dua tempat dulu';

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
}
