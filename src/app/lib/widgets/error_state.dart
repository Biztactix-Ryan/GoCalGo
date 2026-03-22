import 'package:flutter/material.dart';

/// Reusable error state widget shown when an API call fails.
///
/// Displays a centered error icon, message, and a retry button.
/// Uses the app's theme error color for visual consistency.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Error message displayed below the icon.
  final String message;

  /// Callback invoked when the retry button is pressed.
  final VoidCallback? onRetry;

  /// Icon displayed above the message.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
