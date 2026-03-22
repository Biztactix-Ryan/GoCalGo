import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/sqlite_event_cache.dart';

/// Tests for [SqliteEventCache] — the SQLite-backed implementation of
/// [EventCache] for persisting event data across app restarts.
void main() {
  // Use sqflite_common_ffi so tests run without the Flutter engine.
  sqfliteFfiInit();

  late SqliteEventCache cache;

  setUp(() {
    cache = SqliteEventCache.withOpener(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE event_cache (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          payload TEXT NOT NULL,
          stored_at TEXT NOT NULL
        )
      ''');
      return db;
    });
  });

  tearDown(() async {
    await cache.close();
  });

  EventsResponse _response({
    List<EventDto>? events,
    DateTime? lastUpdated,
    bool cacheHit = false,
  }) {
    return EventsResponse(
      events: events ?? [_sampleEvent()],
      lastUpdated: lastUpdated ?? DateTime.utc(2026, 3, 21, 12, 0),
      cacheHit: cacheHit,
    );
  }

  group('SqliteEventCache', () {
    test('get() returns null when cache is empty', () async {
      expect(await cache.get(), isNull);
    });

    test('put() then get() round-trips an EventsResponse', () async {
      final original = _response();
      await cache.put(original);

      final retrieved = await cache.get();
      expect(retrieved, isNotNull);
      expect(retrieved!.events, hasLength(1));
      expect(retrieved.events.first.id, 'ev-1');
      expect(retrieved.events.first.name, 'Community Day');
      expect(retrieved.lastUpdated, DateTime.utc(2026, 3, 21, 12, 0));
    });

    test('put() replaces previous cached data', () async {
      await cache.put(_response(
        events: [_sampleEvent(id: 'ev-1', name: 'First')],
      ));
      await cache.put(_response(
        events: [
          _sampleEvent(id: 'ev-1', name: 'First'),
          _sampleEvent(id: 'ev-2', name: 'Second'),
        ],
      ));

      final retrieved = await cache.get();
      expect(retrieved!.events, hasLength(2));
    });

    test('clear() removes cached data', () async {
      await cache.put(_response());
      expect(await cache.get(), isNotNull);

      await cache.clear();
      expect(await cache.get(), isNull);
    });

    test('storedAt returns null when cache is empty', () async {
      expect(await cache.storedAt, isNull);
    });

    test('storedAt is populated after put()', () async {
      final before = DateTime.now().toUtc();
      await cache.put(_response());
      final after = DateTime.now().toUtc();

      final stored = await cache.storedAt;
      expect(stored, isNotNull);
      // storedAt should be between before and after.
      expect(stored!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(stored.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('storedAt is null after clear()', () async {
      await cache.put(_response());
      await cache.clear();
      expect(await cache.storedAt, isNull);
    });

    test('preserves full event payload including nested objects', () async {
      final event = EventDto(
        id: 'cd-march',
        name: 'March Community Day',
        eventType: EventType.communityDay,
        heading: 'Featuring Bellsprout',
        imageUrl: 'https://example.com/cd.png',
        linkUrl: 'https://example.com/cd',
        start: DateTime(2026, 3, 21, 14, 0),
        end: DateTime(2026, 3, 21, 17, 0),
        isUtcTime: false,
        hasSpawns: true,
        hasResearchTasks: true,
        buffs: [],
        featuredPokemon: [],
        promoCodes: ['POKEMON2026'],
      );

      await cache.put(_response(events: [event]));
      final retrieved = await cache.get();
      final e = retrieved!.events.first;

      expect(e.id, 'cd-march');
      expect(e.name, 'March Community Day');
      expect(e.eventType, EventType.communityDay);
      expect(e.hasSpawns, true);
      expect(e.hasResearchTasks, true);
      expect(e.promoCodes, ['POKEMON2026']);
    });

    test('preserves cacheHit flag', () async {
      await cache.put(_response(cacheHit: true));
      final retrieved = await cache.get();
      expect(retrieved!.cacheHit, true);
    });

    test('multiple get() calls return consistent data', () async {
      await cache.put(_response());

      final r1 = await cache.get();
      final r2 = await cache.get();
      final r3 = await cache.get();

      expect(r1!.events.first.id, r2!.events.first.id);
      expect(r2.events.first.id, r3!.events.first.id);
    });
  });
}

EventDto _sampleEvent({String id = 'ev-1', String name = 'Community Day'}) {
  return EventDto(
    id: id,
    name: name,
    eventType: EventType.event,
    heading: name,
    imageUrl: 'https://example.com/$id.png',
    linkUrl: 'https://example.com/$id',
    start: DateTime(2026, 3, 21, 10, 0),
    end: DateTime(2026, 3, 21, 20, 0),
    isUtcTime: false,
    hasSpawns: false,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );
}
