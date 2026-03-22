import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/device_token_service.dart';
import 'package:gocalgo/services/token_registration_service.dart';

class MockDeviceTokenService extends Mock implements DeviceTokenService {}

class MockApiClient extends Mock implements ApiClient {}

/// Matches a body map containing the expected token plus platform and timezone.
Matcher _bodyWithToken(String token) => predicate<Map<String, dynamic>>(
      (body) =>
          body['token'] == token &&
          body.containsKey('platform') &&
          body.containsKey('timezone'),
      'body with token "$token", platform, and timezone',
    );

void main() {
  group('TokenRegistrationService', () {
    late MockDeviceTokenService mockTokenService;
    late MockApiClient mockApiClient;
    late TokenRegistrationService registrationService;

    setUp(() {
      mockTokenService = MockDeviceTokenService();
      mockApiClient = MockApiClient();

      registrationService = TokenRegistrationService(
        deviceTokenService: mockTokenService,
        apiClient: mockApiClient,
      );
    });

    tearDown(() {
      registrationService.dispose();
    });

    test('sends token with platform and timezone to backend on first launch',
        () async {
      const token = 'dGVzdC1mY20tdG9rZW4tMTIzNDU2Nzg5MA==';

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => token);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured[0], '/api/v1/device-tokens');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['token'], token);
      expect(body['platform'], anyOf('android', 'ios'));
      expect(body['timezone'], isNotEmpty);
    });

    test('does not call backend when token is null', () async {
      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => null);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      await registrationService.registerOnLaunch();

      verifyNever(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          ));
    });

    test('sends refreshed token to backend when FCM rotates', () async {
      const initialToken = 'initial-token';
      const refreshedToken = 'refreshed-token-after-rotation';

      final refreshController = StreamController<String>();

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => initialToken);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => refreshController.stream);
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      // Simulate FCM token rotation
      refreshController.add(refreshedToken);

      // Allow the stream listener to process
      await Future<void>.delayed(Duration.zero);

      // Verify initial token was sent
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body', that: _bodyWithToken(initialToken)),
          )).called(1);

      // Verify refreshed token was also sent
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body', that: _bodyWithToken(refreshedToken)),
          )).called(1);

      await refreshController.close();
    });

    test('sends each rotated token to backend on multiple refreshes',
        () async {
      final refreshController = StreamController<String>();

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => 'launch-token');
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => refreshController.stream);
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      refreshController.add('rotated-token-1');
      await Future<void>.delayed(Duration.zero);
      refreshController.add('rotated-token-2');
      await Future<void>.delayed(Duration.zero);

      // 1 initial + 2 refreshes = 3 total calls
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body'),
          )).called(3);

      await refreshController.close();
    });

    test('subscribes to token refresh stream on launch', () async {
      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => 'some-token');
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      verify(() => mockTokenService.onTokenRefresh).called(1);
    });

    test('stops forwarding refreshed tokens after dispose', () async {
      final refreshController = StreamController<String>();

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => 'initial-token');
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => refreshController.stream);
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      // Dispose cancels the refresh subscription
      registrationService.dispose();

      // Token rotated after dispose — should NOT reach backend
      refreshController.add('post-dispose-token');
      await Future<void>.delayed(Duration.zero);

      // Only the initial token should have been sent
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body'),
          )).called(1);

      await refreshController.close();
    });

    test('forwards refreshed tokens even when initial token was null',
        () async {
      final refreshController = StreamController<String>();

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => null);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => refreshController.stream);
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      // No initial call (token was null)
      verifyNever(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          ));

      // FCM rotates and provides a token later
      refreshController.add('late-arrival-token');
      await Future<void>.delayed(Duration.zero);

      // Refreshed token should still be sent
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body', that: _bodyWithToken('late-arrival-token')),
          )).called(1);

      await refreshController.close();
    });

    test('posts to the correct device-tokens endpoint', () async {
      const token = 'endpoint-check-token';

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => token);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'ok'});

      await registrationService.registerOnLaunch();

      final captured = verify(() => mockApiClient.post(
            captureAny(),
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured[0], '/api/v1/device-tokens');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['token'], token);
      expect(body['platform'], anyOf('android', 'ios'));
      expect(body['timezone'], isNotEmpty);
    });

    test('retries on failure and succeeds on subsequent attempt', () async {
      const token = 'retry-test-token';
      var callCount = 0;

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => token);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw ApiException(500, 'Server error');
        return {'status': 'ok'};
      });

      await registrationService.registerOnLaunch();

      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body'),
          )).called(2);
    });

    test('gives up after max retries without throwing', () async {
      const token = 'persistent-failure-token';

      when(() => mockTokenService.getToken())
          .thenAnswer((_) async => token);
      when(() => mockTokenService.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockApiClient.post(
            any(),
            body: any(named: 'body'),
          )).thenThrow(ApiException(500, 'Server error'));

      // Should not throw
      await registrationService.registerOnLaunch();

      // 1 initial + 3 retries = 4 total attempts
      verify(() => mockApiClient.post(
            '/api/v1/device-tokens',
            body: any(named: 'body'),
          )).called(4);
    });
  });
}
