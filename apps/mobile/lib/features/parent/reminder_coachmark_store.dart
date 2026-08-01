import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One-time "seen" flag for the parent Home reminder-discovery coachmark.
class ReminderCoachmarkStore {
  ReminderCoachmarkStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'reminder_coachmark_seen';

  Future<bool> hasSeen() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == '1' || raw?.toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
  }
}

final reminderCoachmarkStoreProvider =
    Provider<ReminderCoachmarkStore>((ref) => ReminderCoachmarkStore());
