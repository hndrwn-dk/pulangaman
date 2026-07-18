import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class OfflineIntent {
  OfflineIntent({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}

/// Local queue for location + panic intents when offline.
class OfflineQueue {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'pulangaman_queue.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE intents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> enqueue(String kind, Map<String, dynamic> payload) async {
    final db = await _open();
    await db.insert('intents', {
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<OfflineIntent>> peekAll() async {
    final db = await _open();
    final rows = await db.query('intents', orderBy: 'id ASC');
    return rows
        .map(
          (row) => OfflineIntent(
            id: row['id'] as int,
            kind: row['kind'] as String,
            payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> remove(int id) async {
    final db = await _open();
    await db.delete('intents', where: 'id = ?', whereArgs: [id]);
  }
}
