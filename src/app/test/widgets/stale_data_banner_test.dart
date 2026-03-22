import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/widgets/stale_data_banner.dart';

/// Verifies acceptance criterion for story US-GCG-26:
/// "Last sync timestamp displayed on the main screen"
///
/// Tests that [StaleDataBanner] renders the last sync timestamp so users know
/// how fresh the displayed data is.
void main() {
  Widget buildTestWidget({DateTime? lastUpdated}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StaleDataBanner(lastUpdated: lastUpdated),
      ),
    );
  }

  group('US-GCG-26 — Last sync timestamp displayed on the main screen', () {
    testWidgets('displays formatted timestamp when lastUpdated is provided',
        (tester) async {
      // 2:30 PM UTC — local display depends on timezone but we verify the
      // timestamp text is present in the banner message.
      final timestamp = DateTime.utc(2026, 3, 21, 14, 30);

      await tester.pumpWidget(buildTestWidget(lastUpdated: timestamp));

      // The banner should contain "Showing cached data from" with a time.
      expect(find.textContaining('Showing cached data from'), findsOneWidget);
      // Should NOT show the generic (no-timestamp) message.
      expect(
        find.text('Showing cached data — you may be offline'),
        findsNothing,
      );
    });

    testWidgets('displays generic message when lastUpdated is null',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text('Showing cached data — you may be offline'),
        findsOneWidget,
      );
    });

    testWidgets('shows cloud_off icon indicating offline/stale state',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(lastUpdated: DateTime.utc(2026, 3, 21, 10, 0)),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon, isNotNull);
      expect(icon.size, 16);
    });

    testWidgets('banner spans full width', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(lastUpdated: DateTime.utc(2026, 3, 21, 10, 0)),
      );

      // StaleDataBanner renders a Container with width: double.infinity.
      // Verify the rendered banner fills the available width.
      final bannerBox = tester.renderObject<RenderBox>(
        find.byType(StaleDataBanner),
      );
      final scaffoldBox = tester.renderObject<RenderBox>(
        find.byType(Scaffold),
      );
      expect(bannerBox.size.width, scaffoldBox.size.width);
    });

    testWidgets('message includes "you may be offline" suffix with timestamp',
        (tester) async {
      final timestamp = DateTime.utc(2026, 3, 21, 8, 15);

      await tester.pumpWidget(buildTestWidget(lastUpdated: timestamp));

      expect(
        find.textContaining('you may be offline'),
        findsOneWidget,
      );
    });

    testWidgets('timestamp is formatted in local time (jm pattern)',
        (tester) async {
      // Use a known UTC time. DateFormat.jm() produces e.g. "2:30 PM" in
      // the test environment's locale/timezone. We verify the banner
      // contains "Showing cached data from" followed by time info and the
      // offline suffix.
      final timestamp = DateTime.utc(2026, 3, 21, 14, 30);
      await tester.pumpWidget(buildTestWidget(lastUpdated: timestamp));

      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(StaleDataBanner),
          matching: find.byType(Text),
        ),
      );

      final message = textWidget.data!;
      expect(message, startsWith('Showing cached data from'));
      expect(message, endsWith('— you may be offline'));
      // There should be a time string between the prefix and suffix.
      final timePart = message
          .replaceFirst('Showing cached data from ', '')
          .replaceFirst(' — you may be offline', '');
      expect(timePart.isNotEmpty, isTrue,
          reason: 'A formatted time string should appear between prefix and suffix');
    });
  });
}
