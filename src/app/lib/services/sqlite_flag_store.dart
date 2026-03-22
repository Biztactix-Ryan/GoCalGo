import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'flag_store.dart';

/// SQLite-backed store that persists event flag state across app restarts.
///
/// Each flagged event is stored as a row with its event ID and a timestamp.
/// Unflagging removes the row. This ensures flags survive app restarts.
class SqliteFlagStore implements FlagStore {
  static const _tableName = 'flagged_events';
  static const _dbName = 'gocalgo_flags.db';

  final Future<Database> Function() _openDatabase;
  Database? _db;

  /// Creates a flag store backed by a SQLite database at the default path.
  SqliteFlagStore() : _openDatabase = _defaultOpen;

  /// Creates a flag store with a custom database opener (for testing).
  SqliteFlagStore.withOpener(Future<Database> Function() opener)
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
        event_id TEXT PRIMARY KEY,
        flagged_at TEXT NOT NULL
      )
    ''');
  }

  Future<Database> _getDb() async {
    _db ??= await _openDatabase();
    return _db!;
  }

  @override
  Future<void> flag(String eventId) async {
    final db = await _getDb();
    await db.insert(
      _tableName,
      {
        'event_id': eventId,
        'flagged_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> unflag(String eventId) async {
    final db = await _getDb();
    await db.delete(
      _tableName,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  @override
  Future<bool> isFlagged(String eventId) async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<Set<String>> flaggedIds() async {
    final db = await _getDb();
    final rows = await db.query(_tableName, columns: ['event_id']);
    return rows.map((r) => r['event_id'] as String).toSet();
  }

  @override
  Future<void> clearAll() async {
    final db = await _getDb();
    await db.delete(_tableName);
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
