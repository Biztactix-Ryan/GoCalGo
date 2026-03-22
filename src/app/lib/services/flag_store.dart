/// Abstract interface for local event flag persistence.
///
/// Implementations may use SQLite, shared preferences, or in-memory storage.
/// Flags represent events the user has marked for notifications or quick access.
abstract class FlagStore {
  /// Flag an event by its ID. Idempotent — re-flagging is a no-op.
  Future<void> flag(String eventId);

  /// Remove the flag from an event. No-op if the event is not flagged.
  Future<void> unflag(String eventId);

  /// Returns whether the given event is currently flagged.
  Future<bool> isFlagged(String eventId);

  /// Returns the set of all flagged event IDs.
  Future<Set<String>> flaggedIds();

  /// Removes all flags.
  Future<void> clearAll();
}
