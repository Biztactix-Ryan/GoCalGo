import 'package:intl/intl.dart';

import '../models/event_dto.dart';
import 'event_time_display.dart';

/// A group of events sharing the same calendar day, with a formatted header.
class DayGroup {
  /// Display header, e.g. "Mon, Mar 23".
  final String header;

  /// The calendar date for this group (time part is midnight).
  final DateTime date;

  /// Events occurring on this day, in their original order.
  final List<EventDto> events;

  const DayGroup({
    required this.header,
    required this.date,
    required this.events,
  });
}

/// Groups a flat list of events by their start date into [DayGroup]s.
///
/// Events are assigned to the day of their local start time (using
/// [EventTimeDisplay.localStart] for timezone handling). Events with
/// no start date are placed in a trailing "Date TBD" group.
///
/// Groups are returned sorted chronologically. Within each group events
/// retain their original list order.
List<DayGroup> groupEventsByDay(List<EventDto> events) {
  final dateFormat = DateFormat('EEE, MMM d');
  final grouped = <DateTime, List<EventDto>>{};
  final List<EventDto> noDate = [];

  for (final event in events) {
    final localStart = EventTimeDisplay.localStart(event);
    if (localStart == null) {
      noDate.add(event);
      continue;
    }
    final dayKey = DateTime(localStart.year, localStart.month, localStart.day);
    grouped.putIfAbsent(dayKey, () => []).add(event);
  }

  final sortedDays = grouped.keys.toList()..sort();
  final groups = <DayGroup>[
    for (final day in sortedDays)
      DayGroup(
        header: dateFormat.format(day),
        date: day,
        events: grouped[day]!,
      ),
    if (noDate.isNotEmpty)
      DayGroup(
        header: 'Date TBD',
        date: DateTime(9999),
        events: noDate,
      ),
  ];

  return groups;
}
