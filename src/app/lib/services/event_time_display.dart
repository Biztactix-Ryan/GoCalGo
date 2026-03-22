import 'package:intl/intl.dart';

import '../models/event_dto.dart';

/// Converts event times to display strings in the device's local timezone.
///
/// Two modes based on [EventDto.isUtcTime]:
/// - **UTC events** (e.g. GO Fest global raids): stored as UTC, converted to
///   the device's local timezone for display.
/// - **Local-time events** (e.g. Community Day 2-5pm): stored without timezone,
///   displayed as-is because the wall-clock time is the same everywhere.
class EventTimeDisplay {
  static final _timeFormat = DateFormat('h:mm a');
  static final _dateFormat = DateFormat('MMM d');
  static final _dateTimeFormat = DateFormat('MMM d, h:mm a');

  /// Returns the local display [DateTime] for the event's start time.
  ///
  /// For UTC events, converts to local. For local-time events, returns as-is.
  static DateTime? localStart(EventDto event) =>
      _toDisplayTime(event.start, event.isUtcTime);

  /// Returns the local display [DateTime] for the event's end time.
  static DateTime? localEnd(EventDto event) =>
      _toDisplayTime(event.end, event.isUtcTime);

  /// Formats the event's time range for display (e.g. "2:00 PM – 5:00 PM").
  static String formatTimeRange(EventDto event) {
    final start = localStart(event);
    final end = localEnd(event);

    if (start == null && end == null) return 'Time TBD';
    if (start != null && end == null) return 'Starts ${_timeFormat.format(start)}';
    if (start == null && end != null) return 'Ends ${_timeFormat.format(end)}';

    // If start and end are on different days, include the date.
    if (start!.year != end!.year ||
        start.month != end.month ||
        start.day != end.day) {
      return '${_dateTimeFormat.format(start)} – ${_dateTimeFormat.format(end)}';
    }

    return '${_timeFormat.format(start)} – ${_timeFormat.format(end)}';
  }

  /// Formats the event's date for display (e.g. "Mar 21").
  static String formatDate(EventDto event) {
    final start = localStart(event);
    if (start == null) return 'Date TBD';
    return _dateFormat.format(start);
  }

  static DateTime? _toDisplayTime(DateTime? time, bool isUtcTime) {
    if (time == null) return null;
    if (isUtcTime) {
      // Ensure the DateTime is treated as UTC, then convert to local.
      final utc = time.isUtc ? time : DateTime.utc(
        time.year, time.month, time.day,
        time.hour, time.minute, time.second, time.millisecond,
      );
      return utc.toLocal();
    }
    // Local-time event: return as-is (same wall-clock time everywhere).
    return time;
  }
}
