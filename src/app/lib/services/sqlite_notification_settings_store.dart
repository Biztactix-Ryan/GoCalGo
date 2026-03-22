import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/event_type.dart';
import 'notification_settings_store.dart';

/// SQLite-backed store that persists notification settings across app restarts.
///
/// Stores the master toggle, lead time, and enabled event types in a single
/// row keyed by a fixed key. Event types are stored as a comma-separated
/// list of their JSON values.
class SqliteNotificationSettingsStore implements NotificationSettingsStore {
  static const _tableName = 'notification_settings';
  static const _dbName = 'gocalgo_notification_settings.db';
  static const _settingsKey = 'default';

  final Future<Database> Function() _openDatabase;
  Database? _db;

  /// Creates a settings store backed by a SQLite database at the default path.
  SqliteNotificationSettingsStore() : _openDatabase = _defaultOpen;

  /// Creates a settings store with a custom database opener (for testing).
  SqliteNotificationSettingsStore.withOpener(Future<Database> Function() opener)
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
        enabled INTEGER NOT NULL DEFAULT 1,
        lead_time_minutes INTEGER NOT NULL DEFAULT 15,
        enabled_event_types TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<Database> _getDb() async {
    _db ??= await _openDatabase();
    return _db!;
  }

  @override
  Future<NotificationSettings> load() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_settingsKey],
    );
    if (rows.isEmpty) return NotificationSettings.defaults();

    final row = rows.first;
    return NotificationSettings(
      enabled: (row['enabled'] as int) == 1,
      leadTimeMinutes: row['lead_time_minutes'] as int,
      enabledEventTypes: _decodeEventTypes(row['enabled_event_types'] as String),
    );
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    final db = await _getDb();
    await db.insert(
      _tableName,
      {
        'key': _settingsKey,
        'enabled': settings.enabled ? 1 : 0,
        'lead_time_minutes': settings.leadTimeMinutes,
        'enabled_event_types': _encodeEventTypes(settings.enabledEventTypes),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> reset() async {
    final db = await _getDb();
    await db.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [_settingsKey],
    );
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static String _encodeEventTypes(Set<EventType> types) =>
      types.map((t) => t.toJson()).join(',');

  static Set<EventType> _decodeEventTypes(String encoded) {
    if (encoded.isEmpty) return {};
    return encoded.split(',').map((v) => EventType.fromJson(v)).toSet();
  }
}
