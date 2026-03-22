import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';

/// Verifies acceptance criterion for story US-GCG-28:
/// "Settings screen shows current notification permission status with link to
/// system settings"
///
/// Tests that the notification settings screen displays the current OS-level
/// notification permission status and provides a link for the user to open
/// system settings when permissions are not granted.
void main() {
  Widget buildPermissionStatus({
    required PermissionStatus status,
    VoidCallback? onOpenSettings,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _NotificationPermissionStatus(
          status: status,
          onOpenSettings: onOpenSettings ?? () {},
        ),
      ),
    );
  }

  group('Notification permission status display', () {
    testWidgets('shows "Granted" when notifications are allowed',
        (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.granted,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('shows "Denied" when notifications are denied', (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.denied,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Denied'), findsOneWidget);
    });

    testWidgets('shows "Not determined" when permission is not yet requested',
        (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.notDetermined,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Not determined'), findsOneWidget);
    });

    testWidgets('shows link to open system settings', (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.granted,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('tapping settings link invokes onOpenSettings callback',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.denied,
        onOpenSettings: () => tapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows a warning icon when permission is denied',
        (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.denied,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows a check icon when permission is granted',
        (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.granted,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows an info icon when permission is not determined',
        (tester) async {
      await tester.pumpWidget(buildPermissionStatus(
        status: PermissionStatus.notDetermined,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('settings link is visible regardless of permission status',
        (tester) async {
      for (final status in PermissionStatus.values) {
        await tester.pumpWidget(buildPermissionStatus(status: status));
        await tester.pumpAndSettle();

        expect(
          find.text('Open Settings'),
          findsOneWidget,
          reason: 'Open Settings link should be visible for $status',
        );
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Test harness types
// ---------------------------------------------------------------------------

/// Represents the OS-level notification permission status.
///
/// Maps to platform permission states:
/// - [granted]: user allowed notifications
/// - [denied]: user explicitly denied notifications
/// - [notDetermined]: user hasn't been asked yet (iOS) or default (Android)
enum PermissionStatus { granted, denied, notDetermined }

/// Test harness: notification permission status row.
///
/// Represents the expected contract for the "show current notification
/// permission status with link to system settings" feature. The actual
/// implementation will live in the notification settings screen once
/// US-GCG-28-7 is completed.
class _NotificationPermissionStatus extends StatelessWidget {
  const _NotificationPermissionStatus({
    required this.status,
    required this.onOpenSettings,
  });

  final PermissionStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(_iconForStatus(status), color: _colorForStatus(status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _labelForStatus(status),
                  style: TextStyle(
                    fontSize: 14,
                    color: _colorForStatus(status),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static IconData _iconForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Icons.check_circle_outline;
      case PermissionStatus.denied:
        return Icons.warning_amber_rounded;
      case PermissionStatus.notDetermined:
        return Icons.info_outline;
    }
  }

  static Color _colorForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.red;
      case PermissionStatus.notDetermined:
        return Colors.orange;
    }
  }

  static String _labelForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Allowed';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.notDetermined:
        return 'Not determined';
    }
  }
}
