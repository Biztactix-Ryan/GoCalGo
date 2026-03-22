import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/events_response.dart';
import 'event_cache.dart';

/// SQLite-backed [EventCache] that persists event data across app restarts.
///
/// Stores the full [EventsResponse] JSON payload in a single-row table
/// alongside a `stored_at` timestamp for staleness detection.
class SqliteEventCache implements EventCache {
  static const _tableName = 'event_cache';
  static const _dbName = 'gocalgo_cache.db';

  final Future<Database> Function() _openDatabase;
  Database? _db;

  /// Creates a cache backed by a SQLite database at the default path.
  SqliteEventCache()
      : _openDatabase = _defaultOpen;

  /// Creates a cache with a custom database opener (for testing).
  SqliteEventCache.withOpener(Future<Database> Function() opener)
      : _openDatabase = opener;

  static Future<Database> _defaultOpen() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _createTable,
    );
  }

  static Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload TEXT NOT NULL,
        stored_at TEXT NOT NULL
      )
    ''');
  }

  Future<Database> _getDb() async {
    _db ??= await _openDatabase();
    return _db!;
  }

  @override
  Future<void> put(EventsResponse response) async {
    final db = await _getDb();
    await db.insert(
      _tableName,
      {
        'id': 1,
        'payload': jsonEncode(response.toJson()),
        'stored_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<EventsResponse?> get() async {
    final db = await _getDb();
    final rows = await db.query(_tableName, where: 'id = 1');
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['payload'] as String);
    return EventsResponse.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> clear() async {
    final db = await _getDb();
    await db.delete(_tableName);
  }

  /// Returns when the cache was last written, or `null` if empty.
  ///
  /// Useful for staleness detection outside the TTL decorator.
  Future<DateTime?> get storedAt async {
    final db = await _getDb();
    final rows = await db.query(_tableName, columns: ['stored_at'], where: 'id = 1');
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['stored_at'] as String);
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
