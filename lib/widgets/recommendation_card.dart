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
    final iconSize = isLarge ? 84.0 : 60.0;
    return ClayCard(
      padding: EdgeInsets.all(isLarge ? 22 : 18),
      color: isLarge ? KisouTheme.surface : KisouTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RankBadge(rank: recommendation.rank, isLarge: isLarge),
          SizedBox(height: isLarge ? 20 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (recommendation.outer != null)
                ClothingIcon(
                  code: recommendation.outer,
                  type: ClothingIconType.outer,
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
          color: KisouTheme.deepSky,
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
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: KisouTheme.sand,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: KisouTheme.softInk,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          rank == 2 ? AppStrings.warmerOption : AppStrings.lighterOption,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
