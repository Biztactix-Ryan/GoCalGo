import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/providers/notification_settings_provider.dart';
import 'package:gocalgo/screens/home_screen.dart';
import 'package:gocalgo/screens/upcoming_screen.dart';
import 'package:gocalgo/screens/event_detail_screen.dart';
import 'package:gocalgo/screens/settings_screen.dart';
import 'package:gocalgo/screens/onboarding_screen.dart';
import 'package:gocalgo/services/notification_settings_store.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_data.dart';

// ---------------------------------------------------------------------------
// Fake notification settings notifier
// ---------------------------------------------------------------------------

class _FakeNotificationSettingsNotifier
    extends NotificationSettingsNotifier {
  @override
  Future<NotificationSettings> build() async =>
      NotificationSettings.defaults();

  @override
  Future<void> update(NotificationSettings settings) async {
    state = AsyncData(settings);
  }
}

/// Verifies that all main screens render without overflow errors on small
/// and large screen sizes (acceptance criterion for US-GCG-14).
///
/// Device sizes tested:
///   - Small phone:  320×480  (iPhone SE 1st gen / low-end Android)
///   - Large phone:  428×926  (iPhone 14 Pro Max)
///   - Small tablet: 768×1024 (iPad Mini)
///   - Large tablet: 1024×1366 (iPad Pro 12.9")

// ---------------------------------------------------------------------------
// Screen size configurations
// ---------------------------------------------------------------------------

class _ScreenSize {
  final String name;
  final double width;
  final double height;

  const _ScreenSize(this.name, this.width, this.height);
}

const _screenSizes = [
  _ScreenSize('small phone (320×480)', 320, 480),
  _ScreenSize('large phone (428×926)', 428, 926),
  _ScreenSize('small tablet (768×1024)', 768, 1024),
  _ScreenSize('large tablet (1024×1366)', 1024, 1366),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets the test view to the given logical size and resets on teardown.
void _setScreenSize(WidgetTester tester, _ScreenSize size) {
  tester.view.physicalSize = Size(size.width, size.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final events = [
    TestData.communityDay(),
    TestData.spotlightHour(),
    TestData.raidHour(),
  ];

  group('HomeScreen renders on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpScreen(
          const HomeScreen(),
          events: events,
          flaggedIds: {'cd-test'},
        );
        await tester.pumpAndSettle();

        // Screen renders without overflow — Flutter framework throws
        // FlutterError for RenderFlex overflow, which would fail the test.
        expect(find.byType(HomeScreen), findsOneWidget);

        // Key UI elements are present
        expect(find.text('GoCalGo'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
      });
    }
  });

  group('UpcomingScreen renders on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpApp(
          const UpcomingScreen(),
          overrides: [
            upcomingEventsProvider.overrideWith(
              () => FakeUpcomingEventsNotifier(events: events),
            ),
            flaggedIdsProvider.overrideWith(
              () => FakeFlaggedIdsNotifier({}),
            ),
            connectivityProvider.overrideWith(
              () => FakeConnectivityNotifier(),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(UpcomingScreen), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
      });
    }
  });

  group('EventDetailScreen renders on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpApp(
          EventDetailScreen(event: TestData.communityDay()),
          overrides: [
            flaggedIdsProvider.overrideWith(
              () => FakeFlaggedIdsNotifier({}),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(EventDetailScreen), findsOneWidget);
        expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      });
    }
  });

  group('SettingsScreen renders on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpApp(
          const SettingsScreen(),
          overrides: [
            notificationSettingsProvider.overrideWith(
              () => _FakeNotificationSettingsNotifier(),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });
    }
  });

  group('OnboardingScreen renders on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpApp(
          OnboardingScreen(onComplete: () {}),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text("Today's Buffs"), findsOneWidget);
      });
    }
  });

  group('HomeScreen empty state on all screen sizes', () {
    for (final size in _screenSizes) {
      testWidgets('renders on ${size.name}', (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpScreen(
          const HomeScreen(),
          events: [],
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('No events today'), findsOneWidget);
      });
    }
  });
}
