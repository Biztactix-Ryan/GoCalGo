import '../models/event_type.dart';

/// Notification settings that persist locally and sync to backend.
///
/// Captures the user's notification preferences: master toggle, lead time
/// before event end, and which event types should trigger notifications.
class NotificationSettings {
  final bool enabled;
  final int leadTimeMinutes;
  final Set<EventType> enabledEventTypes;

  const NotificationSettings({
    this.enabled = true,
    this.leadTimeMinutes = 15,
    this.enabledEventTypes = const {},
  });

  /// Default settings: notifications enabled, 15-minute lead time, all types.
  factory NotificationSettings.defaults() => NotificationSettings(
        enabled: true,
        leadTimeMinutes: 15,
        enabledEventTypes: EventType.values.toSet(),
      );

  /// Allowed lead time values in minutes.
  static const allowedLeadTimes = [5, 15, 30, 60];

  NotificationSettings copyWith({
    bool? enabled,
    int? leadTimeMinutes,
    Set<EventType>? enabledEventTypes,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
        enabledEventTypes: enabledEventTypes ?? this.enabledEventTypes,
      );
}

/// Abstract interface for local notification settings persistence.
///
/// Implementations may use SQLite or in-memory storage.
abstract class NotificationSettingsStore {
  /// Loads the saved settings, or returns defaults if none are stored.
  Future<NotificationSettings> load();

  /// Persists the given settings locally.
  Future<void> save(NotificationSettings settings);

  /// Resets to default settings.
  Future<void> reset();
}
