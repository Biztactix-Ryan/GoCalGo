import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'onboarding_store.dart';

/// SQLite-backed store that persists onboarding completion state.
///
/// Stores a single row indicating that onboarding has been completed.
/// This ensures the onboarding carousel is only shown once per device,
/// surviving app restarts.
class SqliteOnboardingStore implements OnboardingStore {
  static const _tableName = 'onboarding_state';
  static const _dbName = 'gocalgo_onboarding.db';
  static const _key = 'onboarding_complete';

  final Future<Database> Function() _openDatabase;
  Database? _db;

  /// Creates an onboarding store backed by a SQLite database at the default path.
  SqliteOnboardingStore() : _openDatabase = _defaultOpen;

  /// Creates an onboarding store with a custom database opener (for testing).
  SqliteOnboardingStore.withOpener(Future<Database> Function() opener)
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
        key TEXT PRIMARY KEY,
        completed_at TEXT NOT NULL
      )
    ''');
  }

  Future<Database> _getDb() async {
    _db ??= await _openDatabase();
    return _db!;
  }

  @override
  Future<bool> hasCompletedOnboarding() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_key],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> markOnboardingComplete() async {
    final db = await _getDb();
    await db.insert(
      _tableName,
      {
        'key': _key,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> resetOnboarding() async {
    final db = await _getDb();
    await db.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [_key],
    );
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
