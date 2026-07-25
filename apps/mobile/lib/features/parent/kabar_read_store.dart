import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'kabar_models.dart';

/// Local read cursor for parent kabar / panic banners.
/// History stays in Riwayat; only home badge + urgent banners use unread state.
class KabarReadStore {
  KabarReadStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'kabar_read_before';

  DateTime? _readBefore;
  bool _loaded = false;

  DateTime? get readBefore => _readBefore;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        _readBefore = DateTime.tryParse(raw);
      }
    } catch (_) {}
    _loaded = true;
  }

  /// Marks everything at or before [at] (default: now) as read.
  Future<void> markAllRead([DateTime? at]) async {
    await load();
    final stamp = (at ?? DateTime.now()).toUtc();
    if (_readBefore != null && stamp.isBefore(_readBefore!)) {
      return;
    }
    _readBefore = stamp;
    try {
      await _storage.write(key: _key, value: stamp.toIso8601String());
    } catch (_) {}
  }

  /// Marks this message and all older ones as read.
  Future<void> markReadThrough(ChildKabarMessage msg) async {
    await markAllRead(msg.sentAt.toUtc());
  }

  bool isUnread(ChildKabarMessage msg) {
    final before = _readBefore;
    if (before == null) return true;
    return msg.sentAt.toUtc().isAfter(before);
  }

  List<ChildKabarMessage> unreadOf(Iterable<ChildKabarMessage> all) {
    return all.where(isUnread).toList();
  }

  List<ChildKabarMessage> unreadUrgentOf(Iterable<ChildKabarMessage> all) {
    return all.where((m) => isUnread(m) && m.isUrgent).toList();
  }
}
