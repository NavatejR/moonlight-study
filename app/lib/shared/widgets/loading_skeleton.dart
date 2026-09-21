import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/colors.dart';

/// Skeleton placeholder for loading states. Shimmers to indicate progress.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? CoffeeColors.mocha : CoffeeColors.latte;
    final highlightColor =
        isDark ? CoffeeColors.cacao : CoffeeColors.crema;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton card for notebook/document lists.
class NotebookCardSkeleton extends StatelessWidget {
  const NotebookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LoadingSkeleton(width: 32, height: 32, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(width: double.infinity, height: 18),
                    SizedBox(height: 6),
                    LoadingSkeleton(width: 120, height: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LoadingSkeleton(width: double.infinity, height: 12),
          SizedBox(height: 4),
          LoadingSkeleton(width: 200, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton for flashcard list items.
class FlashcardSkeleton extends StatelessWidget {
  const FlashcardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: double.infinity, height: 16),
          SizedBox(height: 8),
          LoadingSkeleton(width: 240, height: 14),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 8),
          LoadingSkeleton(width: double.infinity, height: 14),
          SizedBox(height: 6),
          LoadingSkeleton(width: 180, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton for PDF page thumbnails.
class PageThumbnailSkeleton extends StatelessWidget {
  const PageThumbnailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: const Column(
        children: [
          LoadingSkeleton(
            width: 120,
            height: 160,
            borderRadius: 8,
          ),
          SizedBox(height: 4),
          LoadingSkeleton(width: 40, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Generic list skeleton with customizable item count and builder.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    required this.itemBuilder,
    this.itemCount = 3,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: itemBuilder,
    );
  }
}
