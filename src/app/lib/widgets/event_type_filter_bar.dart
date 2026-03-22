import 'package:flutter/material.dart';

import '../config/event_type_style.dart';
import '../models/event_type.dart';

/// Horizontal scrolling filter chips for event types.
///
/// Shows an "All" chip followed by one chip per [EventType]. Tapping a chip
/// toggles that type in the selection set. When nothing is selected (or "All"
/// is tapped), all events are shown.
class EventTypeFilterBar extends StatelessWidget {
  const EventTypeFilterBar({
    super.key,
    required this.selectedTypes,
    required this.onChanged,
  });

  /// Currently selected event types. Empty means "All".
  final Set<EventType> selectedTypes;

  /// Called when the selection changes.
  final ValueChanged<Set<EventType>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAll = selectedTypes.isEmpty;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isAll,
              label: const Text('All'),
              showCheckmark: false,
              onSelected: (_) => onChanged({}),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                fontWeight: isAll ? FontWeight.w600 : FontWeight.normal,
                color: isAll
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final type in EventType.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _EventTypeChip(
                type: type,
                isSelected: selectedTypes.contains(type),
                onSelected: (selected) {
                  final updated = {...selectedTypes};
                  if (selected) {
                    updated.add(type);
                  } else {
                    updated.remove(type);
                  }
                  onChanged(updated);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EventTypeChip extends StatelessWidget {
  const _EventTypeChip({
    required this.type,
    required this.isSelected,
    required this.onSelected,
  });

  final EventType type;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final style = EventTypeStyle.of(type);

    return FilterChip(
      selected: isSelected,
      label: Text(style.label),
      tooltip: '${isSelected ? 'Remove' : 'Add'} ${style.label} filter',
      avatar: ExcludeSemantics(
        child: Icon(style.icon, size: 16, color: isSelected ? style.color : null),
      ),
      showCheckmark: false,
      onSelected: onSelected,
      selectedColor: style.color.withAlpha(40),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? style.color : null,
        fontSize: 13,
      ),
      side: isSelected ? BorderSide(color: style.color.withAlpha(80)) : null,
    );
  }
}
