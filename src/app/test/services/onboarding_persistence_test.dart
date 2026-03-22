import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gocalgo/services/sqlite_onboarding_store.dart';

/// Verifies acceptance criterion for story US-GCG-25:
/// "Onboarding only shows once (tracked in local storage)"
///
/// Tests the [SqliteOnboardingStore] — a SQLite-backed store that persists
/// onboarding completion state. Uses in-memory SQLite via sqflite_common_ffi
/// so tests run without the Flutter engine.
void main() {
  sqfliteFfiInit();

  late SqliteOnboardingStore store;

  /// Creates a fresh [SqliteOnboardingStore] backed by a new in-memory database.
  Future<SqliteOnboardingStore> createStore() async {
    return SqliteOnboardingStore.withOpener(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS onboarding_state (
          key TEXT PRIMARY KEY,
          completed_at TEXT NOT NULL
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

  group('SqliteOnboardingStore', () {
    test('hasCompletedOnboarding() returns false initially', () async {
      expect(await store.hasCompletedOnboarding(), isFalse);
    });

    test('markOnboardingComplete() sets completion state', () async {
      await store.markOnboardingComplete();
      expect(await store.hasCompletedOnboarding(), isTrue);
    });

    test('markOnboardingComplete() is idempotent', () async {
      await store.markOnboardingComplete();
      await store.markOnboardingComplete();
      expect(await store.hasCompletedOnboarding(), isTrue);
    });

    test('resetOnboarding() clears the completion state', () async {
      await store.markOnboardingComplete();
      await store.resetOnboarding();
      expect(await store.hasCompletedOnboarding(), isFalse);
    });

    test('resetOnboarding() is a no-op when not completed', () async {
      await store.resetOnboarding();
      expect(await store.hasCompletedOnboarding(), isFalse);
    });
  });

  group('Onboarding shows only once (persistence across restarts)', () {
    test('completion state survives close and reopen', () async {
      final dbPath =
          'onboarding_persist_test_${DateTime.now().microsecondsSinceEpoch}.db';
      Database? sharedDb;

      Future<Database> openDb() async {
        sharedDb = await databaseFactoryFfi.openDatabase(dbPath);
        await sharedDb!.execute('''
          CREATE TABLE IF NOT EXISTS onboarding_state (
            key TEXT PRIMARY KEY,
            completed_at TEXT NOT NULL
          )
        ''');
        return sharedDb!;
      }

      // Session 1: first launch — onboarding not yet completed
      final session1 = SqliteOnboardingStore.withOpener(openDb);
      expect(await session1.hasCompletedOnboarding(), isFalse);

      // User completes onboarding
      await session1.markOnboardingComplete();
      expect(await session1.hasCompletedOnboarding(), isTrue);
      await session1.close();

      // Session 2: second launch — onboarding should NOT show again
      final session2 = SqliteOnboardingStore.withOpener(openDb);
      expect(await session2.hasCompletedOnboarding(), isTrue,
          reason: 'Onboarding should only show once — completion must persist');
      await session2.close();

      // Session 3: third launch — still completed
      final session3 = SqliteOnboardingStore.withOpener(openDb);
      expect(await session3.hasCompletedOnboarding(), isTrue,
          reason: 'Onboarding completion must persist across multiple restarts');
      await session3.close();

      // Cleanup
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });

    test('reset allows onboarding to show again after a restart', () async {
      final dbPath =
          'onboarding_reset_test_${DateTime.now().microsecondsSinceEpoch}.db';
      Database? sharedDb;

      Future<Database> openDb() async {
        sharedDb = await databaseFactoryFfi.openDatabase(dbPath);
        await sharedDb!.execute('''
          CREATE TABLE IF NOT EXISTS onboarding_state (
            key TEXT PRIMARY KEY,
            completed_at TEXT NOT NULL
          )
        ''');
        return sharedDb!;
      }

      // Session 1: complete onboarding
      final session1 = SqliteOnboardingStore.withOpener(openDb);
      await session1.markOnboardingComplete();
      await session1.close();

      // Session 2: reset onboarding, then close
      final session2 = SqliteOnboardingStore.withOpener(openDb);
      expect(await session2.hasCompletedOnboarding(), isTrue);
      await session2.resetOnboarding();
      await session2.close();

      // Session 3: onboarding should show again
      final session3 = SqliteOnboardingStore.withOpener(openDb);
      expect(await session3.hasCompletedOnboarding(), isFalse,
          reason: 'After reset, onboarding should show again on next launch');
      await session3.close();

      // Cleanup
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });
}
