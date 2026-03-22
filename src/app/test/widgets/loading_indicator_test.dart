import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/widgets/loading_indicator.dart';
import 'package:gocalgo/config/theme.dart';

void main() {
  Widget buildTestWidget({String? message}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: LoadingIndicator(
          message: message ?? 'Loading...',
        ),
      ),
    );
  }

  group('LoadingIndicator', () {
    testWidgets('shows a CircularProgressIndicator spinner', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows default loading message', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('shows custom loading message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(message: 'Fetching events...'),
      );

      expect(find.text('Fetching events...'), findsOneWidget);
    });

    testWidgets('spinner uses the primary theme color', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      expect(indicator.color, equals(AppTheme.primaryBlue));
    });

    testWidgets('is centered on screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Center), findsWidgets);

      // The LoadingIndicator's root widget is a Center
      final center = tester.widget<Center>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(Center),
        ).first,
      );
      expect(center, isNotNull);
    });
  });
}
