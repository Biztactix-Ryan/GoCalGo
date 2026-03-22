import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Banner shown when event data may be stale (loaded from local cache).
///
/// Uses an amber background when data is older than 1 hour, and a neutral
/// surface colour otherwise.
class StaleDataBanner extends StatelessWidget {
  final DateTime? lastUpdated;

  const StaleDataBanner({super.key, this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String message = 'Showing cached data — you may be offline';
    if (lastUpdated != null) {
      final formatted = DateFormat.jm().format(lastUpdated!.toLocal());
      message = 'Showing cached data from $formatted — you may be offline';
    }

    final isOld = lastUpdated != null &&
        DateTime.now().difference(lastUpdated!) >= const Duration(hours: 1);

    final backgroundColor = isOld
        ? Colors.amber.shade100
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = isOld
        ? Colors.amber.shade900
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
