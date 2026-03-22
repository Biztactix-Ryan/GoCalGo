import 'package:flutter/material.dart';

import 'shimmer.dart';

/// A skeleton placeholder that matches the event card layout.
///
/// Shows shimmer-animated rectangles in place of the image, title, subtitle,
/// time range, and buff chips. Used during initial data fetch and
/// pull-to-refresh to indicate content is loading.
class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final boneColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Semantics(
      label: 'Loading event',
      child: Card(
      child: Shimmer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: boneColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              // Event type badge
              Container(
                height: 20,
                width: 100,
                decoration: BoxDecoration(
                  color: boneColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Container(
                height: 18,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: boneColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              // Subtitle / heading
              Container(
                height: 14,
                width: 200,
                decoration: BoxDecoration(
                  color: boneColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              // Time range row
              Row(
                children: [
                  Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: boneColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: boneColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Buff chips row
              Row(
                children: [
                  _SkeletonChip(color: boneColor, width: 80),
                  const SizedBox(width: 8),
                  _SkeletonChip(color: boneColor, width: 60),
                  const SizedBox(width: 8),
                  _SkeletonChip(color: boneColor, width: 70),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

/// A scrollable list of [SkeletonEventCard]s used as a full-screen
/// loading placeholder. Suitable for both initial load and pull-to-refresh.
class SkeletonEventList extends StatelessWidget {
  const SkeletonEventList({
    super.key,
    this.itemCount = 3,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const SkeletonEventCard(),
    );
  }
}
