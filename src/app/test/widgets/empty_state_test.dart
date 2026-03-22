import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/widgets/empty_state.dart';
import 'package:gocalgo/config/theme.dart';

void main() {
  Widget buildTestWidget({String? message, IconData? icon}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: EmptyState(
          message: message ?? 'No events today',
          icon: icon,
        ),
      ),
    );
  }

  group('EmptyState', () {
    testWidgets('shows default empty state message', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No events today'), findsOneWidget);
    });

    testWidgets('shows custom empty state message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(message: 'No upcoming raids'),
      );

      expect(find.text('No upcoming raids'), findsOneWidget);
    });

    testWidgets('shows an icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('supports custom icon', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(icon: Icons.search_off),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.search_off));
    });

    testWidgets('icon uses secondary text color from theme', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(AppTheme.textSecondary));
    });

    testWidgets('is centered on screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Center), findsWidgets);

      final center = tester.widget<Center>(
        find.ancestor(
          of: find.byType(EmptyState),
          matching: find.byType(Center),
        ).first,
      );
      expect(center, isNotNull);
    });
  });
}
