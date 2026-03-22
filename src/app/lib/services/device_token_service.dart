import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract interface for obtaining and managing FCM device tokens.
///
/// Implementations wrap the platform-specific Firebase Cloud Messaging SDK.
/// The app calls [getToken] on first launch and whenever FCM rotates the
/// token (via [onTokenRefresh]).
abstract class DeviceTokenService {
  /// Request the current FCM device token.
  ///
  /// Returns the token string, or `null` if the user has denied notification
  /// permissions or the token is otherwise unavailable.
  Future<String?> getToken();

  /// A stream that emits a new token whenever FCM rotates it.
  ///
  /// Listeners should forward the refreshed token to the backend so that
  /// push notifications continue to reach this device.
  Stream<String> get onTokenRefresh;
}

/// Production implementation backed by Firebase Cloud Messaging.
class FirebaseDeviceTokenService implements DeviceTokenService {
  FirebaseDeviceTokenService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Requests notification permissions from the user.
  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
}

final deviceTokenServiceProvider = Provider<DeviceTokenService>((ref) {
  return FirebaseDeviceTokenService();
});
