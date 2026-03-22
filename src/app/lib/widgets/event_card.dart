import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/event_type_style.dart';
import '../models/event_dto.dart';
import '../services/event_time_display.dart';
import 'buff_chip.dart';
import 'cached_event_image.dart';

/// Displays a single event as a card with type badge, title, time range,
/// and active buff chips.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.isFlagged = false,
    this.onToggleFlag,
  });

  final EventDto event;
  final bool isFlagged;
  final VoidCallback? onToggleFlag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = EventTypeStyle.of(event.eventType);
    final timeRange = EventTimeDisplay.formatTimeRange(event);
    final timeRemaining = _timeRemaining(event);

    return Semantics(
      button: true,
      label: '${event.name}, ${style.label} event. $timeRange${timeRemaining != null ? '. $timeRemaining' : ''}${isFlagged ? '. Flagged' : ''}',
      child: RepaintBoundary(
      child: GestureDetector(
      onTap: () => context.go('/event/${event.id}', extra: event),
      child: Card(
      clipBehavior: Clip.antiAlias,
      shape: isFlagged
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: style.color, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event image
          if (event.imageUrl.isNotEmpty)
            Stack(
              children: [
                CachedEventImage(
                  imageUrl: event.imageUrl,
                  height: 140,
                  semanticLabel: '${event.name} event image',
                  placeholderColor: style.color.withAlpha(30),
                  errorIcon: style.icon,
                  errorIconColor: style.color,
                ),
                if (isFlagged)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.flag, size: 18, color: style.color),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                _TypeBadge(style: style),
                const SizedBox(height: 8),

                // Event name
                Text(
                  event.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Heading / subtitle
                if (event.heading.isNotEmpty &&
                    event.heading != event.name) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.heading,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                // Time range row with flag toggle
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.schedule, size: 16, color: style.color),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(timeRange, style: theme.textTheme.bodySmall),
                    ),
                    if (timeRemaining != null)
                      Text(
                        timeRemaining,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: style.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (onToggleFlag != null) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        button: true,
                        label: isFlagged ? 'Unflag event' : 'Flag event',
                        child: GestureDetector(
                          onTap: onToggleFlag,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isFlagged ? Icons.flag : Icons.flag_outlined,
                              size: 20,
                              color: isFlagged ? style.color : theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Buff chips
                if (event.buffs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  BuffChipList(buffs: event.buffs),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    ),
    );
  }

  static String? _timeRemaining(EventDto event) {
    final end = EventTimeDisplay.localEnd(event);
    if (end == null) return null;

    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return null;

    if (remaining.inDays > 0) {
      return '${remaining.inDays}d left';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h left';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m left';
    }
    return 'Ending soon';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.style});

  final EventTypeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(style.icon, size: 14, color: style.color),
          ),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
