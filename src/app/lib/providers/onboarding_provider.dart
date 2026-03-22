import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/onboarding_store.dart';
import '../services/sqlite_onboarding_store.dart';

/// Singleton onboarding store for tracking first-launch state.
final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  final store = SqliteOnboardingStore();
  ref.onDispose(() => (store).close());
  return store;
});

/// Whether the user has completed onboarding. Used by the router to decide
/// whether to show the onboarding carousel or the main app.
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final store = ref.read(onboardingStoreProvider);
  return store.hasCompletedOnboarding();
});
