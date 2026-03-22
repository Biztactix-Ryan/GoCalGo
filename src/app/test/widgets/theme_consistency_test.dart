import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/widgets/loading_indicator.dart';
import 'package:gocalgo/widgets/error_state.dart';

/// Verifies that all state widgets (loading, error, empty) use theme colors
/// and text styles consistently — acceptance criterion US-GCG-27 AC-5.
void main() {
  group('Theme consistency across all state widgets', () {
    group('All state widgets use AppTheme.lightTheme', () {
      testWidgets('LoadingIndicator spinner uses theme primary color',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: LoadingIndicator()),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, equals(AppTheme.primaryBlue));
      });

      testWidgets('ErrorState icon uses theme error color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppTheme.pokemonRed));
      });

      testWidgets('ErrorState with network error uses theme error color',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ErrorState(
                message: 'No internet connection.\nSome features are available offline.',
                icon: Icons.cloud_off,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppTheme.pokemonRed));
      });
    });

    group('All state widgets use bodyMedium text style', () {
      testWidgets('LoadingIndicator message uses bodyMedium', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: LoadingIndicator()),
          ),
        );

        final text = tester.widget<Text>(find.text('Loading...'));
        final bodyMedium = AppTheme.lightTheme.textTheme.bodyMedium;
        expect(text.style?.color, equals(bodyMedium?.color));
      });

      testWidgets('ErrorState message uses bodyMedium', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        final text = tester.widget<Text>(find.text('Something went wrong'));
        final bodyMedium = AppTheme.lightTheme.textTheme.bodyMedium;
        expect(text.style?.color, equals(bodyMedium?.color));
      });
    });

    group('All state widgets are centered', () {
      testWidgets('LoadingIndicator is centered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: LoadingIndicator()),
          ),
        );

        expect(
          find.ancestor(
            of: find.byType(CircularProgressIndicator),
            matching: find.byType(Center),
          ),
          findsWidgets,
        );
      });

      testWidgets('ErrorState is centered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        expect(
          find.ancestor(
            of: find.byType(ErrorState),
            matching: find.byType(Center),
          ),
          findsWidgets,
        );
      });
    });

    group('Consistent icon sizing across states', () {
      testWidgets('ErrorState icon uses size 48', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(48));
      });

      testWidgets('ErrorState network error icon uses same size 48',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ErrorState(icon: Icons.cloud_off),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(48));
      });
    });

    group('Consistent spacing across states', () {
      testWidgets('LoadingIndicator uses SizedBox spacing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: LoadingIndicator()),
          ),
        );

        final sizedBoxes = tester.widgetList<SizedBox>(
          find.descendant(
            of: find.byType(LoadingIndicator),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBoxes.any((sb) => sb.height == 16), isTrue);
      });

      testWidgets('ErrorState uses SizedBox spacing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        final sizedBoxes = tester.widgetList<SizedBox>(
          find.descendant(
            of: find.byType(ErrorState),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBoxes.any((sb) => sb.height == 16), isTrue);
      });
    });

    group('Dark theme consistency', () {
      testWidgets('LoadingIndicator uses dark theme primary color',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: LoadingIndicator()),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        // Primary blue is consistent across both themes
        expect(indicator.color, equals(AppTheme.primaryBlue));
      });

      testWidgets('ErrorState uses dark theme error color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ErrorState()),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppTheme.pokemonRed));
      });
    });
  });
}
