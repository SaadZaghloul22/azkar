import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/arabic.dart';
import 'models.dart';

/// Local SQLite database. All core features work offline from here.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const schemaVersion = 1;
  static const contentAsset = 'assets/data/azkar.json';

  static Future<AppDatabase> open({String? path, String? contentJson}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'azkar.db');
    final db = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) => _createSchema(db),
      onUpgrade: (db, from, to) => _migrate(db, from, to),
    );
    final app = AppDatabase._(db);
    await app._syncContent(contentJson ?? await rootBundle.loadString(contentAsset));
    return app;
  }

  static Future<void> _createSchema(Database db) async {
    final b = db.batch();
    b.execute('''CREATE TABLE categories(
      id INTEGER PRIMARY KEY,
      key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      sort_order INTEGER NOT NULL)''');
    b.execute('''CREATE TABLE azkar(
      id INTEGER PRIMARY KEY,
      category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      search_text TEXT NOT NULL,
      repeat_count INTEGER NOT NULL DEFAULT 1,
      virtue TEXT,
      source TEXT,
      audio_path TEXT,
      is_verified INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0)''');
    b.execute('CREATE INDEX idx_azkar_category ON azkar(category_id, sort_order)');
    b.execute('''CREATE TABLE favorites(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      azkar_id INTEGER NOT NULL UNIQUE REFERENCES azkar(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL)''');
    b.execute('''CREATE TABLE recents(
      azkar_id INTEGER PRIMARY KEY REFERENCES azkar(id) ON DELETE CASCADE,
      used_at INTEGER NOT NULL)''');
    b.execute('CREATE INDEX idx_recents_used ON recents(used_at)');
    b.execute('''CREATE TABLE tasbeeh_sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tasbeeh_name TEXT NOT NULL,
      count INTEGER NOT NULL,
      target INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      completed_at INTEGER)''');
    b.execute('CREATE INDEX idx_tasbeeh_created ON tasbeeh_sessions(created_at)');
    b.execute('''CREATE TABLE custom_tasbeeh(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text TEXT NOT NULL UNIQUE,
      created_at INTEGER NOT NULL)''');
    b.execute('''CREATE TABLE user_settings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      setting_key TEXT NOT NULL UNIQUE,
      setting_value TEXT)''');
    b.execute('''CREATE TABLE daily_progress(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      morning_completed INTEGER NOT NULL DEFAULT 0,
      evening_completed INTEGER NOT NULL DEFAULT 0,
      sleep_completed INTEGER NOT NULL DEFAULT 0,
      total_tasbeeh INTEGER NOT NULL DEFAULT 0)''');
    b.execute('''CREATE TABLE custom_azkar(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      repeat_count INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL)''');
    await b.commit(noResult: true);
  }

  /// Future schema changes go here, one step per version, so user data is kept.
  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      switch (v) {
        default:
          break;
      }
    }
  }

  /// Loads bundled azkar when the bundled content version is newer than the stored one.
  /// IDs are stable (category index * 1000 + item index) so favorites survive updates.
  Future<void> _syncContent(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final version = data['version'] as int;
    final stored = int.tryParse(await getSetting('content_version') ?? '') ?? 0;
    if (stored >= version) return;
    final cats = (data['categories'] as List).cast<Map<String, dynamic>>();
    await db.transaction((txn) async {
      final b = txn.batch();
      for (var ci = 0; ci < cats.length; ci++) {
        final c = cats[ci];
        final catId = ci + 1;
        b.insert(
          'categories',
          {
            'id': catId,
            'key': c['id'],
            'name': c['name'],
            'icon': c['icon'],
            'sort_order': c['sort'] ?? ci,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final items = (c['items'] as List).cast<Map<String, dynamic>>();
        for (var i = 0; i < items.length; i++) {
          final z = items[i];
          b.insert(
            'azkar',
            {
              'id': catId * 1000 + i + 1,
              'category_id': catId,
              'title': z['title'],
              'content': z['content'],
              'search_text': normalizeArabic('${z['title']} ${z['content']}'),
              'repeat_count': z['repeat'] ?? 1,
              'virtue': z['virtue'],
              'source': z['source'],
              'audio_path': z['audio'],
              'is_verified': 1,
              'sort_order': i,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await b.commit(noResult: true);
    });
    await setSetting('content_version', '$version');
  }

  // ---------- settings table ----------
  Future<String?> getSetting(String key) async {
    final r = await db.query('user_settings',
        columns: ['setting_value'], where: 'setting_key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['setting_value'] as String?;
  }

  Future<void> setSetting(String key, String value) => db.insert(
        'user_settings',
        {'setting_key': key, 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ---------- categories & azkar ----------
  Future<List<Category>> categories() async {
    final r = await db.rawQuery('''SELECT c.*, COUNT(a.id) AS cnt FROM categories c
      LEFT JOIN azkar a ON a.category_id = c.id GROUP BY c.id ORDER BY c.sort_order''');
    return r.map(Category.fromMap).toList();
  }

  Future<Category?> categoryByKey(String key) async {
    final all = await categories();
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  Future<List<Zekr>> azkarOf(int categoryId) async {
    final r = await db.query('azkar',
        where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'sort_order');
    return r.map(Zekr.fromMap).toList();
  }

  Future<List<Zekr>> allAzkar() async {
    final r = await db.query('azkar', orderBy: 'category_id, sort_order');
    return r.map(Zekr.fromMap).toList();
  }

  Future<Zekr?> zekr(int id) async {
    final r = await db.query('azkar', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Zekr.fromMap(r.first);
  }

  Future<List<Zekr>> search(String query, {int? categoryId}) async {
    final q = normalizeArabic(query);
    final where = <String>[];
    final args = <Object>[];
    if (q.isNotEmpty) {
      where.add('search_text LIKE ?');
      args.add('%$q%');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    final r = await db.query('azkar',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'category_id, sort_order',
        limit: 200);
    return r.map(Zekr.fromMap).toList();
  }

  // ---------- favorites ----------
  Future<Set<int>> favoriteIds() async {
    final r = await db.query('favorites', columns: ['azkar_id']);
    return r.map((e) => e['azkar_id'] as int).toSet();
  }

  Future<List<Zekr>> favorites() async {
    final r = await db.rawQuery('''SELECT a.* FROM favorites f
      JOIN azkar a ON a.id = f.azkar_id ORDER BY f.created_at DESC''');
    return r.map(Zekr.fromMap).toList();
  }

  Future<void> addFavorite(int azkarId) => db.insert(
        'favorites',
        {'azkar_id': azkarId, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<void> removeFavorite(int azkarId) =>
      db.delete('favorites', where: 'azkar_id = ?', whereArgs: [azkarId]);

  // ---------- recents ----------
  Future<void> markRecent(int azkarId) => db.insert(
        'recents',
        {'azkar_id': azkarId, 'used_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Zekr>> recents({int limit = 20}) async {
    final r = await db.rawQuery('''SELECT a.* FROM recents r
      JOIN azkar a ON a.id = r.azkar_id ORDER BY r.used_at DESC LIMIT ?''', [limit]);
    return r.map(Zekr.fromMap).toList();
  }

  // ---------- custom azkar ----------
  Future<List<Zekr>> customAzkar() async {
    final r = await db.query('custom_azkar', orderBy: 'created_at DESC');
    return r.map(Zekr.fromCustom).toList();
  }

  Future<int> addCustomZekr(String title, String content, int repeat) => db.insert(
        'custom_azkar',
        {
          'title': title,
          'content': content,
          'repeat_count': repeat,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

  Future<void> updateCustomZekr(int id, String title, String content, int repeat) =>
      db.update('custom_azkar',
          {'title': title, 'content': content, 'repeat_count': repeat},
          where: 'id = ?', whereArgs: [id]);

  Future<void> deleteCustomZekr(int id) =>
      db.delete('custom_azkar', where: 'id = ?', whereArgs: [id]);

  // ---------- tasbeeh ----------
  Future<void> saveSession(TasbeehSession s) => db.insert('tasbeeh_sessions', {
        'tasbeeh_name': s.name,
        'count': s.count,
        'target': s.target,
        'created_at': s.createdAt.millisecondsSinceEpoch,
        'completed_at': s.completedAt?.millisecondsSinceEpoch,
      });

  Future<List<TasbeehSession>> sessions({int limit = 50}) async {
    final r = await db.query('tasbeeh_sessions',
        orderBy: 'created_at DESC', limit: limit);
    return r.map(TasbeehSession.fromMap).toList();
  }

  Future<void> clearSessions() => db.delete('tasbeeh_sessions');

  Future<List<String>> customTasbeeh() async {
    final r = await db.query('custom_tasbeeh', orderBy: 'created_at');
    return r.map((e) => e['text'] as String).toList();
  }

  Future<void> addCustomTasbeeh(String text) => db.insert(
        'custom_tasbeeh',
        {'text': text, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<void> deleteCustomTasbeeh(String text) =>
      db.delete('custom_tasbeeh', where: 'text = ?', whereArgs: [text]);

  // ---------- daily progress ----------
  Future<DailyProgress> progress(String date) async {
    final r = await db.query('daily_progress', where: 'date = ?', whereArgs: [date]);
    return r.isEmpty ? DailyProgress(date: date) : DailyProgress.fromMap(r.first);
  }

  Future<List<DailyProgress>> progressRange(String from, String to) async {
    final r = await db.query('daily_progress',
        where: 'date >= ? AND date <= ?', whereArgs: [from, to], orderBy: 'date');
    return r.map(DailyProgress.fromMap).toList();
  }

  Future<void> _ensureDay(String date) => db.insert(
        'daily_progress',
        {'date': date},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  /// [part] is one of: morning, evening, sleep.
  Future<void> markCompleted(String date, String part) async {
    await _ensureDay(date);
    await db.update('daily_progress', {'${part}_completed': 1},
        where: 'date = ?', whereArgs: [date]);
  }

  Future<void> addTasbeeh(String date, int n) async {
    await _ensureDay(date);
    await db.rawUpdate(
        'UPDATE daily_progress SET total_tasbeeh = total_tasbeeh + ? WHERE date = ?',
        [n, date]);
  }

  Future<void> close() => db.close();
}
