import 'package:flutter/material.dart';

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
    final iconSize = isLarge ? 78.0 : 58.0;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.rank == 1
                  ? AppStrings.bestRecommendation
                  : '${recommendation.rank}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: isLarge ? 16 : 12),
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
      ),
    );
  }
}
