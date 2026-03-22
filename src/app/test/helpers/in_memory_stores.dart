import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/flag_store.dart';
import 'package:gocalgo/services/notification_settings_store.dart';
import 'package:gocalgo/services/onboarding_store.dart';

/// In-memory [EventCache] for testing without SQLite.
class InMemoryEventCache implements EventCache {
  EventsResponse? _stored;

  @override
  Future<void> put(EventsResponse response) async {
    _stored = response;
  }

  @override
  Future<EventsResponse?> get() async => _stored;

  @override
  Future<void> clear() async {
    _stored = null;
  }
}

/// In-memory [FlagStore] for testing without SQLite.
class InMemoryFlagStore implements FlagStore {
  final Set<String> _ids = {};

  @override
  Future<void> flag(String eventId) async => _ids.add(eventId);

  @override
  Future<void> unflag(String eventId) async => _ids.remove(eventId);

  @override
  Future<bool> isFlagged(String eventId) async => _ids.contains(eventId);

  @override
  Future<Set<String>> flaggedIds() async => {..._ids};

  @override
  Future<void> clearAll() async => _ids.clear();
}

/// In-memory [NotificationSettingsStore] for testing without SQLite.
class InMemoryNotificationSettingsStore implements NotificationSettingsStore {
  NotificationSettings? _settings;

  @override
  Future<NotificationSettings> load() async =>
      _settings ?? NotificationSettings.defaults();

  @override
  Future<void> save(NotificationSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> reset() async {
    _settings = null;
  }
}

/// In-memory [OnboardingStore] for testing without SQLite.
class InMemoryOnboardingStore implements OnboardingStore {
  bool _completed = false;

  @override
  Future<bool> hasCompletedOnboarding() async => _completed;

  @override
  Future<void> markOnboardingComplete() async {
    _completed = true;
  }

  @override
  Future<void> resetOnboarding() async {
    _completed = false;
  }
}
