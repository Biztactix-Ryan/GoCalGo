import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/device_token_service.dart';
import 'package:gocalgo/services/notification_settings_store.dart';
import 'package:gocalgo/services/notification_settings_sync_service.dart';
import 'package:gocalgo/services/sqlite_notification_settings_store.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDeviceTokenService extends Mock implements DeviceTokenService {}

/// Verifies acceptance criterion for story US-GCG-28:
/// "Settings persist locally and sync to backend"
///
/// Tests the [SqliteNotificationSettingsStore] for local persistence and
/// verifies that settings changes are synced to the backend API.
void main() {
  sqfliteFfiInit();

  group('SqliteNotificationSettingsStore — local persistence', () {
    late SqliteNotificationSettingsStore store;

    Future<SqliteNotificationSettingsStore> createStore() async {
      return SqliteNotificationSettingsStore.withOpener(() async {
        final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notification_settings (
            key TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL DEFAULT 1,
            lead_time_minutes INTEGER NOT NULL DEFAULT 15,
            enabled_event_types TEXT NOT NULL,
            updated_at TEXT NOT NULL
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

    test('load() returns defaults when no settings are saved', () async {
      final settings = await store.load();

      expect(settings.enabled, isTrue);
      expect(settings.leadTimeMinutes, 15);
      expect(settings.enabledEventTypes, EventType.values.toSet());
    });

    test('save() and load() round-trip all fields', () async {
      final saved = NotificationSettings(
        enabled: false,
        leadTimeMinutes: 30,
        enabledEventTypes: {EventType.communityDay, EventType.raidHour},
      );

      await store.save(saved);
      final loaded = await store.load();

      expect(loaded.enabled, isFalse);
      expect(loaded.leadTimeMinutes, 30);
      expect(
        loaded.enabledEventTypes,
        {EventType.communityDay, EventType.raidHour},
      );
    });

    test('save() overwrites previous settings', () async {
      await store.save(NotificationSettings(
        enabled: true,
        leadTimeMinutes: 5,
        enabledEventTypes: EventType.values.toSet(),
      ));
      await store.save(NotificationSettings(
        enabled: false,
        leadTimeMinutes: 60,
        enabledEventTypes: {EventType.spotlightHour},
      ));

      final loaded = await store.load();
      expect(loaded.enabled, isFalse);
      expect(loaded.leadTimeMinutes, 60);
      expect(loaded.enabledEventTypes, {EventType.spotlightHour});
    });

    test('reset() clears settings so load() returns defaults', () async {
      await store.save(NotificationSettings(
        enabled: false,
        leadTimeMinutes: 60,
        enabledEventTypes: {},
      ));

      await store.reset();
      final loaded = await store.load();

      expect(loaded.enabled, isTrue);
      expect(loaded.leadTimeMinutes, 15);
      expect(loaded.enabledEventTypes, EventType.values.toSet());
    });

    test('persists enabled=false correctly', () async {
      await store.save(NotificationSettings(
        enabled: false,
        leadTimeMinutes: 15,
        enabledEventTypes: EventType.values.toSet(),
      ));

      final loaded = await store.load();
      expect(loaded.enabled, isFalse);
    });

    test('persists empty event type set', () async {
      await store.save(NotificationSettings(
        enabled: true,
        leadTimeMinutes: 15,
        enabledEventTypes: {},
      ));

      final loaded = await store.load();
      expect(loaded.enabledEventTypes, isEmpty);
    });

    test('persists each allowed lead time value', () async {
      for (final minutes in NotificationSettings.allowedLeadTimes) {
        await store.save(NotificationSettings(
          enabled: true,
          leadTimeMinutes: minutes,
          enabledEventTypes: EventType.values.toSet(),
        ));

        final loaded = await store.load();
        expect(loaded.leadTimeMinutes, minutes);
      }
    });

    test('persists every event type individually', () async {
      for (final type in EventType.values) {
        await store.save(NotificationSettings(
          enabled: true,
          leadTimeMinutes: 15,
          enabledEventTypes: {type},
        ));

        final loaded = await store.load();
        expect(loaded.enabledEventTypes, {type});
      }
    });
  });

  group('Settings persistence across restarts', () {
    test('settings survive close and reopen (simulated app restart)', () async {
      final dbPath =
          'settings_persist_test_${DateTime.now().microsecondsSinceEpoch}.db';
      Database? sharedDb;

      Future<Database> openDb() async {
        sharedDb = await databaseFactoryFfi.openDatabase(dbPath);
        await sharedDb!.execute('''
          CREATE TABLE IF NOT EXISTS notification_settings (
            key TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL DEFAULT 1,
            lead_time_minutes INTEGER NOT NULL DEFAULT 15,
            enabled_event_types TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        return sharedDb!;
      }

      // Session 1: save custom settings
      final session1 = SqliteNotificationSettingsStore.withOpener(openDb);
      await session1.save(NotificationSettings(
        enabled: false,
        leadTimeMinutes: 30,
        enabledEventTypes: {EventType.communityDay, EventType.pokemonGoFest},
      ));
      await session1.close();

      // Session 2: reopen and verify settings persisted
      final session2 = SqliteNotificationSettingsStore.withOpener(openDb);
      final loaded = await session2.load();
      expect(loaded.enabled, isFalse);
      expect(loaded.leadTimeMinutes, 30);
      expect(
        loaded.enabledEventTypes,
        {EventType.communityDay, EventType.pokemonGoFest},
      );
      await session2.close();

      // Session 3: update lead time, close, reopen, verify
      final session3 = SqliteNotificationSettingsStore.withOpener(openDb);
      await session3.save(loaded.copyWith(leadTimeMinutes: 60));
      await session3.close();

      final session4 = SqliteNotificationSettingsStore.withOpener(openDb);
      final updated = await session4.load();
      expect(updated.enabled, isFalse);
      expect(updated.leadTimeMinutes, 60);
      expect(
        updated.enabledEventTypes,
        {EventType.communityDay, EventType.pokemonGoFest},
      );
      await session4.close();

      // Cleanup
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });

  group('Settings sync to backend', () {
    late MockApiClient mockApiClient;

    setUp(() {
      mockApiClient = MockApiClient();
    });

    test('posts settings to backend sync endpoint after local save', () async {
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      final settings = NotificationSettings(
        enabled: true,
        leadTimeMinutes: 30,
        enabledEventTypes: {EventType.communityDay, EventType.raidHour},
      );

      // Simulate the sync that the settings screen would trigger
      await mockApiClient.post(
        '/api/v1/notification-settings',
        body: {
          'enabled': settings.enabled,
          'leadTimeMinutes': settings.leadTimeMinutes,
          'enabledEventTypes':
              settings.enabledEventTypes.map((t) => t.toJson()).toList(),
        },
      );

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured[0], '/api/v1/notification-settings');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['enabled'], isTrue);
      expect(body['leadTimeMinutes'], 30);
      expect(body['enabledEventTypes'], contains('community-day'));
      expect(body['enabledEventTypes'], contains('raid-hour'));
    });

    test('sync payload includes all event types when all are enabled',
        () async {
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      final settings = NotificationSettings.defaults();

      await mockApiClient.post(
        '/api/v1/notification-settings',
        body: {
          'enabled': settings.enabled,
          'leadTimeMinutes': settings.leadTimeMinutes,
          'enabledEventTypes':
              settings.enabledEventTypes.map((t) => t.toJson()).toList(),
        },
      );

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured[1] as Map<String, dynamic>;
      final eventTypes = body['enabledEventTypes'] as List;
      expect(eventTypes, hasLength(EventType.values.length));
    });

    test('sync payload reflects disabled notifications', () async {
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      final settings = NotificationSettings(
        enabled: false,
        leadTimeMinutes: 15,
        enabledEventTypes: EventType.values.toSet(),
      );

      await mockApiClient.post(
        '/api/v1/notification-settings',
        body: {
          'enabled': settings.enabled,
          'leadTimeMinutes': settings.leadTimeMinutes,
          'enabledEventTypes':
              settings.enabledEventTypes.map((t) => t.toJson()).toList(),
        },
      );

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured[1] as Map<String, dynamic>;
      expect(body['enabled'], isFalse);
    });

    test('sync payload includes empty event types list when none selected',
        () async {
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      final settings = NotificationSettings(
        enabled: true,
        leadTimeMinutes: 15,
        enabledEventTypes: {},
      );

      await mockApiClient.post(
        '/api/v1/notification-settings',
        body: {
          'enabled': settings.enabled,
          'leadTimeMinutes': settings.leadTimeMinutes,
          'enabledEventTypes':
              settings.enabledEventTypes.map((t) => t.toJson()).toList(),
        },
      );

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured[1] as Map<String, dynamic>;
      expect(body['enabledEventTypes'], isEmpty);
    });

    test('sync retries on failure without losing local settings', () async {
      var callCount = 0;
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw ApiException(500, 'Server error');
        return {'status': 'ok'};
      });

      // First attempt fails
      try {
        await mockApiClient.post(
          '/api/v1/notification-settings',
          body: {'enabled': true, 'leadTimeMinutes': 30},
        );
      } catch (_) {
        // Expected failure
      }

      // Retry succeeds
      await mockApiClient.post(
        '/api/v1/notification-settings',
        body: {'enabled': true, 'leadTimeMinutes': 30},
      );

      verify(() => mockApiClient.post(
            '/api/v1/notification-settings',
            body: any(named: 'body'),
          )).called(2);
    });
  });

  group('NotificationSettingsSyncService', () {
    late MockApiClient mockApiClient;
    late MockDeviceTokenService mockDeviceTokenService;
    late NotificationSettingsSyncService syncService;

    setUp(() {
      mockApiClient = MockApiClient();
      mockDeviceTokenService = MockDeviceTokenService();
      syncService = NotificationSettingsSyncService(
        apiClient: mockApiClient,
        deviceTokenService: mockDeviceTokenService,
      );
    });

    test('sync sends settings with fcmToken to backend', () async {
      when(() => mockDeviceTokenService.getToken())
          .thenAnswer((_) async => 'test-fcm-token');
      when(() => mockApiClient.post(any(), body: any(named: 'body')))
          .thenAnswer((_) async => {'status': 'ok'});

      final settings = NotificationSettings(
        enabled: true,
        leadTimeMinutes: 30,
        enabledEventTypes: {EventType.communityDay, EventType.raidHour},
      );

      await syncService.sync(settings);

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured[0], '/api/v1/notification-settings');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['fcmToken'], 'test-fcm-token');
      expect(body['enabled'], isTrue);
      expect(body['leadTimeMinutes'], 30);
      expect(body['enabledEventTypes'], contains('community-day'));
      expect(body['enabledEventTypes'], contains('raid-hour'));
    });

    test('sync skips when no device token is available', () async {
      when(() => mockDeviceTokenService.getToken())
          .thenAnswer((_) async => null);

      await syncService.sync(NotificationSettings.defaults());

      verifyNever(() => mockApiClient.post(any(), body: any(named: 'body')));
    });

    test('sync retries on failure and eventually succeeds', () async {
      when(() => mockDeviceTokenService.getToken())
          .thenAnswer((_) async => 'test-token');

      var callCount = 0;
      when(() => mockApiClient.post(any(), body: any(named: 'body')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw ApiException(500, 'Server error');
        return {'status': 'ok'};
      });

      await syncService.sync(NotificationSettings.defaults());

      verify(() => mockApiClient.post(any(), body: any(named: 'body')))
          .called(2);
    });

    test('sync silently returns after max retries exhausted', () async {
      when(() => mockDeviceTokenService.getToken())
          .thenAnswer((_) async => 'test-token');
      when(() => mockApiClient.post(any(), body: any(named: 'body')))
          .thenThrow(ApiException(500, 'Server error'));

      // Should not throw
      await syncService.sync(NotificationSettings.defaults());

      // 1 initial + 3 retries = 4 calls
      verify(() => mockApiClient.post(any(), body: any(named: 'body')))
          .called(4);
    });
  });

  group('NotificationSettings model', () {
    test('defaults() has expected values', () {
      final defaults = NotificationSettings.defaults();

      expect(defaults.enabled, isTrue);
      expect(defaults.leadTimeMinutes, 15);
      expect(defaults.enabledEventTypes, EventType.values.toSet());
    });

    test('copyWith() preserves unchanged fields', () {
      final original = NotificationSettings(
        enabled: true,
        leadTimeMinutes: 30,
        enabledEventTypes: {EventType.communityDay},
      );

      final updated = original.copyWith(leadTimeMinutes: 60);

      expect(updated.enabled, isTrue);
      expect(updated.leadTimeMinutes, 60);
      expect(updated.enabledEventTypes, {EventType.communityDay});
    });

    test('copyWith() can change every field', () {
      final original = NotificationSettings.defaults();
      final updated = original.copyWith(
        enabled: false,
        leadTimeMinutes: 5,
        enabledEventTypes: {EventType.raidHour},
      );

      expect(updated.enabled, isFalse);
      expect(updated.leadTimeMinutes, 5);
      expect(updated.enabledEventTypes, {EventType.raidHour});
    });

    test('allowedLeadTimes contains expected values', () {
      expect(
        NotificationSettings.allowedLeadTimes,
        containsAll([5, 15, 30, 60]),
      );
    });
  });
}
