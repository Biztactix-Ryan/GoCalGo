import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/notification_navigation_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class MockGoRouter extends Mock implements GoRouter {}

class MockCachedEventsService extends Mock implements CachedEventsService {}

class FakeRemoteMessage extends Fake implements RemoteMessage {
  FakeRemoteMessage(this._data);
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> get data => _data;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EventDto _makeEvent(String id, {String name = 'Test Event'}) => EventDto(
      id: id,
      name: name,
      eventType: EventType.event,
      heading: name,
      imageUrl: 'https://example.com/$id.png',
      linkUrl: 'https://example.com/$id',
      isUtcTime: false,
      hasSpawns: false,
      hasResearchTasks: false,
      buffs: const [],
      featuredPokemon: const [],
      promoCodes: const [],
    );

EventsResponse _responseWith(List<EventDto> events) => EventsResponse(
      events: events,
      lastUpdated: DateTime(2026, 3, 22),
      cacheHit: false,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFirebaseMessaging mockMessaging;
  late MockGoRouter mockRouter;
  late MockCachedEventsService mockEventsService;
  late StreamController<RemoteMessage> onMessageOpenedController;
  late StreamController<RemoteMessage> onMessageController;

  setUp(() {
    mockMessaging = MockFirebaseMessaging();
    mockRouter = MockGoRouter();
    mockEventsService = MockCachedEventsService();
    onMessageOpenedController = StreamController<RemoteMessage>();
    onMessageController = StreamController<RemoteMessage>();

    // Default: no initial message, empty onMessageOpenedApp stream.
    when(() => mockMessaging.getInitialMessage())
        .thenAnswer((_) async => null);
  });

  tearDown(() async {
    await onMessageOpenedController.close();
    await onMessageController.close();
  });

  NotificationNavigationService createService() =>
      NotificationNavigationService(
        messaging: mockMessaging,
        eventsService: mockEventsService,
        router: mockRouter,
        onMessageOpenedApp: onMessageOpenedController.stream,
        onMessage: onMessageController.stream,
      );

  group('NotificationNavigationService', () {
    // ------------------------------------------------------------------
    // Cold-start: getInitialMessage
    // ------------------------------------------------------------------

    group('cold-start (getInitialMessage)', () {
      test('navigates to event detail when launched from notification tap',
          () async {
        final event = _makeEvent('evt-001', name: 'Community Day');
        final message = FakeRemoteMessage({'eventId': 'evt-001'});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        verify(() => mockRouter.push('/event/evt-001', extra: event)).called(1);

        service.dispose();
      });

      test('does not navigate when initial message has no eventId', () async {
        final message = FakeRemoteMessage({});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);

        final service = createService();
        await service.init();

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('does not navigate when no initial message exists', () async {
        // Default stub already returns null.
        final service = createService();
        await service.init();

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('does not navigate when event is not found in cache', () async {
        final message = FakeRemoteMessage({'eventId': 'evt-missing'});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([_makeEvent('evt-other')]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('does not navigate when events service throws', () async {
        final message = FakeRemoteMessage({'eventId': 'evt-001'});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);
        when(() => mockEventsService.getEvents()).thenThrow(Exception('offline'));

        final service = createService();
        await service.init();

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });
    });

    // ------------------------------------------------------------------
    // Background: onMessageOpenedApp
    // ------------------------------------------------------------------

    group('background tap (onMessageOpenedApp)', () {
      test('navigates to event detail on notification tap', () async {
        final event = _makeEvent('evt-042', name: 'Raid Hour');
        final message = FakeRemoteMessage({'eventId': 'evt-042'});

        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        // Simulate user tapping notification while app is in background.
        onMessageOpenedController.add(message);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockRouter.push('/event/evt-042', extra: event)).called(1);

        service.dispose();
      });

      test('handles multiple notification taps sequentially', () async {
        final event1 = _makeEvent('evt-1');
        final event2 = _makeEvent('evt-2');

        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event1, event2]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        onMessageOpenedController.add(FakeRemoteMessage({'eventId': 'evt-1'}));
        await Future<void>.delayed(Duration.zero);
        onMessageOpenedController.add(FakeRemoteMessage({'eventId': 'evt-2'}));
        await Future<void>.delayed(Duration.zero);

        verify(() => mockRouter.push('/event/evt-1', extra: event1)).called(1);
        verify(() => mockRouter.push('/event/evt-2', extra: event2)).called(1);

        service.dispose();
      });

      test('does not navigate when tapped notification has no eventId',
          () async {
        final service = createService();
        await service.init();

        onMessageOpenedController.add(FakeRemoteMessage({}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('does not navigate when event not found', () async {
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([]));

        final service = createService();
        await service.init();

        onMessageOpenedController
            .add(FakeRemoteMessage({'eventId': 'evt-gone'}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('stops handling taps after dispose', () async {
        final event = _makeEvent('evt-after-dispose');

        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        service.dispose();

        onMessageOpenedController
            .add(FakeRemoteMessage({'eventId': 'evt-after-dispose'}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));
      });
    });

    // ------------------------------------------------------------------
    // Foreground: onMessage
    // ------------------------------------------------------------------

    group('foreground (onMessage)', () {
      test('navigates to event detail when notification arrives in foreground',
          () async {
        final event = _makeEvent('evt-fg-001', name: 'Go Fest');
        final message = FakeRemoteMessage({'eventId': 'evt-fg-001'});

        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        // Simulate foreground message arrival.
        onMessageController.add(message);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockRouter.push('/event/evt-fg-001', extra: event))
            .called(1);

        service.dispose();
      });

      test('does not navigate when foreground message has no eventId',
          () async {
        final service = createService();
        await service.init();

        onMessageController.add(FakeRemoteMessage({}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('does not navigate when event not found for foreground message',
          () async {
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([]));

        final service = createService();
        await service.init();

        onMessageController
            .add(FakeRemoteMessage({'eventId': 'evt-no-match'}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('handles events service exception gracefully in foreground',
          () async {
        when(() => mockEventsService.getEvents())
            .thenThrow(Exception('network error'));

        final service = createService();
        await service.init();

        onMessageController
            .add(FakeRemoteMessage({'eventId': 'evt-fg-err'}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));

        service.dispose();
      });

      test('stops handling foreground messages after dispose', () async {
        final event = _makeEvent('evt-fg-disposed');

        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        service.dispose();

        onMessageController
            .add(FakeRemoteMessage({'eventId': 'evt-fg-disposed'}));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRouter.push(any(), extra: any(named: 'extra')));
      });
    });

    // ------------------------------------------------------------------
    // All three states together
    // ------------------------------------------------------------------

    group('all app states', () {
      test(
          'handles notifications from terminated, background, and foreground states',
          () async {
        final terminatedEvent =
            _makeEvent('evt-terminated', name: 'Terminated');
        final backgroundEvent =
            _makeEvent('evt-background', name: 'Background');
        final foregroundEvent =
            _makeEvent('evt-foreground', name: 'Foreground');

        when(() => mockMessaging.getInitialMessage()).thenAnswer(
            (_) async => FakeRemoteMessage({'eventId': 'evt-terminated'}));
        when(() => mockEventsService.getEvents()).thenAnswer((_) async =>
            _responseWith(
                [terminatedEvent, backgroundEvent, foregroundEvent]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        // Terminated state: handled via getInitialMessage during init.
        verify(() => mockRouter.push('/event/evt-terminated',
            extra: terminatedEvent)).called(1);

        // Background state: user taps notification while app is backgrounded.
        onMessageOpenedController
            .add(FakeRemoteMessage({'eventId': 'evt-background'}));
        await Future<void>.delayed(Duration.zero);

        verify(() => mockRouter.push('/event/evt-background',
            extra: backgroundEvent)).called(1);

        // Foreground state: notification arrives while app is active.
        onMessageController
            .add(FakeRemoteMessage({'eventId': 'evt-foreground'}));
        await Future<void>.delayed(Duration.zero);

        verify(() => mockRouter.push('/event/evt-foreground',
            extra: foregroundEvent)).called(1);

        service.dispose();
      });
    });

    // ------------------------------------------------------------------
    // Route correctness
    // ------------------------------------------------------------------

    group('route construction', () {
      test('pushes /event/:id with the correct EventDto as extra', () async {
        final event = _makeEvent('spotlight-hour-123',
            name: 'Spotlight Hour: Pikachu');
        final message = FakeRemoteMessage({'eventId': 'spotlight-hour-123'});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith([event]));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        final captured = verify(() => mockRouter.push(
              captureAny(),
              extra: captureAny(named: 'extra'),
            )).captured;

        expect(captured[0], '/event/spotlight-hour-123');
        expect(captured[1], isA<EventDto>());
        expect((captured[1] as EventDto).id, 'spotlight-hour-123');
        expect((captured[1] as EventDto).name, 'Spotlight Hour: Pikachu');

        service.dispose();
      });

      test('selects the correct event when multiple events exist', () async {
        final events = [
          _makeEvent('evt-a', name: 'Event A'),
          _makeEvent('evt-b', name: 'Event B'),
          _makeEvent('evt-c', name: 'Event C'),
        ];
        final message = FakeRemoteMessage({'eventId': 'evt-b'});

        when(() => mockMessaging.getInitialMessage())
            .thenAnswer((_) async => message);
        when(() => mockEventsService.getEvents())
            .thenAnswer((_) async => _responseWith(events));
        when(() => mockRouter.push(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async => null);

        final service = createService();
        await service.init();

        final captured = verify(() => mockRouter.push(
              captureAny(),
              extra: captureAny(named: 'extra'),
            )).captured;

        expect((captured[1] as EventDto).id, 'evt-b');
        expect((captured[1] as EventDto).name, 'Event B');

        service.dispose();
      });
    });
  });
}
