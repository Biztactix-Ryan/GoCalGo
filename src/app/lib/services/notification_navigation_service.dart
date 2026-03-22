import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../models/event_dto.dart';
import 'cached_events_service.dart';

/// Handles notification tap events and navigates to the relevant event.
///
/// Listens for two FCM scenarios:
/// - **Cold start:** App was terminated; the user tapped a notification to
///   launch it. Handled via [FirebaseMessaging.getInitialMessage].
/// - **Background:** App was in the background; the user tapped a notification.
///   Handled via [FirebaseMessaging.onMessageOpenedApp].
///
/// In both cases the service extracts the `eventId` from the notification's
/// data payload, fetches the matching [EventDto], and pushes the event detail
/// route.
class NotificationNavigationService {
  NotificationNavigationService({
    required FirebaseMessaging messaging,
    required CachedEventsService eventsService,
    required GoRouter router,
    Stream<RemoteMessage>? onMessageOpenedApp,
    Stream<RemoteMessage>? onMessage,
  })  : _messaging = messaging,
        _eventsService = eventsService,
        _router = router,
        _onMessageOpenedApp =
            onMessageOpenedApp ?? FirebaseMessaging.onMessageOpenedApp,
        _onMessage = onMessage ?? FirebaseMessaging.onMessage;

  final FirebaseMessaging _messaging;
  final CachedEventsService _eventsService;
  final GoRouter _router;
  final Stream<RemoteMessage> _onMessageOpenedApp;
  final Stream<RemoteMessage> _onMessage;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;

  /// Initialises notification tap handling.
  ///
  /// Must be called once during app startup, after Firebase is initialised.
  Future<void> init() async {
    // Handle cold-start tap (app was terminated).
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage);
    }

    // Handle background tap (app was in background).
    _onMessageOpenedSubscription =
        _onMessageOpenedApp.listen(_handleMessage);

    // Handle foreground message (app is in foreground).
    _onMessageSubscription = _onMessage.listen(_handleMessage);
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final eventId = message.data['eventId'] as String?;
    if (eventId == null) return;

    final event = await _findEvent(eventId);
    if (event == null) return;

    _router.push('/event/$eventId', extra: event);
  }

  Future<EventDto?> _findEvent(String eventId) async {
    try {
      final response = await _eventsService.getEvents();
      return response.events.cast<EventDto?>().firstWhere(
            (e) => e!.id == eventId,
            orElse: () => null,
          );
    } on Exception {
      return null;
    }
  }

  void dispose() {
    _onMessageOpenedSubscription?.cancel();
    _onMessageSubscription?.cancel();
  }
}
