import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'api_client.dart';
import 'device_token_service.dart';

/// Sends FCM device tokens to the .NET backend for push notification targeting.
///
/// On [registerOnLaunch], retrieves the current token and POSTs it to the
/// backend. Also subscribes to [DeviceTokenService.onTokenRefresh] so that
/// rotated tokens are forwarded automatically.
///
/// Failed requests are retried with exponential backoff.
class TokenRegistrationService {
  final DeviceTokenService _deviceTokenService;
  final ApiClient _apiClient;

  StreamSubscription<String>? _refreshSubscription;

  static const String _registrationPath = '/api/v1/device-tokens';
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(seconds: 2);

  TokenRegistrationService({
    required DeviceTokenService deviceTokenService,
    required ApiClient apiClient,
  })  : _deviceTokenService = deviceTokenService,
        _apiClient = apiClient;

  /// Registers the current device token with the backend and subscribes
  /// to future token refreshes.
  ///
  /// Should be called once during app initialisation.
  Future<void> registerOnLaunch() async {
    final token = await _deviceTokenService.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    _refreshSubscription = _deviceTokenService.onTokenRefresh.listen(
      (newToken) => _sendToken(newToken),
    );
  }

  /// Sends a single token to the backend registration endpoint.
  /// Retries with exponential backoff on failure.
  Future<void> _sendToken(String token) async {
    final body = <String, dynamic>{
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'timezone': DateTime.now().timeZoneName,
    };

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await _apiClient.post(_registrationPath, body: body);
        return;
      } catch (_) {
        if (attempt == _maxRetries) return;
        final delay = _initialBackoff * pow(2, attempt);
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Cancels the token-refresh listener. Call when the service is no longer
  /// needed to prevent memory leaks.
  void dispose() {
    _refreshSubscription?.cancel();
  }
}
