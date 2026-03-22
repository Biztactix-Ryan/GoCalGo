import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/events_response.dart';

import 'test_data.dart';

/// A mock events service that returns configurable data without any
/// HTTP or backend dependency.
///
/// Use this in tests where you need an [EventsService]-like object
/// but don't want to set up [MockClient] and JSON plumbing.
///
/// ```dart
/// final mock = MockEventsService(events: [TestData.communityDay()]);
/// final response = await mock.getEvents();
/// ```
class MockEventsService {
  /// The events that [getEvents] will return.
  List<EventDto> events;

  /// The [lastUpdated] timestamp on returned responses.
  DateTime lastUpdated;

  /// Whether returned responses should report as cache hits.
  bool cacheHit;

  /// When true, all methods throw [MockApiException] to simulate
  /// network failures.
  bool simulateError;

  /// Optional delay to simulate network latency.
  Duration? latency;

  /// Tracks how many times [getEvents] has been called.
  int getEventsCallCount = 0;

  /// Tracks how many times [getActiveEvents] has been called.
  int getActiveEventsCallCount = 0;

  /// Tracks how many times [getUpcomingEvents] has been called.
  int getUpcomingEventsCallCount = 0;

  MockEventsService({
    List<EventDto>? events,
    DateTime? lastUpdated,
    this.cacheHit = false,
    this.simulateError = false,
    this.latency,
  })  : events = events ?? [TestData.event()],
        lastUpdated = lastUpdated ?? DateTime(2026, 3, 21, 12, 0);

  /// Returns an [EventsResponse] built from the configured [events].
  ///
  /// Throws [MockApiException] when [simulateError] is true.
  Future<EventsResponse> getEvents() async {
    getEventsCallCount++;
    if (latency != null) {
      await Future<void>.delayed(latency!);
    }
    if (simulateError) {
      throw MockApiException('Simulated API error');
    }
    return EventsResponse(
      events: events,
      lastUpdated: lastUpdated,
      cacheHit: cacheHit,
    );
  }

  /// Returns currently active events from the configured [events] list.
  ///
  /// An event is active when [now] falls between its start and end times.
  Future<List<EventDto>> getActiveEvents({DateTime? now}) async {
    getActiveEventsCallCount++;
    final response = await getEvents();
    // Undo the getEvents increment since we're delegating
    getEventsCallCount--;
    final timestamp = now ?? DateTime.now();
    return response.events.where((e) {
      if (e.start == null) return false;
      final started = !e.start!.isAfter(timestamp);
      final notEnded = e.end == null || e.end!.isAfter(timestamp);
      return started && notEnded;
    }).toList();
  }

  /// Returns upcoming events from the configured [events] list.
  ///
  /// When [days] is provided, only events starting within that window
  /// from [now] are included.
  Future<List<EventDto>> getUpcomingEvents({DateTime? now, int? days}) async {
    getUpcomingEventsCallCount++;
    final response = await getEvents();
    // Undo the getEvents increment since we're delegating
    getEventsCallCount--;
    final timestamp = now ?? DateTime.now();
    final cutoff = days != null ? timestamp.add(Duration(days: days)) : null;
    return response.events.where((e) {
      if (e.start == null) return true;
      if (!e.start!.isAfter(timestamp)) return false;
      if (cutoff != null && e.start!.isAfter(cutoff)) return false;
      return true;
    }).toList();
  }

  void dispose() {}
}

/// Exception thrown by [MockEventsService] when [simulateError] is true.
class MockApiException implements Exception {
  final String message;
  const MockApiException(this.message);

  @override
  String toString() => 'MockApiException: $message';
}
