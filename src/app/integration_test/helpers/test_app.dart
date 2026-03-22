import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gocalgo/config/router.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/providers/onboarding_provider.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/flag_store.dart';

import 'backend_config.dart';

/// Builds a [ProviderScope]-wrapped app for integration testing against
/// the local backend, bypassing Firebase and SQLite dependencies.
Widget buildTestApp({
  String? apiBaseUrl,
  bool skipOnboarding = true,
  List<Override> overrides = const [],
}) {
  final baseUrl = apiBaseUrl ?? BackendConfig.apiV1Url;

  return ProviderScope(
    overrides: [
      // Point the events service at the local backend API.
      cachedEventsServiceProvider.overrideWithValue(
        CachedEventsService(
          remote: EventsService(
            apiClient: ApiClient(baseUrl: baseUrl),
          ),
          cache: _NoOpEventCache(),
        ),
      ),
      // Skip onboarding so integration tests land on the home screen.
      if (skipOnboarding)
        hasCompletedOnboardingProvider.overrideWith((_) async => true),
      // Use an in-memory flag store (no SQLite needed).
      flagStoreProvider.overrideWithValue(_InMemoryFlagStore()),
      ...overrides,
    ],
    child: const _IntegrationTestApp(),
  );
}

class _IntegrationTestApp extends ConsumerWidget {
  const _IntegrationTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GoCalGo Integration Test',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

/// No-op event cache — integration tests always fetch from the real backend.
class _NoOpEventCache implements EventCache {
  @override
  Future<void> put(EventsResponse response) async {}

  @override
  Future<EventsResponse?> get() async => null;

  @override
  Future<void> clear() async {}
}

/// Minimal in-memory flag store for integration tests.
class _InMemoryFlagStore implements FlagStore {
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
