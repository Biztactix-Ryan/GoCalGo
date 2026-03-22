import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/event_type_style.dart';
import '../models/buff.dart';
import '../models/event_dto.dart';
import '../models/pokemon.dart';
import '../providers/events_provider.dart';
import '../services/event_time_display.dart';
import '../widgets/buff_chip.dart';
import '../widgets/cached_event_image.dart';

/// Full detail view for a single event, showing description, all buffs/bonuses,
/// start/end times in local timezone, and a flag toggle.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.event});

  final EventDto event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = EventTypeStyle.of(event.eventType);
    final flaggedIds =
        ref.watch(flaggedIdsProvider).valueOrNull ?? <String>{};
    final isFlagged = flaggedIds.contains(event.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsing app bar with event image
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: style.color,
            flexibleSpace: FlexibleSpaceBar(
              background: event.imageUrl.isNotEmpty
                  ? CachedEventImage(
                      imageUrl: event.imageUrl,
                      height: 220,
                      semanticLabel: '${event.name} event image',
                      placeholderColor: style.color.withAlpha(60),
                      errorIcon: style.icon,
                      errorIconColor: Colors.white,
                    )
                  : Container(
                      color: style.color.withAlpha(60),
                      child: Icon(style.icon, size: 64, color: Colors.white),
                    ),
            ),
            actions: [
              // Flag toggle button
              IconButton(
                icon: Icon(isFlagged ? Icons.flag : Icons.flag_outlined),
                tooltip: isFlagged ? 'Unflag event' : 'Flag event',
                onPressed: () => ref
                    .read(flaggedIdsProvider.notifier)
                    .toggle(event.id),
              ),
            ],
          ),

          // Content body
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Type badge
                _TypeBadge(style: style),
                const SizedBox(height: 12),

                // Event name
                Text(
                  event.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Heading / subtitle
                if (event.heading.isNotEmpty &&
                    event.heading != event.name) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.heading,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Time section
                _TimeSection(event: event, style: style),

                const SizedBox(height: 16),

                // Buffs / Bonuses
                if (event.buffs.isNotEmpty) ...[
                  _SectionHeader(title: 'Active Bonuses', icon: Icons.auto_awesome),
                  const SizedBox(height: 8),
                  ...event.buffs.map((buff) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BuffDetailTile(buff: buff),
                      )),
                  const SizedBox(height: 16),
                ],

                // Featured Pokemon
                if (event.featuredPokemon.isNotEmpty) ...[
                  _SectionHeader(title: 'Featured Pokémon', icon: Icons.catching_pokemon),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: event.featuredPokemon
                        .map((p) => _PokemonTile(pokemon: p))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Extra info chips
                if (event.hasSpawns || event.hasResearchTasks) ...[
                  _SectionHeader(title: 'Features', icon: Icons.info_outline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (event.hasSpawns)
                        const _InfoChip(
                          icon: Icons.catching_pokemon,
                          label: 'Special Spawns',
                        ),
                      if (event.hasResearchTasks)
                        const _InfoChip(
                          icon: Icons.science,
                          label: 'Research Tasks',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Promo codes
                if (event.promoCodes.isNotEmpty) ...[
                  _SectionHeader(title: 'Promo Codes', icon: Icons.card_giftcard),
                  const SizedBox(height: 8),
                  ...event.promoCodes.map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PromoCodeTile(code: code),
                      )),
                  const SizedBox(height: 16),
                ],

                // Bottom padding
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.style});
  final EventTypeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(style.icon, size: 16, color: style.color),
          ),
          const SizedBox(width: 6),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({required this.event, required this.style});
  final EventDto event;
  final EventTypeStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = EventTimeDisplay.localStart(event);
    final end = EventTimeDisplay.localEnd(event);
    final timeRange = EventTimeDisplay.formatTimeRange(event);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: style.color),
                const SizedBox(width: 10),
                Text(
                  timeRange,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (start != null || end != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (start != null)
                    _DateLabel(
                      label: 'Starts',
                      date: EventTimeDisplay.formatDate(event),
                    ),
                  if (start != null && end != null) const Spacer(),
                  if (end != null)
                    _DateLabel(
                      label: 'Ends',
                      date: _formatEndDate(end),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatEndDate(DateTime end) {
    final start = EventTimeDisplay.localStart(event);
    if (start != null &&
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return EventTimeDisplay.formatDate(event);
    }
    // Different day — show the end date.
    return '${end.month}/${end.day}';
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.label, required this.date});
  final String label;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(date, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BuffDetailTile extends StatelessWidget {
  const _BuffDetailTile({required this.buff});
  final Buff buff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = BuffCategoryStyle.color(buff.category);
    final fg = BuffCategoryStyle.foreground(buff.category);
    final iconData = BuffCategoryStyle.icon(buff.category);

    return Semantics(
      label: '${buff.category.name} bonus: ${buff.text}'
          '${buff.multiplier != null ? ', ${buff.multiplier}x${buff.resource != null ? ' ${buff.resource}' : ''}' : ''}'
          '${buff.disclaimer != null ? '. ${buff.disclaimer}' : ''}',
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(iconData, size: 20, color: fg)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buff.text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (buff.multiplier != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${buff.multiplier}x${buff.resource != null ? ' ${buff.resource}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
                if (buff.disclaimer != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    buff.disclaimer!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: fg.withAlpha(180),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PokemonTile extends StatelessWidget {
  const _PokemonTile({required this.pokemon});
  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${pokemon.name}${pokemon.canBeShiny ? ', can be shiny' : ''}',
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: pokemon.imageUrl.isNotEmpty
                      ? NetworkImage(pokemon.imageUrl)
                      : null,
                  child: pokemon.imageUrl.isEmpty
                      ? Icon(Icons.catching_pokemon, size: 28,
                          semanticLabel: pokemon.name)
                      : null,
                ),
                if (pokemon.canBeShiny)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.white,
                        semanticLabel: 'Shiny available',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              pokemon.name,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: ExcludeSemantics(child: Icon(icon, size: 18)),
      label: Text(label, style: theme.textTheme.bodySmall),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PromoCodeTile extends StatelessWidget {
  const _PromoCodeTile({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.content_copy, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            code,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
