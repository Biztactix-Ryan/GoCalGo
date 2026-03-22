import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/screens/event_detail_screen.dart';

/// Widget tests for EventDetailScreen — full detail view for a single event.
///
/// Pattern: override flaggedIdsProvider to avoid real persistence, pass an
/// [EventDto] fixture directly to the screen constructor.

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _event = EventDto(
  id: 'evt-detail-1',
  name: 'Community Day Classic: Charmander',
  eventType: EventType.communityDay,
  heading: 'Charmander featured with exclusive move!',
  imageUrl: '',
  linkUrl: 'https://pokemongolive.com',
  start: DateTime(2026, 3, 21, 11, 0),
  end: DateTime(2026, 3, 21, 17, 0),
  isUtcTime: false,
  hasSpawns: true,
  hasResearchTasks: true,
  buffs: const [
    Buff(
      text: '3× Catch XP',
      category: BuffCategory.multiplier,
      multiplier: 3.0,
      resource: 'XP',
    ),
    Buff(
      text: '2-hour Lure Modules',
      category: BuffCategory.duration,
      resource: 'Lure Modules',
    ),
  ],
  featuredPokemon: const [
    Pokemon(
      name: 'Charmander',
      imageUrl: '',
      canBeShiny: true,
      role: PokemonRole.spotlight,
    ),
    Pokemon(
      name: 'Charmeleon',
      imageUrl: '',
      canBeShiny: false,
      role: PokemonRole.spawn,
    ),
  ],
  promoCodes: const ['CHARMDAY2026'],
);

final _minimalEvent = EventDto(
  id: 'evt-minimal',
  name: 'Season of Discovery',
  eventType: EventType.season,
  heading: '',
  imageUrl: '',
  linkUrl: '',
  start: DateTime(2026, 3, 1),
  end: DateTime(2026, 6, 1),
  isUtcTime: false,
  hasSpawns: false,
  hasResearchTasks: false,
  buffs: const [],
  featuredPokemon: const [],
  promoCodes: const [],
);

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

Widget _buildDetailScreen({
  required EventDto event,
  Set<String> flaggedIds = const {},
}) {
  return ProviderScope(
    overrides: [
      flaggedIdsProvider.overrideWith(() => _FakeFlaggedIdsNotifier(flaggedIds)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: EventDetailScreen(event: event),
    ),
  );
}

class _FakeFlaggedIdsNotifier extends FlaggedIdsNotifier {
  _FakeFlaggedIdsNotifier(this._ids);
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventDetailScreen', () {
    testWidgets('displays event name', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(
        find.text('Community Day Classic: Charmander'),
        findsOneWidget,
      );
    });

    testWidgets('displays event heading when different from name',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(
        find.text('Charmander featured with exclusive move!'),
        findsOneWidget,
      );
    });

    testWidgets('hides heading when empty', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _minimalEvent));
      await tester.pumpAndSettle();

      // Only the event name should appear as text in the title area
      expect(find.text('Season of Discovery'), findsOneWidget);
    });

    testWidgets('shows type badge', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(find.text('Community Day'), findsOneWidget);
    });

    testWidgets('displays active bonuses section when buffs exist',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(find.text('Active Bonuses'), findsOneWidget);
      expect(find.text('3× Catch XP'), findsOneWidget);
      expect(find.text('2-hour Lure Modules'), findsOneWidget);
    });

    testWidgets('hides bonuses section when no buffs', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _minimalEvent));
      await tester.pumpAndSettle();

      expect(find.text('Active Bonuses'), findsNothing);
    });

    testWidgets('displays featured Pokemon section', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      // Scroll down to reveal content below the fold
      await tester.dragUntilVisible(
        find.text('Featured Pok\u00e9mon'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      expect(find.text('Featured Pok\u00e9mon'), findsOneWidget);
      expect(find.text('Charmander'), findsOneWidget);
      expect(find.text('Charmeleon'), findsOneWidget);
    });

    testWidgets('hides Pokemon section when none featured', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _minimalEvent));
      await tester.pumpAndSettle();

      expect(find.text('Featured Pok\u00e9mon'), findsNothing);
    });

    testWidgets('shows shiny indicator for shiny-eligible Pokemon',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      // Scroll down to reveal Pokemon tiles
      await tester.dragUntilVisible(
        find.text('Charmander'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      // Shiny indicator uses auto_awesome icon
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    });

    testWidgets('displays special features chips', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      // Scroll down to reveal features section
      await tester.dragUntilVisible(
        find.text('Features'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Special Spawns'), findsOneWidget);
      expect(find.text('Research Tasks'), findsOneWidget);
    });

    testWidgets('hides features section when no spawns or research',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _minimalEvent));
      await tester.pumpAndSettle();

      expect(find.text('Features'), findsNothing);
      expect(find.text('Special Spawns'), findsNothing);
    });

    testWidgets('displays promo codes section', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      // Scroll down to reveal promo codes section
      await tester.dragUntilVisible(
        find.text('Promo Codes'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      expect(find.text('Promo Codes'), findsOneWidget);
      expect(find.text('CHARMDAY2026'), findsOneWidget);
    });

    testWidgets('hides promo codes when none available', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _minimalEvent));
      await tester.pumpAndSettle();

      expect(find.text('Promo Codes'), findsNothing);
    });

    testWidgets('flag button shows unflagged state by default',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('flag button shows flagged state when event is flagged',
        (tester) async {
      await tester.pumpWidget(_buildDetailScreen(
        event: _event,
        flaggedIds: {'evt-detail-1'},
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('uses collapsing SliverAppBar', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(event: _event));
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
      final appBar =
          tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
      expect(appBar.expandedHeight, equals(220));
    });
  });
}
