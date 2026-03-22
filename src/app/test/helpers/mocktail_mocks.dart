import 'package:mocktail/mocktail.dart';

import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/device_token_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/flag_store.dart';
import 'package:gocalgo/services/notification_display_service.dart';
import 'package:gocalgo/services/onboarding_store.dart';

/// Mocktail mock for [ApiClient].
///
/// Use when you need to verify HTTP interactions or stub specific API
/// responses at the client level.
class MockApiClient extends Mock implements ApiClient {}

/// Mocktail mock for [EventsService].
///
/// Use when testing code that depends on the remote events service and you
/// need fine-grained control over stubbing and call verification.
class MockEventsServiceMocktail extends Mock implements EventsService {}

/// Mocktail mock for [CachedEventsService].
///
/// Use when testing providers or screens that depend on the cached service
/// layer without needing real cache or network behaviour.
class MockCachedEventsService extends Mock implements CachedEventsService {}

/// Mocktail mock for [EventCache].
///
/// Use when testing cache interactions (put/get/clear) without SQLite.
class MockEventCache extends Mock implements EventCache {}

/// Mocktail mock for [FlagStore].
///
/// Use when testing flag-related providers or screens without SQLite.
class MockFlagStore extends Mock implements FlagStore {}

/// Mocktail mock for [OnboardingStore].
///
/// Use when testing onboarding flow without SQLite.
class MockOnboardingStore extends Mock implements OnboardingStore {}

/// Mocktail mock for [DeviceTokenService].
///
/// Use when testing FCM device token retrieval and refresh without Firebase.
class MockDeviceTokenService extends Mock implements DeviceTokenService {}

/// Mocktail mock for [NotificationDisplayService].
///
/// Use when testing notification display and permission flows without
/// the local notifications plugin.
class MockNotificationDisplayService extends Mock
    implements NotificationDisplayService {}
