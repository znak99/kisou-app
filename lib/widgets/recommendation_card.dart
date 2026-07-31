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
    final largeText = usesLargeText(context);
    final clothingIcons = <Widget>[
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
    ];
    return ClayCard(
      padding: EdgeInsets.all(isLarge ? KisouTheme.gapL : KisouTheme.gapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RankBadge(recommendation: recommendation, isLarge: isLarge),
          SizedBox(height: isLarge ? KisouTheme.gapL : KisouTheme.gapM),
          if (largeText)
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runAlignment: WrapAlignment.start,
              spacing: KisouTheme.gapS,
              runSpacing: KisouTheme.gapL,
              children: clothingIcons,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: clothingIcons,
            ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.recommendation, required this.isLarge});

  final RecommendationItem recommendation;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final direction = recommendation.direction;
    final label = switch (direction) {
      RecommendationDirection.primary => AppStrings.bestRecommendation,
      RecommendationDirection.warmer => AppStrings.warmerOption,
      RecommendationDirection.lighter => AppStrings.lighterOption,
      RecommendationDirection.alternative => AppStrings.sameWarmthAlternative,
    };
    final semanticLabel = AppStrings.recommendationOptionSemantics(
      recommendation.rank,
      label,
    );

    if (direction == RecommendationDirection.primary) {
      return Semantics(
        label: semanticLabel,
        container: true,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KisouTheme.accent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: isLarge ? 11 : 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final (icon, color) = switch (direction) {
      RecommendationDirection.warmer => (Icons.arrow_upward_rounded, c.warm),
      RecommendationDirection.lighter => (Icons.arrow_downward_rounded, c.cool),
      RecommendationDirection.alternative => (
        Icons.swap_horiz_rounded,
        c.accent,
      ),
      RecommendationDirection.primary => (Icons.star_rounded, c.accent),
    };
    return Semantics(
      label: semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.kisou.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
