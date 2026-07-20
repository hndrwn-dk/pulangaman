import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'children_controller.dart';

/// Disk cache for parent children list (stale-while-revalidate).
class ChildrenLocalCache {
  ChildrenLocalCache._();
  static final ChildrenLocalCache instance = ChildrenLocalCache._();

  Future<File> _file(String parentKey) async {
    final dir = await getDatabasesPath();
    final safe = parentKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(dir, 'pa_children_$safe.json'));
  }

  Future<({List<ChildSummary> items, List<ChildInvite> invites})?> read(
    String parentKey,
  ) async {
    try {
      final file = await _file(parentKey);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return null;
      final items = (raw['children'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList();
      final invites = (raw['invites'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildInvite.fromJson)
          .where((i) => i.status == 'pending')
          .toList();
      return (items: items, invites: invites);
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String parentKey,
    required List<ChildSummary> items,
    required List<ChildInvite> invites,
  }) async {
    try {
      final file = await _file(parentKey);
      await file.writeAsString(
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'children': items.map((c) => c.toJson()).toList(),
          'invites': invites.map((i) => i.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  Future<void> clear(String parentKey) async {
    try {
      final file = await _file(parentKey);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
