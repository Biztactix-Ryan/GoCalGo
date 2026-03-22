import 'dart:async';

import 'package:flutter/material.dart';

/// Displays a relative timestamp like "Updated 5 minutes ago".
///
/// Ticks every 60 seconds so the label stays current. When [lastUpdated] is
/// null no widget is rendered.
class FreshnessIndicator extends StatefulWidget {
  final DateTime? lastUpdated;

  const FreshnessIndicator({super.key, this.lastUpdated});

  @override
  State<FreshnessIndicator> createState() => _FreshnessIndicatorState();
}

class _FreshnessIndicatorState extends State<FreshnessIndicator> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lastUpdated == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final age = DateTime.now().difference(widget.lastUpdated!);
    final label = _formatAge(age);
    final isStaleByAge = age >= const Duration(hours: 1);

    return Semantics(
      label: '$label${isStaleByAge ? '. Data may be stale.' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.sync,
                size: 14,
                color: isStaleByAge
                    ? Colors.amber.shade700
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            ExcludeSemantics(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isStaleByAge
                      ? Colors.amber.shade700
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAge(Duration age) {
    if (age.inMinutes < 1) return 'Updated just now';
    if (age.inMinutes == 1) return 'Updated 1 minute ago';
    if (age.inMinutes < 60) return 'Updated ${age.inMinutes} minutes ago';
    if (age.inHours == 1) return 'Updated 1 hour ago';
    if (age.inHours < 24) return 'Updated ${age.inHours} hours ago';
    return 'Updated ${age.inDays} days ago';
  }
}
