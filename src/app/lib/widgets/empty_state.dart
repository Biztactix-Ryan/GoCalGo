import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Reusable empty state widget shown when there is no data to display.
///
/// Displays a centered icon and message. Typically used for
/// "no events today" or similar empty-list scenarios.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = 'No events today',
    this.icon,
  });

  /// Message displayed below the icon.
  final String message;

  /// Icon displayed above the message. Defaults to [Icons.event_busy].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon ?? Icons.event_busy,
              size: 48,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
