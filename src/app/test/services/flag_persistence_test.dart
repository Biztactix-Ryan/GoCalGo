import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gocalgo/services/sqlite_flag_store.dart';

/// Verifies acceptance criterion for story US-GCG-8:
/// "Flags persist across app restarts using local storage"
///
/// Tests the [SqliteFlagStore] — a SQLite-backed store that persists event
/// flag state across app restarts. Uses in-memory SQLite via sqflite_common_ffi
/// so tests run without the Flutter engine.
void main() {
  sqfliteFfiInit();

  late SqliteFlagStore store;

  /// Creates a fresh [SqliteFlagStore] backed by a new in-memory database.
  Future<SqliteFlagStore> createStore() async {
    return SqliteFlagStore.withOpener(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS flagged_events (
          event_id TEXT PRIMARY KEY,
          flagged_at TEXT NOT NULL
        )
      ''');
      return db;
    });
  }

  setUp(() async {
    store = await createStore();
  });

  tearDown(() async {
    await store.close();
  });

  group('SqliteFlagStore', () {
    test('isFlagged() returns false for an unflagged event', () async {
      expect(await store.isFlagged('ev-1'), isFalse);
    });

    test('flag() marks an event as flagged', () async {
      await store.flag('ev-1');
      expect(await store.isFlagged('ev-1'), isTrue);
    });

    test('unflag() removes the flag from an event', () async {
      await store.flag('ev-1');
      await store.unflag('ev-1');
      expect(await store.isFlagged('ev-1'), isFalse);
    });

    test('unflag() is a no-op for an already unflagged event', () async {
      // Should not throw
      await store.unflag('ev-1');
      expect(await store.isFlagged('ev-1'), isFalse);
    });

    test('flaggedIds() returns empty set when nothing is flagged', () async {
      final ids = await store.flaggedIds();
      expect(ids, isEmpty);
    });

    test('flaggedIds() returns all flagged event IDs', () async {
      await store.flag('ev-1');
      await store.flag('ev-2');
      await store.flag('ev-3');

      final ids = await store.flaggedIds();
      expect(ids, containsAll(['ev-1', 'ev-2', 'ev-3']));
      expect(ids, hasLength(3));
    });

    test('flagging the same event twice is idempotent', () async {
      await store.flag('ev-1');
      await store.flag('ev-1');

      expect(await store.isFlagged('ev-1'), isTrue);
      final ids = await store.flaggedIds();
      expect(ids, hasLength(1));
    });

    test('flags are independent across events', () async {
      await store.flag('ev-1');
      await store.flag('ev-2');
      await store.unflag('ev-1');

      expect(await store.isFlagged('ev-1'), isFalse);
      expect(await store.isFlagged('ev-2'), isTrue);
    });

    test('clearAll() removes every flag', () async {
      await store.flag('ev-1');
      await store.flag('ev-2');
      await store.clearAll();

      expect(await store.flaggedIds(), isEmpty);
      expect(await store.isFlagged('ev-1'), isFalse);
      expect(await store.isFlagged('ev-2'), isFalse);
    });
  });

  group('Flag persistence across restarts', () {
    test('flags survive close and reopen (simulated app restart)', () async {
      // Use a shared file-backed database to simulate persistence.
      final dbPath = 'flag_persist_test_${DateTime.now().microsecondsSinceEpoch}.db';
      Database? sharedDb;

      Future<Database> openDb() async {
        sharedDb = await databaseFactoryFfi.openDatabase(dbPath);
        await sharedDb!.execute('''
          CREATE TABLE IF NOT EXISTS flagged_events (
            event_id TEXT PRIMARY KEY,
            flagged_at TEXT NOT NULL
          )
        ''');
        return sharedDb!;
      }

      // Session 1: flag some events
      final session1 = SqliteFlagStore.withOpener(openDb);
      await session1.flag('ev-1');
      await session1.flag('ev-2');
      expect(await session1.isFlagged('ev-1'), isTrue);
      await session1.close();

      // Session 2: reopen and verify flags are still there
      final session2 = SqliteFlagStore.withOpener(openDb);
      expect(await session2.isFlagged('ev-1'), isTrue);
      expect(await session2.isFlagged('ev-2'), isTrue);
      expect(await session2.isFlagged('ev-3'), isFalse);

      final ids = await session2.flaggedIds();
      expect(ids, containsAll(['ev-1', 'ev-2']));
      expect(ids, hasLength(2));
      await session2.close();

      // Session 3: unflag one event, close, reopen, verify
      final session3 = SqliteFlagStore.withOpener(openDb);
      await session3.unflag('ev-1');
      await session3.close();

      final session4 = SqliteFlagStore.withOpener(openDb);
      expect(await session4.isFlagged('ev-1'), isFalse);
      expect(await session4.isFlagged('ev-2'), isTrue);
      await session4.close();

      // Cleanup
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });
}
