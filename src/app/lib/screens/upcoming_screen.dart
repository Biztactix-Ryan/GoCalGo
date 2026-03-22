import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_dto.dart';
import '../providers/events_provider.dart';
import '../providers/filter_provider.dart';
import '../services/event_day_grouping.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/event_card.dart';
import '../widgets/event_type_filter_bar.dart';
import '../widgets/skeleton_event_card.dart';
import '../widgets/freshness_indicator.dart';
import '../widgets/offline_banner.dart';
import '../widgets/stale_data_banner.dart';

/// Shows upcoming Pokemon GO events for the next 7 days, grouped by day.
///
/// Each day section has a date header (e.g. "Mon, Mar 23") followed by
/// event cards. Multi-day events appear under their start date only.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final flaggedIds =
        ref.watch(flaggedIdsProvider).valueOrNull ?? <String>{};
    final selectedTypes = ref.watch(selectedEventTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming'),
      ),
      body: eventsAsync.when(
        loading: () => const SkeletonEventList(),
        error: (error, _) => ErrorState(
          message: 'Failed to load events',
          onRetry: () => ref.invalidate(upcomingEventsProvider),
        ),
        data: (state) {
          var events = state.events;
          if (selectedTypes.isNotEmpty) {
            events = events
                .where((e) => selectedTypes.contains(e.eventType))
                .toList();
          }
          final dayGroups = groupEventsByDay(events);

          return Column(
            children: [
              const OfflineBanner(),
              if (state.shouldShowStaleBanner())
                StaleDataBanner(lastUpdated: state.lastUpdated),
              FreshnessIndicator(lastUpdated: state.lastUpdated),
              EventTypeFilterBar(
                selectedTypes: selectedTypes,
                onChanged: (types) =>
                    ref.read(selectedEventTypesProvider.notifier).state = types,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(upcomingEventsProvider.notifier).refresh(),
                  child: dayGroups.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 200),
                            selectedTypes.isNotEmpty
                                ? const EmptyState(
                                    icon: Icons.filter_list_off,
                                    message:
                                        'No upcoming events match\nthe selected filters.',
                                  )
                                : const EmptyState(
                                    message:
                                        'No upcoming events\nin the next 7 days.',
                                  ),
                          ],
                        )
                      : _UpcomingDaysList(
                          groups: dayGroups,
                          flaggedIds: flaggedIds,
                          onToggleFlag: (eventId) => ref
                              .read(flaggedIdsProvider.notifier)
                              .toggle(eventId),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A flat-index entry in the upcoming list — either a day header or an event.
class _ListItem {
  final String? header;
  final EventDto? event;

  const _ListItem.header(this.header) : event = null;
  const _ListItem.event(this.event) : header = null;

  bool get isHeader => header != null;
}

class _UpcomingDaysList extends StatelessWidget {
  const _UpcomingDaysList({
    required this.groups,
    required this.flaggedIds,
    required this.onToggleFlag,
  });

  final List<DayGroup> groups;
  final Set<String> flaggedIds;
  final void Function(String eventId) onToggleFlag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a flat index of headers + events for ListView.builder.
    final items = <_ListItem>[];
    for (final group in groups) {
      items.add(_ListItem.header(group.header));
      for (final event in group.events) {
        items.add(_ListItem.event(event));
      }
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              item.header!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }
        final event = item.event!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: EventCard(
            event: event,
            isFlagged: flaggedIds.contains(event.id),
            onToggleFlag: () => onToggleFlag(event.id),
          ),
        );
      },
    );
  }
}
