import 'package:flutter/material.dart';

import '../models/buff.dart';
import '../models/buff_category.dart';

/// Maps [BuffCategory] to a display colour used for chip backgrounds.
class BuffCategoryStyle {
  static Color color(BuffCategory category) {
    return switch (category) {
      BuffCategory.multiplier => const Color(0xFFE8F5E9), // green tint
      BuffCategory.duration => const Color(0xFFFFF3E0), // orange tint
      BuffCategory.spawn => const Color(0xFFE3F2FD), // blue tint
      BuffCategory.probability => const Color(0xFFFCE4EC), // pink tint
      BuffCategory.trade => const Color(0xFFEDE7F6), // purple tint
      BuffCategory.weather => const Color(0xFFE0F7FA), // cyan tint
      BuffCategory.other => const Color(0xFFF5F5F5), // grey tint
    };
  }

  static Color foreground(BuffCategory category) {
    return switch (category) {
      BuffCategory.multiplier => const Color(0xFF2E7D32),
      BuffCategory.duration => const Color(0xFFE65100),
      BuffCategory.spawn => const Color(0xFF1565C0),
      BuffCategory.probability => const Color(0xFFC62828),
      BuffCategory.trade => const Color(0xFF6A1B9A),
      BuffCategory.weather => const Color(0xFF00838F),
      BuffCategory.other => const Color(0xFF616161),
    };
  }

  static IconData icon(BuffCategory category) {
    return switch (category) {
      BuffCategory.multiplier => Icons.trending_up,
      BuffCategory.duration => Icons.timer,
      BuffCategory.spawn => Icons.catching_pokemon,
      BuffCategory.probability => Icons.auto_awesome,
      BuffCategory.trade => Icons.swap_horiz,
      BuffCategory.weather => Icons.cloud,
      BuffCategory.other => Icons.star,
    };
  }
}

/// A prominent chip that displays a single active buff/bonus.
///
/// Shows the buff text with a category-specific colour and icon so that
/// active buffs stand out on the event card (AC-4 of US-GCG-7).
class BuffChip extends StatelessWidget {
  const BuffChip({super.key, required this.buff});

  final Buff buff;

  @override
  Widget build(BuildContext context) {
    final bg = BuffCategoryStyle.color(buff.category);
    final fg = BuffCategoryStyle.foreground(buff.category);
    final iconData = BuffCategoryStyle.icon(buff.category);

    return Semantics(
      label: '${buff.category.name} bonus: ${buff.text}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(iconData, size: 16, color: fg),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                buff.text,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a list of [BuffChip]s in a wrapping layout.
///
/// Used on the event card to prominently show all active buffs.
class BuffChipList extends StatelessWidget {
  const BuffChipList({super.key, required this.buffs});

  final List<Buff> buffs;

  @override
  Widget build(BuildContext context) {
    if (buffs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: buffs.map((b) => BuffChip(buff: b)).toList(),
    );
  }
}
