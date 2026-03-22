import 'package:flutter/material.dart';

/// Reusable loading indicator widget shown while fetching data.
///
/// Displays a centered [CircularProgressIndicator] with an optional message.
/// Uses the app's theme colors for visual consistency.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message = 'Loading...',
  });

  /// Optional message displayed below the spinner.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            semanticsLabel: message,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
