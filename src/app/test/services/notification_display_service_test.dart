import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gocalgo/services/notification_display_service.dart';

class FakeNotificationResponse extends Fake implements NotificationResponse {
  FakeNotificationResponse({this.fakePayload});

  final String? fakePayload;

  @override
  String? get payload => fakePayload;
}

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeAndroidNotificationChannel extends Fake
    implements AndroidNotificationChannel {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

class FakeRemoteMessage extends Fake implements RemoteMessage {
  FakeRemoteMessage({
    this.fakeNotification,
    this.fakeData = const {},
  });

  final RemoteNotification? fakeNotification;
  final Map<String, dynamic> fakeData;

  @override
  RemoteNotification? get notification => fakeNotification;

  @override
  Map<String, dynamic> get data => fakeData;
}

class FakeRemoteNotification extends Fake implements RemoteNotification {
  FakeRemoteNotification({this.fakeTitle, this.fakeBody});

  final String? fakeTitle;
  final String? fakeBody;

  @override
  String? get title => fakeTitle;

  @override
  String? get body => fakeBody;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeAndroidNotificationChannel());
    registerFallbackValue(FakeNotificationDetails());
  });

  group('NotificationDisplayService', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late MockAndroidPlugin mockAndroidPlugin;
    late MockFirebaseMessaging mockMessaging;
    late StreamController<RemoteMessage> onMessageController;
    DidReceiveNotificationResponseCallback? capturedTapCallback;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      mockAndroidPlugin = MockAndroidPlugin();
      mockMessaging = MockFirebaseMessaging();
      onMessageController = StreamController<RemoteMessage>.broadcast();
      capturedTapCallback = null;

      when(() => mockPlugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((invocation) async {
        capturedTapCallback = invocation.namedArguments[
            #onDidReceiveNotificationResponse] as DidReceiveNotificationResponseCallback?;
        return true;
      });
      when(() => mockPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.createNotificationChannel(any()))
          .thenAnswer((_) async {});
      when(() => mockMessaging.setForegroundNotificationPresentationOptions(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
          )).thenAnswer((_) async {});
    });

    tearDown(() {
      onMessageController.close();
    });

    NotificationDisplayService createService() {
      return NotificationDisplayService(
        localNotifications: mockPlugin,
        messaging: mockMessaging,
        onMessage: onMessageController.stream,
      );
    }

    test('init() initialises the local notifications plugin', () async {
      final service = createService();
      await service.init();

      verify(() => mockPlugin.initialize(any())).called(1);
      service.dispose();
    });

    test('init() creates the Android notification channel', () async {
      final service = createService();
      await service.init();

      verify(() => mockAndroidPlugin.createNotificationChannel(
            any(
              that: isA<AndroidNotificationChannel>()
                  .having((c) => c.id, 'id', 'gocalgo_events')
                  .having((c) => c.importance, 'importance', Importance.high),
            ),
          )).called(1);
      service.dispose();
    });

    test('init() enables iOS foreground presentation options', () async {
      final service = createService();
      await service.init();

      verify(() => mockMessaging.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          )).called(1);
      service.dispose();
    });

    test('shows local notification for foreground FCM messages', () async {
      when(() => mockPlugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      final service = createService();
      await service.init();

      final notification = FakeRemoteNotification(
        fakeTitle: 'Community Day',
        fakeBody: 'Starts in 30 minutes!',
      );
      final message = FakeRemoteMessage(
        fakeNotification: notification,
        fakeData: {'eventId': 'evt-123'},
      );

      onMessageController.add(message);

      // Allow the stream listener to process.
      await Future<void>.delayed(Duration.zero);

      verify(() => mockPlugin.show(
            any(),
            'Community Day',
            'Starts in 30 minutes!',
            any(
              that: isA<NotificationDetails>(),
            ),
            payload: 'evt-123',
          )).called(1);

      service.dispose();
    });

    test('ignores foreground messages without a notification payload',
        () async {
      final service = createService();
      await service.init();

      final message = FakeRemoteMessage(fakeData: {'eventId': 'evt-456'});
      onMessageController.add(message);

      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockPlugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          ));

      service.dispose();
    });

    test('dispose() cancels the foreground subscription', () async {
      final service = createService();
      await service.init();
      service.dispose();

      // After dispose, adding messages should not trigger show().
      when(() => mockPlugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      final notification = FakeRemoteNotification(
        fakeTitle: 'After dispose',
        fakeBody: 'Should not show',
      );
      onMessageController.add(
        FakeRemoteMessage(fakeNotification: notification),
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockPlugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          ));
    });

    test('eventNotificationChannel has correct properties', () {
      expect(eventNotificationChannel.id, 'gocalgo_events');
      expect(eventNotificationChannel.name, 'Event Notifications');
      expect(eventNotificationChannel.importance, Importance.high);
      expect(eventNotificationChannel.description, isNotEmpty);
    });

    test('init() works when Android plugin is null (e.g. on iOS)', () async {
      when(() => mockPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final service = createService();
      await service.init();

      verifyNever(
          () => mockAndroidPlugin.createNotificationChannel(any()));
      service.dispose();
    });

    // ----------------------------------------------------------------
    // Local notification tap handling
    // ----------------------------------------------------------------

    group('notification tap callback', () {
      test('init() registers onDidReceiveNotificationResponse', () async {
        final service = createService();
        await service.init();

        expect(capturedTapCallback, isNotNull);
        service.dispose();
      });

      test('invokes onNotificationTap when user taps a local notification',
          () async {
        String? receivedPayload;
        final service = createService();
        service.onNotificationTap = (payload) {
          receivedPayload = payload;
        };
        await service.init();

        capturedTapCallback!(FakeNotificationResponse(fakePayload: 'evt-789'));

        expect(receivedPayload, 'evt-789');
        service.dispose();
      });

      test('does not invoke callback when payload is null', () async {
        var callCount = 0;
        final service = createService();
        service.onNotificationTap = (_) => callCount++;
        await service.init();

        capturedTapCallback!(FakeNotificationResponse(fakePayload: null));

        expect(callCount, 0);
        service.dispose();
      });

      test('does not invoke callback when payload is empty', () async {
        var callCount = 0;
        final service = createService();
        service.onNotificationTap = (_) => callCount++;
        await service.init();

        capturedTapCallback!(FakeNotificationResponse(fakePayload: ''));

        expect(callCount, 0);
        service.dispose();
      });

      test('does not crash when onNotificationTap is not set', () async {
        final service = createService();
        await service.init();

        // Should not throw when no callback is registered.
        capturedTapCallback!(FakeNotificationResponse(fakePayload: 'evt-abc'));

        service.dispose();
      });
    });
  });
}
