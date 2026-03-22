/// Abstract interface for tracking onboarding completion state.
///
/// Implementations may use SQLite, shared preferences, or in-memory storage.
/// This ensures onboarding is only shown once per device.
abstract class OnboardingStore {
  /// Returns whether the user has completed (or skipped) onboarding.
  Future<bool> hasCompletedOnboarding();

  /// Marks onboarding as completed. Idempotent — calling again is a no-op.
  Future<void> markOnboardingComplete();

  /// Resets onboarding state so it will show again on next launch.
  Future<void> resetOnboarding();
}
