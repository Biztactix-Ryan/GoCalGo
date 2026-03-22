import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/providers/events_provider.dart';

/// Pumps [widget] wrapped in a [ProviderScope] and [MaterialApp] with the app
/// theme applied.
///
/// Override providers via [overrides] to inject test data. For the most common
/// case — overriding the events/flags/connectivity providers — use
/// [pumpScreen] instead.
///
/// ```dart
/// await tester.pumpApp(const HomeScreen());
/// ```
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: widget,
        ),
      ),
    );
  }

  /// Convenience wrapper for screens that depend on the standard trio of
  /// events, flags, and connectivity providers.
  ///
  /// ```dart
  /// await tester.pumpScreen(
  ///   const HomeScreen(),
  ///   events: [TestData.communityDay()],
  ///   flaggedIds: {'cd-test'},
  /// );
  /// await tester.pumpAndSettle();
  /// ```
  Future<void> pumpScreen(
    Widget screen, {
    List<EventDto> events = const [],
    Set<String> flaggedIds = const {},
    bool isError = false,
    bool isOnline = true,
    List<Override> additionalOverrides = const [],
  }) async {
    await pumpApp(
      screen,
      overrides: [
        activeEventsProvider.overrideWith(
          () => FakeEventsNotifier(events: events, isError: isError),
        ),
        flaggedIdsProvider.overrideWith(
          () => FakeFlaggedIdsNotifier(flaggedIds),
        ),
        connectivityProvider.overrideWith(
          () => FakeConnectivityNotifier(isOnline: isOnline),
        ),
        ...additionalOverrides,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable fake notifiers for provider overrides
// ---------------------------------------------------------------------------

/// Fake [EventsNotifier] that returns pre-loaded data without any service
/// dependency.
class FakeEventsNotifier extends EventsNotifier {
  FakeEventsNotifier({this.events = const [], this.isError = false});

  final List<EventDto> events;
  final bool isError;

  @override
  Future<EventsState> build() async {
    if (isError) throw Exception('Network error');
    return EventsState(
      events: events,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> refresh() async {
    state = AsyncData(EventsState(
      events: events,
      lastUpdated: DateTime.now(),
    ));
  }
}

/// Fake [FlaggedIdsNotifier] backed by an in-memory set.
class FakeFlaggedIdsNotifier extends FlaggedIdsNotifier {
  FakeFlaggedIdsNotifier(this._ids);
  final Set<String> _ids;

  @override
  Future<Set<String>> build() async => _ids;

  @override
  Future<void> toggle(String id) async {
    final current = state.valueOrNull ?? {};
    if (current.contains(id)) {
      state = AsyncData({...current}..remove(id));
    } else {
      state = AsyncData({...current, id});
    }
  }
}

/// Fake [ConnectivityNotifier] that emits a fixed online/offline state.
class FakeConnectivityNotifier extends ConnectivityNotifier {
  FakeConnectivityNotifier({this.isOnline = true});
  final bool isOnline;

  @override
  Stream<bool> build() => Stream.value(isOnline);
}

/// Fake [UpcomingEventsNotifier] that returns pre-loaded data.
class FakeUpcomingEventsNotifier extends UpcomingEventsNotifier {
  FakeUpcomingEventsNotifier({this.events = const [], this.isError = false});

  final List<EventDto> events;
  final bool isError;

  @override
  Future<EventsState> build() async {
    if (isError) throw Exception('Network error');
    return EventsState(
      events: events,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> refresh() async {
    state = AsyncData(EventsState(
      events: events,
      lastUpdated: DateTime.now(),
    ));
  }
}
