import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/widgets/stale_data_banner.dart';

/// Verifies acceptance criterion for story US-GCG-26:
/// "Offline mode banner when no network connection"
///
/// Tests the full offline-to-banner pipeline: when the network is down,
/// [CachedEventsService] falls back to cached data with [cacheHit]=true,
/// [EventsState.shouldShowStaleBanner] returns true, and [StaleDataBanner]
/// renders the offline indicator with appropriate messaging.
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildResponse({
    required List<Map<String, dynamic>> events,
    required String lastUpdated,
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
      'eventType': 'event',
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

  CachedEventsService _buildService({
    required MockClient client,
    required InMemoryEventCache cache,
  }) {
    final api = ApiClient(httpClient: client, baseUrl: 'http://test.local');
    final remote = EventsService(apiClient: api);
    return CachedEventsService(remote: remote, cache: cache);
  }

  Widget buildBannerWidget({DateTime? lastUpdated}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StaleDataBanner(lastUpdated: lastUpdated),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Service-level: offline fallback triggers banner condition
  // ---------------------------------------------------------------------------

  group('US-GCG-26 — Offline mode banner when no network connection', () {
    test('SocketException (no network) triggers cache fallback with '
        'cacheHit=true', () async {
      final cache = InMemoryEventCache();

      // Seed cache with a prior sync.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Community Day')],
            lastUpdated: '2026-03-21T09:00:00Z',
          )),
          200,
        );
      });
      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Simulate complete network loss.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });
      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final result = await offlineService.getEvents();

      expect(result.cacheHit, isTrue,
          reason: 'Network failure must fall back to cache with cacheHit=true');
    });

    test('EventsState built from offline fallback has shouldShowStaleBanner '
        'returning true', () async {
      final cache = InMemoryEventCache();

      // Seed cache.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Raid Hour')],
            lastUpdated: '2026-03-21T09:00:00Z',
          )),
          200,
        );
      });
      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Go offline.
      final offlineClient = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });
      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final response = await offlineService.getEvents();

      // Build EventsState the same way the provider does.
      final state = EventsState(
        events: response.events,
        isStale: response.cacheHit,
        lastUpdated: response.lastUpdated,
      );

      expect(state.shouldShowStaleBanner(), isTrue,
          reason:
              'Offline cache fallback must cause the stale banner to display');
      expect(state.isStale, isTrue);
    });

    test('no cached data and no network throws instead of showing empty banner',
        () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });
      final offlineService =
          _buildService(client: offlineClient, cache: cache);

      expect(
        () => offlineService.getEvents(),
        throwsA(isA<SocketException>()),
        reason: 'With no cache and no network, the error should propagate '
            'so the UI can show an error state, not an empty banner',
      );
    });

    test('offline fallback preserves lastUpdated for banner timestamp display',
        () async {
      final cache = InMemoryEventCache();
      const syncTime = '2026-03-21T06:30:00Z';

      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Spotlight Hour')],
            lastUpdated: syncTime,
          )),
          200,
        );
      });
      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Network down.
      final offlineClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });
      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final result = await offlineService.getEvents();

      expect(result.lastUpdated, DateTime.parse(syncTime),
          reason: 'Banner needs the original sync timestamp to show '
              '"Showing cached data from <time>"');
    });

    // -------------------------------------------------------------------------
    // Widget-level: banner renders offline messaging
    // -------------------------------------------------------------------------

    testWidgets('banner displays cloud_off icon for offline state',
        (tester) async {
      await tester.pumpWidget(
        buildBannerWidget(lastUpdated: DateTime.utc(2026, 3, 21, 9, 0)),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon, isNotNull);
      expect(icon.size, 16,
          reason: 'cloud_off icon indicates offline/stale status');
    });

    testWidgets('banner message includes "you may be offline" when timestamp '
        'is available', (tester) async {
      await tester.pumpWidget(
        buildBannerWidget(lastUpdated: DateTime.utc(2026, 3, 21, 9, 0)),
      );

      expect(find.textContaining('you may be offline'), findsOneWidget);
      expect(find.textContaining('Showing cached data from'), findsOneWidget);
    });

    testWidgets('banner shows generic offline message when no timestamp',
        (tester) async {
      await tester.pumpWidget(buildBannerWidget());

      expect(
        find.text('Showing cached data — you may be offline'),
        findsOneWidget,
        reason: 'With no timestamp the banner should still indicate '
            'offline/stale status',
      );
    });

    testWidgets('banner is visible (non-zero size) when rendered',
        (tester) async {
      await tester.pumpWidget(
        buildBannerWidget(lastUpdated: DateTime.utc(2026, 3, 21, 9, 0)),
      );

      final bannerBox = tester.renderObject<RenderBox>(
        find.byType(StaleDataBanner),
      );
      expect(bannerBox.size.height, greaterThan(0),
          reason: 'Offline banner must be visible to the user');
      expect(bannerBox.size.width, greaterThan(0));
    });
  });
}

/// Simple in-memory [EventCache] implementation for testing.
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
