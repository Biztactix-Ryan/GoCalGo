import 'dart:math';

import 'api_client.dart';
import 'device_token_service.dart';
import 'notification_settings_store.dart';

/// Syncs notification preferences to the backend so the scheduler
/// respects the user's global settings (enabled toggle, lead time,
/// event type filters).
///
/// Failed syncs are retried with exponential backoff. Local settings
/// are always saved first — sync failures do not block the UI.
class NotificationSettingsSyncService {
  final ApiClient _apiClient;
  final DeviceTokenService _deviceTokenService;

  static const String _syncPath = '/api/v1/notification-settings';
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(seconds: 2);

  NotificationSettingsSyncService({
    required ApiClient apiClient,
    required DeviceTokenService deviceTokenService,
  })  : _apiClient = apiClient,
        _deviceTokenService = deviceTokenService;

  /// Posts the given settings to the backend, keyed by the device's FCM token.
  ///
  /// Silently returns on failure after retries are exhausted — the local
  /// settings remain the source of truth and will be re-synced on the
  /// next update.
  Future<void> sync(NotificationSettings settings) async {
    final token = await _deviceTokenService.getToken();
    if (token == null) return;

    final body = <String, dynamic>{
      'fcmToken': token,
      'enabled': settings.enabled,
      'leadTimeMinutes': settings.leadTimeMinutes,
      'enabledEventTypes':
          settings.enabledEventTypes.map((t) => t.toJson()).toList(),
    };

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await _apiClient.post(_syncPath, body: body);
        return;
      } catch (_) {
        if (attempt == _maxRetries) return;
        final delay = _initialBackoff * pow(2, attempt);
        await Future<void>.delayed(delay);
      }
    }
  }
}
