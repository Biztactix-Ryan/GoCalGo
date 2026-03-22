import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/widgets/loading_indicator.dart';
import 'package:gocalgo/widgets/error_state.dart';
import 'package:gocalgo/widgets/empty_state.dart';
import 'package:gocalgo/widgets/shimmer.dart';
import 'package:gocalgo/widgets/skeleton_event_card.dart';
import 'package:gocalgo/config/theme.dart';

/// Verifies acceptance criterion for story US-GCG-7:
/// "Loading and error states are handled gracefully"
///
/// Tests cover:
/// - API error propagation (4xx, 5xx status codes)
/// - Network / socket errors
/// - Widget states: loading skeleton, error with retry, empty state
/// - Transitions between loading → success, loading → error, loading → empty
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  final now = DateTime(2026, 3, 21, 14, 0);

  Map<String, dynamic> _buildResponse({
    required List<Map<String, dynamic>> events,
    String lastUpdated = '2026-03-21T12:00:00Z',
    bool cacheHit = false,
  }) {
    return {
      'events': events,
      'lastUpdated': lastUpdated,
      'cacheHit': cacheHit,
    };
  }

  Map<String, dynamic> _event({
    required String id,
    required String name,
    String? start,
    String? end,
  }) {
    return {
      'id': id,
      'name': name,
      'eventType': 'general',
      'heading': name,
      'imageUrl': 'https://example.com/$id.png',
      'linkUrl': 'https://example.com/$id',
      'start': start ?? '2026-03-21T10:00:00.000',
      'end': end ?? '2026-03-21T20:00:00.000',
      'isUtcTime': false,
      'hasSpawns': false,
      'hasResearchTasks': false,
      'buffs': [],
      'featuredPokemon': [],
      'promoCodes': [],
    };
  }

  EventsService _serviceWith(MockClient mockClient) {
    final apiClient =
        ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
    return EventsService(apiClient: apiClient);
  }

  // ---------------------------------------------------------------------------
  // Service-level: API errors throw ApiException with correct status code
  // ---------------------------------------------------------------------------

  group('Service-level error handling', () {
    test('404 response throws ApiException with statusCode 404', () async {
      final service = _serviceWith(
        MockClient((_) async => http.Response('Not Found', 404)),
      );

      expect(
        () => service.getEvents(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('500 response throws ApiException with statusCode 500', () async {
      final service = _serviceWith(
        MockClient((_) async => http.Response('Internal Server Error', 500)),
      );

      expect(
        () => service.getActiveEvents(now: now),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('503 response throws ApiException with statusCode 503', () async {
      final service = _serviceWith(
        MockClient((_) async => http.Response('Service Unavailable', 503)),
      );

      expect(
        () => service.getUpcomingEvents(now: now),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('ApiException includes response body for debugging', () async {
      const body = '{"error": "rate limited"}';
      final service = _serviceWith(
        MockClient((_) async => http.Response(body, 429)),
      );

      expect(
        () => service.getEvents(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.body, 'body', body),
        ),
      );
    });

    test('network error (SocketException) propagates to caller', () async {
      final service = _serviceWith(
        MockClient((_) async =>
            throw const SocketException('Connection refused')),
      );

      expect(
        () => service.getEvents(),
        throwsA(isA<SocketException>()),
      );
    });

    test('malformed JSON response throws FormatException', () async {
      final service = _serviceWith(
        MockClient((_) async => http.Response('not json', 200)),
      );

      expect(
        () => service.getEvents(),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty events list returns empty result, not an error', () async {
      final service = _serviceWith(
        MockClient((_) async => http.Response(
              jsonEncode(_buildResponse(events: [])),
              200,
            )),
      );

      final result = await service.getActiveEvents(now: now);
      expect(result, isEmpty);
    });

    test('successful recovery after transient error', () async {
      var callCount = 0;
      final service = _serviceWith(
        MockClient((_) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Server Error', 500);
          }
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-1', name: 'Event 1')],
            )),
            200,
          );
        }),
      );

      // First call fails.
      expect(
        () => service.getActiveEvents(now: now),
        throwsA(isA<ApiException>()),
      );

      // Second call succeeds — no stale error state.
      final events = await service.getActiveEvents(now: now);
      expect(events, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget-level: SkeletonEventCard / SkeletonEventList as loading placeholder
  // ---------------------------------------------------------------------------

  group('Loading state widgets', () {
    testWidgets('SkeletonEventList renders the correct number of cards',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList(itemCount: 3)),
        ),
      );

      // SkeletonEventList builds 3 cards; some may be off-screen.
      expect(find.byType(SkeletonEventCard), findsAtLeast(2));
    });

    testWidgets('SkeletonEventCard contains shimmer animation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList()),
        ),
      );

      // Shimmer wraps the skeleton content.
      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('LoadingIndicator can serve as a fallback loading state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: LoadingIndicator(message: 'Fetching events...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetching events...'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget-level: ErrorState with retry for graceful error recovery
  // ---------------------------------------------------------------------------

  group('Error state widgets', () {
    testWidgets('ErrorState shows message and retry button', (tester) async {
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ErrorState(
              message: 'Failed to load events',
              onRetry: () => retryCount++,
            ),
          ),
        ),
      );

      expect(find.text('Failed to load events'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retryCount, 1);
    });

    testWidgets('network error uses cloud_off icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ErrorState(
              message: 'No internet connection',
              icon: Icons.cloud_off,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.icon, equals(Icons.cloud_off));
    });

    testWidgets('error state without retry hides the button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ErrorState(message: 'Permanent error'),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget-level: EmptyState when there are no events
  // ---------------------------------------------------------------------------

  group('Empty state widgets', () {
    testWidgets('shows default empty state for no events', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: EmptyState()),
        ),
      );

      expect(find.text('No events today'), findsOneWidget);
      expect(find.byIcon(Icons.event_busy), findsOneWidget);
    });

    testWidgets('empty state is visually distinct from error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: EmptyState()),
        ),
      );

      // EmptyState uses secondary text color, not error color.
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(AppTheme.textSecondary));
      expect(icon.color, isNot(equals(AppTheme.pokemonRed)));
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: simulated state transitions
  // ---------------------------------------------------------------------------

  group('State transition simulation', () {
    testWidgets('loading → success: skeleton replaced by content',
        (tester) async {
      // Start in loading state.
      final stateNotifier = ValueNotifier<String>('loading');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: stateNotifier,
              builder: (_, state, __) {
                switch (state) {
                  case 'loading':
                    return const SkeletonEventList();
                  case 'error':
                    return ErrorState(
                      message: 'Failed to load',
                      onRetry: () => stateNotifier.value = 'loading',
                    );
                  case 'empty':
                    return const EmptyState();
                  default:
                    return const Text('Events loaded');
                }
              },
            ),
          ),
        ),
      );

      // Verify loading skeleton is visible.
      expect(find.byType(SkeletonEventCard), findsWidgets);
      expect(find.text('Events loaded'), findsNothing);

      // Transition to success.
      stateNotifier.value = 'success';
      await tester.pump();

      expect(find.byType(SkeletonEventCard), findsNothing);
      expect(find.text('Events loaded'), findsOneWidget);
    });

    testWidgets('loading → error: skeleton replaced by error state',
        (tester) async {
      final stateNotifier = ValueNotifier<String>('loading');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: stateNotifier,
              builder: (_, state, __) {
                if (state == 'loading') {
                  return const SkeletonEventList();
                }
                return ErrorState(
                  message: 'Something went wrong',
                  onRetry: () => stateNotifier.value = 'loading',
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonEventCard), findsWidgets);

      stateNotifier.value = 'error';
      await tester.pump();

      expect(find.byType(SkeletonEventCard), findsNothing);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('error → retry → loading: retry returns to loading state',
        (tester) async {
      final stateNotifier = ValueNotifier<String>('error');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: stateNotifier,
              builder: (_, state, __) {
                if (state == 'loading') {
                  return const SkeletonEventList();
                }
                return ErrorState(
                  message: 'Failed to load',
                  onRetry: () => stateNotifier.value = 'loading',
                );
              },
            ),
          ),
        ),
      );

      // Start in error state.
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry → back to loading.
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.byType(SkeletonEventCard), findsWidgets);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('loading → empty: skeleton replaced by empty state',
        (tester) async {
      final stateNotifier = ValueNotifier<String>('loading');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: stateNotifier,
              builder: (_, state, __) {
                if (state == 'loading') {
                  return const SkeletonEventList();
                }
                return const EmptyState();
              },
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonEventCard), findsWidgets);

      stateNotifier.value = 'empty';
      await tester.pump();

      expect(find.byType(SkeletonEventCard), findsNothing);
      expect(find.text('No events today'), findsOneWidget);
    });
  });
}

