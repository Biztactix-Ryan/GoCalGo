import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channel for event-related push notifications.
const AndroidNotificationChannel eventNotificationChannel =
    AndroidNotificationChannel(
  'gocalgo_events',
  'Event Notifications',
  description: 'Notifications about Pokemon GO events starting or ending soon.',
  importance: Importance.high,
);

/// Callback invoked when the user taps a local notification shown in the
/// foreground. The [payload] contains the `eventId` string.
typedef NotificationTapCallback = FutureOr<void> Function(String? payload);

/// Configures [FlutterLocalNotificationsPlugin] for foreground notification
/// display and manages platform-specific notification channels and permissions.
///
/// On Android, creates a high-importance notification channel so heads-up
/// notifications appear. On iOS, requests notification permissions during
/// onboarding via [requestIOSPermission].
class NotificationDisplayService {
  NotificationDisplayService({
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseMessaging? messaging,
    Stream<RemoteMessage>? onMessage,
  })  : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _messaging = messaging ?? FirebaseMessaging.instance,
        _onMessage = onMessage ?? FirebaseMessaging.onMessage;

  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseMessaging _messaging;
  final Stream<RemoteMessage> _onMessage;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  /// Callback for handling taps on local notifications shown in the foreground.
  /// Set this before or after [init] to receive tap events.
  NotificationTapCallback? onNotificationTap;

  /// Initialises the plugin, creates Android notification channels, and starts
  /// listening for foreground FCM messages.
  ///
  /// Must be called once during app startup, after Firebase is initialised.
  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create the Android notification channel.
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(eventNotificationChannel);
    }

    // Enable foreground notification presentation on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show a local notification for each FCM message received in foreground.
    _foregroundSubscription = _onMessage.listen(_showForegroundNotification);
  }

  /// Requests notification permissions on iOS.
  ///
  /// Call this at an appropriate moment (e.g. the notification onboarding page)
  /// rather than immediately on first launch to respect the user's attention.
  /// Returns `true` if the user granted permission.
  Future<bool> requestIOSPermission() async {
    if (!Platform.isIOS) return true;

    final iosPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin == null) return false;

    final granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          eventNotificationChannel.id,
          eventNotificationChannel.name,
          channelDescription: eventNotificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['eventId'] as String?,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call(payload);
    }
  }

  void dispose() {
    _foregroundSubscription?.cancel();
  }
}
