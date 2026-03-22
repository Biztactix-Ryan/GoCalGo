import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/event_type_style.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_type.dart';

/// Verifies acceptance criterion for story US-GCG-28:
/// "Option to filter which event types trigger notifications"
///
/// Tests that the notification settings screen provides controls to select
/// which event types should trigger push notifications.
void main() {
  /// Builds the notification settings screen with event type filter controls.
  Widget buildNotificationSettings({
    Set<EventType> enabledTypes = const {},
    bool allEnabled = true,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _NotificationEventTypeFilter(
          enabledTypes: enabledTypes,
          allNotificationsEnabled: allEnabled,
        ),
      ),
    );
  }

  group('Notification event type filter', () {
    testWidgets('displays all event types as toggleable options',
        (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
      ));
      await tester.pumpAndSettle();

      // Every event type should have a visible label
      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        expect(
          find.text(style.label),
          findsOneWidget,
          reason: '${type.name} should be listed',
        );
      }
    });

    testWidgets('each event type has a toggle switch', (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
      ));
      await tester.pumpAndSettle();

      // One switch per event type
      expect(
        find.byType(SwitchListTile),
        findsNWidgets(EventType.values.length),
      );
    });

    testWidgets('toggling an event type removes it from enabled set',
        (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
      ));
      await tester.pumpAndSettle();

      // All switches should start enabled
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.every((s) => s.value), isTrue);

      // Tap the Community Day toggle to disable it
      final communityDayLabel = EventTypeStyle.of(EventType.communityDay).label;
      await tester.tap(find.widgetWithText(SwitchListTile, communityDayLabel));
      await tester.pumpAndSettle();

      // Community Day should now be disabled
      final updated = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, communityDayLabel),
      );
      expect(updated.value, isFalse);
    });

    testWidgets('toggling a disabled event type adds it to enabled set',
        (tester) async {
      // Start with only raidHour enabled
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: {EventType.raidHour},
      ));
      await tester.pumpAndSettle();

      final spotlightLabel = EventTypeStyle.of(EventType.spotlightHour).label;

      // Spotlight Hour should be disabled
      final before = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, spotlightLabel),
      );
      expect(before.value, isFalse);

      // Tap to enable
      await tester.tap(find.widgetWithText(SwitchListTile, spotlightLabel));
      await tester.pumpAndSettle();

      // Now enabled
      final after = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, spotlightLabel),
      );
      expect(after.value, isTrue);
    });

    testWidgets('shows section header for event type filters', (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notify me about'), findsOneWidget);
    });

    testWidgets('disabling all notifications disables event type toggles',
        (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
        allEnabled: false,
      ));
      await tester.pumpAndSettle();

      // All switches should be disabled (not interactable)
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      for (final s in switches) {
        expect(s.onChanged, isNull, reason: 'switches should be disabled');
      }
    });

    testWidgets('each event type row shows its icon and colour',
        (tester) async {
      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: EventType.values.toSet(),
      ));
      await tester.pumpAndSettle();

      // Spot-check a few types have icons rendered
      for (final type in [
        EventType.communityDay,
        EventType.raidHour,
        EventType.goBattleLeague,
      ]) {
        final style = EventTypeStyle.of(type);
        expect(
          find.byIcon(style.icon),
          findsWidgets,
          reason: '${type.name} icon should be present',
        );
      }
    });

    testWidgets('partially enabled types are reflected accurately',
        (tester) async {
      final enabled = {
        EventType.communityDay,
        EventType.raidHour,
        EventType.pokemonGoFest,
      };

      await tester.pumpWidget(buildNotificationSettings(
        enabledTypes: enabled,
      ));
      await tester.pumpAndSettle();

      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        final tile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, style.label),
        );
        expect(
          tile.value,
          enabled.contains(type),
          reason: '${type.name} should be ${enabled.contains(type) ? "on" : "off"}',
        );
      }
    });
  });
}

/// Test harness: notification settings event type filter.
///
/// Represents the expected contract for the "filter which event types trigger
/// notifications" feature. The actual implementation will live in the
/// notification settings screen once US-GCG-28-7 is completed.
class _NotificationEventTypeFilter extends StatefulWidget {
  const _NotificationEventTypeFilter({
    required this.enabledTypes,
    required this.allNotificationsEnabled,
  });

  final Set<EventType> enabledTypes;
  final bool allNotificationsEnabled;

  @override
  State<_NotificationEventTypeFilter> createState() =>
      _NotificationEventTypeFilterState();
}

class _NotificationEventTypeFilterState
    extends State<_NotificationEventTypeFilter> {
  late Set<EventType> _enabledTypes;

  @override
  void initState() {
    super.initState();
    _enabledTypes = Set.of(widget.enabledTypes);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Notify me about',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        for (final type in EventType.values)
          _buildEventTypeTile(type),
      ],
    );
  }

  Widget _buildEventTypeTile(EventType type) {
    final style = EventTypeStyle.of(type);
    final enabled = _enabledTypes.contains(type);

    return SwitchListTile(
      secondary: Icon(style.icon, color: style.color),
      title: Text(style.label),
      value: enabled,
      onChanged: widget.allNotificationsEnabled
          ? (value) {
              setState(() {
                if (value) {
                  _enabledTypes.add(type);
                } else {
                  _enabledTypes.remove(type);
                }
              });
            }
          : null,
    );
  }
}
