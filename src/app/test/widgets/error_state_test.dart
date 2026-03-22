import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/widgets/error_state.dart';
import 'package:gocalgo/config/theme.dart';

void main() {
  bool retryPressed = false;

  Widget buildTestWidget({
    String? message,
    IconData? icon,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ErrorState(
          message: message ?? 'Something went wrong',
          icon: icon ?? Icons.error_outline,
          onRetry: onRetry,
        ),
      ),
    );
  }

  setUp(() {
    retryPressed = false;
  });

  group('ErrorState', () {
    testWidgets('shows default error message', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows custom error message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(message: 'Failed to load events'),
      );

      expect(find.text('Failed to load events'), findsOneWidget);
    });

    testWidgets('shows an error icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('icon uses error color from theme', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(AppTheme.pokemonRed));
    });

    testWidgets('supports custom icon', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(icon: Icons.cloud_off),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.cloud_off));
    });

    testWidgets('shows retry button when onRetry is provided',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onRetry: () {}),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('retry button has refresh icon', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onRetry: () {}),
      );

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('does not show retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('retry button calls onRetry callback when tapped',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onRetry: () => retryPressed = true),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    group('network error with offline mode explanation', () {
      testWidgets('shows network error message for offline state',
          (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            message:
                'No internet connection.\nSome features are available offline.',
            icon: Icons.cloud_off,
          ),
        );

        expect(find.text('No internet connection.\nSome features are available offline.'),
            findsOneWidget);
      });

      testWidgets('uses cloud_off icon for network errors', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            message: 'No internet connection.\nSome features are available offline.',
            icon: Icons.cloud_off,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon).first);
        expect(icon.icon, equals(Icons.cloud_off));
      });

      testWidgets('network error icon uses error color from theme',
          (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            message: 'No internet connection.\nSome features are available offline.',
            icon: Icons.cloud_off,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon).first);
        expect(icon.color, equals(AppTheme.pokemonRed));
      });

      testWidgets('network error shows retry button', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            message: 'No internet connection.\nSome features are available offline.',
            icon: Icons.cloud_off,
            onRetry: () => retryPressed = true,
          ),
        );

        expect(find.text('Retry'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retryPressed, isTrue);
      });
    });

    testWidgets('is centered on screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Center), findsWidgets);

      final center = tester.widget<Center>(
        find.ancestor(
          of: find.byType(ErrorState),
          matching: find.byType(Center),
        ).first,
      );
      expect(center, isNotNull);
    });
  });
}
