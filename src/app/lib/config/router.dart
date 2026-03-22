import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_dto.dart';
import '../providers/onboarding_provider.dart';
import '../screens/event_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/onboarding_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/upcoming_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingAsync = ref.watch(hasCompletedOnboardingProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final hasCompleted = onboardingAsync.valueOrNull;

      // Still loading onboarding state — don't redirect yet.
      if (hasCompleted == null) return null;

      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasCompleted && !isOnboarding) {
        return '/onboarding';
      }

      if (hasCompleted && isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => OnboardingScreen(
          onComplete: () async {
            final container = ProviderScope.containerOf(context);
            final store = container.read(onboardingStoreProvider);
            await store.markOnboardingComplete();
            container.invalidate(hasCompletedOnboardingProvider);
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upcoming',
                name: 'upcoming',
                builder: (context, state) => const UpcomingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/event/:id',
        name: 'eventDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final event = state.extra as EventDto;
          return EventDetailScreen(event: event);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('No route found for ${state.uri}'),
      ),
    ),
  );
});
