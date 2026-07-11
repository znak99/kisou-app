import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/recommendation.dart';
import 'clothing_icon.dart';

enum RecommendationCardSize { large, small }

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.size = RecommendationCardSize.small,
  });

  final RecommendationItem recommendation;
  final RecommendationCardSize size;

  @override
  Widget build(BuildContext context) {
    final isLarge = size == RecommendationCardSize.large;
    final iconSize = isLarge ? 84.0 : 40.0;
    return ClayCard(
      padding: EdgeInsets.all(isLarge ? KisouTheme.gapL : KisouTheme.gapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RankBadge(rank: recommendation.rank, isLarge: isLarge),
          SizedBox(height: isLarge ? KisouTheme.gapL : KisouTheme.gapM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ordering is a hard requirement: outer → top → bottom.
              // When there is no outer, skip it (start with top).
              if (recommendation.outer != null)
                ClothingIcon(
                  code: recommendation.outer,
                  type: ClothingIconType.outer,
                  size: iconSize,
                ),
              ClothingIcon(
                code: recommendation.top,
                type: ClothingIconType.top,
                size: iconSize,
              ),
              ClothingIcon(
                code: recommendation.bottom,
                type: ClothingIconType.bottom,
                size: iconSize,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.isLarge});

  final int rank;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    if (rank == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: KisouTheme.accent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              AppStrings.bestRecommendation,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontSize: isLarge ? 16 : 15,
              ),
            ),
          ],
        ),
      );
    }
    // Ranks 2 & 3: no number — just the "warmer / lighter" label.
    final isWarmer = rank == 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isWarmer ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 15,
          color: isWarmer ? KisouTheme.warm : KisouTheme.cool,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            isWarmer ? AppStrings.warmerOption : AppStrings.lighterOption,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.kisou.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
