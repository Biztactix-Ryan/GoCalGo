import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/services/device_token_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocktail_mocks.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

/// Helper to build a [NotificationSettings] with the given authorization status.
NotificationSettings _makeSettings(AuthorizationStatus status) {
  return NotificationSettings(
    authorizationStatus: status,
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.notSupported,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.notSupported,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );
}

void main() {
  group('DeviceTokenService', () {
    late MockDeviceTokenService service;

    setUp(() {
      service = MockDeviceTokenService();
    });

    test('getToken() returns a valid FCM device token', () async {
      const fakeToken = 'dGVzdC1mY20tdG9rZW4tMTIzNDU2Nzg5MA==';
      when(() => service.getToken()).thenAnswer((_) async => fakeToken);

      final token = await service.getToken();

      expect(token, isNotNull);
      expect(token, isNotEmpty);
      expect(token, fakeToken);
      verify(() => service.getToken()).called(1);
    });

    test('getToken() returns null when notification permission denied',
        () async {
      when(() => service.getToken()).thenAnswer((_) async => null);

      final token = await service.getToken();

      expect(token, isNull);
      verify(() => service.getToken()).called(1);
    });

    test('getToken() can be called multiple times and returns same token',
        () async {
      const fakeToken = 'dGVzdC1mY20tdG9rZW4tMTIzNDU2Nzg5MA==';
      when(() => service.getToken()).thenAnswer((_) async => fakeToken);

      final token1 = await service.getToken();
      final token2 = await service.getToken();

      expect(token1, equals(token2));
      verify(() => service.getToken()).called(2);
    });

    test('onTokenRefresh emits new tokens when FCM rotates', () async {
      const refreshedToken = 'cmVmcmVzaGVkLXRva2VuLTk4NzY1NDMyMQ==';
      when(() => service.onTokenRefresh)
          .thenAnswer((_) => Stream.value(refreshedToken));

      final emitted = await service.onTokenRefresh.first;

      expect(emitted, refreshedToken);
    });

    test('onTokenRefresh emits multiple tokens over time', () async {
      final tokens = [
        'token-rotation-1',
        'token-rotation-2',
        'token-rotation-3',
      ];
      when(() => service.onTokenRefresh)
          .thenAnswer((_) => Stream.fromIterable(tokens));

      final collected = await service.onTokenRefresh.toList();

      expect(collected, orderedEquals(tokens));
    });

    test('getToken() throws when Firebase is not initialised', () async {
      when(() => service.getToken()).thenThrow(
        StateError('Firebase has not been initialised'),
      );

      expect(
        () => service.getToken(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Firebase has not been initialised'),
        )),
      );
    });
  });

  group('FirebaseDeviceTokenService – iOS permission request', () {
    late MockFirebaseMessaging mockMessaging;
    late FirebaseDeviceTokenService service;

    setUp(() {
      mockMessaging = MockFirebaseMessaging();
      service = FirebaseDeviceTokenService(messaging: mockMessaging);
    });

    test('requestPermission() calls Firebase with alert, badge, sound enabled',
        () async {
      final settings = _makeSettings(AuthorizationStatus.authorized);
      when(() => mockMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).thenAnswer((_) async => settings);

      final result = await service.requestPermission();

      expect(
        result.authorizationStatus,
        AuthorizationStatus.authorized,
      );
      verify(() => mockMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).called(1);
    });

    test('requestPermission() returns denied when user declines', () async {
      final settings = _makeSettings(AuthorizationStatus.denied);
      when(() => mockMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).thenAnswer((_) async => settings);

      final result = await service.requestPermission();

      expect(
        result.authorizationStatus,
        AuthorizationStatus.denied,
      );
    });

    test('requestPermission() returns provisional for provisional auth',
        () async {
      final settings = _makeSettings(AuthorizationStatus.provisional);
      when(() => mockMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).thenAnswer((_) async => settings);

      final result = await service.requestPermission();

      expect(
        result.authorizationStatus,
        AuthorizationStatus.provisional,
      );
    });

    test('requestPermission() returns notDetermined before first prompt',
        () async {
      final settings = _makeSettings(AuthorizationStatus.notDetermined);
      when(() => mockMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).thenAnswer((_) async => settings);

      final result = await service.requestPermission();

      expect(
        result.authorizationStatus,
        AuthorizationStatus.notDetermined,
      );
    });

    test('getToken() delegates to FirebaseMessaging.getToken()', () async {
      const token = 'ios-fcm-token-abc123';
      when(() => mockMessaging.getToken()).thenAnswer((_) async => token);

      final result = await service.getToken();

      expect(result, token);
      verify(() => mockMessaging.getToken()).called(1);
    });

    test('onTokenRefresh delegates to FirebaseMessaging.onTokenRefresh',
        () async {
      const refreshed = 'refreshed-token-xyz';
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => Stream.value(refreshed));

      final result = await service.onTokenRefresh.first;

      expect(result, refreshed);
    });
  });
}
