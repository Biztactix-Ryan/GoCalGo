import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/backend_config.dart';

/// Integration tests verifying that the Flutter API client can communicate
/// with the local backend running via Docker Compose.
///
/// Prerequisites:
///   docker compose up -d
///
/// Run:
///   cd src/app
///   flutter test integration_test/api_client_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  late EventsService eventsService;

  setUp(() {
    apiClient = ApiClient(baseUrl: BackendConfig.apiV1Url);
    eventsService = EventsService(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  group('Health check', () {
    testWidgets('backend is reachable and healthy', (tester) async {
      // The health endpoint is at the root, not under /api/v1.
      final healthClient = ApiClient(baseUrl: BackendConfig.apiBaseUrl);
      try {
        final health = await healthClient.get('/health');
        expect(health, isA<Map<String, dynamic>>());
        final status = (health as Map<String, dynamic>)['status'] as String?;
        expect(status, isNotNull);
      } finally {
        healthClient.dispose();
      }
    });
  });

  group('Events API', () {
    testWidgets('GET /events returns a valid EventsResponse', (tester) async {
      final json = await apiClient.get('/events') as Map<String, dynamic>;
      final response = EventsResponse.fromJson(json);

      expect(response.events, isA<List>());
      expect(response.lastUpdated, isA<DateTime>());
      expect(response.cacheHit, isA<bool>());
    });

    testWidgets('EventsService.getEvents() deserializes correctly',
        (tester) async {
      final response = await eventsService.getEvents();

      expect(response.events, isA<List>());
      expect(response.lastUpdated, isA<DateTime>());

      // If events exist, verify the DTOs have required fields populated.
      for (final event in response.events) {
        expect(event.id, isNotEmpty);
        expect(event.name, isNotEmpty);
        expect(event.eventType, isNotNull);
      }
    });

    testWidgets('EventsService.getActiveEvents() filters to active events',
        (tester) async {
      final active = await eventsService.getActiveEvents();

      // Active events should have a start time in the past.
      final now = DateTime.now();
      for (final event in active) {
        expect(event.start, isNotNull);
        expect(event.start!.isBefore(now) || event.start!.isAtSameMomentAs(now),
            isTrue,
            reason: '${event.name} should have started before now');
      }
    });

    testWidgets('EventsService.getUpcomingEvents() filters to future events',
        (tester) async {
      final upcoming = await eventsService.getUpcomingEvents(days: 7);

      // Upcoming events should have a start time in the future.
      final now = DateTime.now();
      for (final event in upcoming) {
        if (event.start != null) {
          expect(event.start!.isAfter(now), isTrue,
              reason: '${event.name} should start after now');
        }
      }
    });
  });

  group('Events /active endpoint', () {
    testWidgets('GET /events/active returns valid response', (tester) async {
      final json =
          await apiClient.get('/events/active') as Map<String, dynamic>;

      expect(json['events'], isA<List>());
      expect(json['lastUpdated'], isA<String>());
      expect(json['cacheHit'], isA<bool>());
    });
  });

  group('Events /upcoming endpoint', () {
    testWidgets('GET /events/upcoming returns valid response', (tester) async {
      final json =
          await apiClient.get('/events/upcoming') as Map<String, dynamic>;

      expect(json['events'], isA<List>());
      expect(json['lastUpdated'], isA<String>());
      expect(json['cacheHit'], isA<bool>());
    });

    testWidgets('GET /events/upcoming?days=3 respects window parameter',
        (tester) async {
      final json =
          await apiClient.get('/events/upcoming?days=3') as Map<String, dynamic>;

      expect(json['events'], isA<List>());
    });
  });
}
