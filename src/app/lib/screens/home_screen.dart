import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/events_provider.dart';
import '../providers/filter_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/event_card.dart';
import '../widgets/event_type_filter_bar.dart';
import '../widgets/skeleton_event_card.dart';
import '../widgets/freshness_indicator.dart';
import '../widgets/offline_banner.dart';
import '../widgets/stale_data_banner.dart';

/// The hero screen of the app — shows today's active Pokemon GO events.
///
/// Uses an offline-first loading strategy: cached data is shown immediately,
/// then fresh data is fetched from the API in the background. A banner
/// indicates when displayed data may be stale.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showFlaggedOnly = false;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(activeEventsProvider);
    final flaggedIds =
        ref.watch(flaggedIdsProvider).valueOrNull ?? <String>{};
    final selectedTypes = ref.watch(selectedEventTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GoCalGo'),
        actions: [
          IconButton(
            icon: Icon(
              _showFlaggedOnly ? Icons.flag : Icons.flag_outlined,
              color: _showFlaggedOnly
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip:
                _showFlaggedOnly ? 'Show all events' : 'Show flagged only',
            onPressed: () =>
                setState(() => _showFlaggedOnly = !_showFlaggedOnly),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const SkeletonEventList(),
        error: (error, _) => ErrorState(
          message: 'Failed to load events',
          onRetry: () => ref.invalidate(activeEventsProvider),
        ),
        data: (state) {
          var events = state.events;
          if (_showFlaggedOnly || selectedTypes.isNotEmpty) {
            events = events.where((e) {
              if (_showFlaggedOnly && !flaggedIds.contains(e.id)) return false;
              if (selectedTypes.isNotEmpty && !selectedTypes.contains(e.eventType)) return false;
              return true;
            }).toList();
          }

          final hasActiveFilters =
              _showFlaggedOnly || selectedTypes.isNotEmpty;

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
                      ref.read(activeEventsProvider.notifier).refresh(),
                  child: events.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 200),
                            hasActiveFilters
                                ? const EmptyState(
                                    icon: Icons.filter_list_off,
                                    message:
                                        'No events match the\nselected filters.',
                                  )
                                : const EmptyState(),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final event = events[index];
                            return EventCard(
                              event: event,
                              isFlagged: flaggedIds.contains(event.id),
                              onToggleFlag: () => ref
                                  .read(flaggedIdsProvider.notifier)
                                  .toggle(event.id),
                            );
                          },
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
