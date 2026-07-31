enum RecommendationDirection {
  primary('primary'),
  warmer('warmer'),
  lighter('lighter'),
  alternative('alternative');

  const RecommendationDirection(this.apiCode);

  final String apiCode;

  static RecommendationDirection? fromApiCode(Object? value) {
    for (final direction in values) {
      if (direction.apiCode == value) {
        return direction;
      }
    }
    return null;
  }

  static RecommendationDirection fallbackForRank(int rank) {
    return switch (rank) {
      1 => RecommendationDirection.primary,
      2 => RecommendationDirection.warmer,
      3 => RecommendationDirection.lighter,
      _ => throw const FormatException('Invalid recommendation rank'),
    };
  }

  bool isAllowedForRank(int rank) {
    return switch (rank) {
      1 => this == RecommendationDirection.primary,
      2 =>
        this == RecommendationDirection.warmer ||
            this == RecommendationDirection.alternative,
      3 =>
        this == RecommendationDirection.lighter ||
            this == RecommendationDirection.alternative,
      _ => false,
    };
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.rank,
    required this.direction,
    required this.top,
    required this.bottom,
    required this.outer,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    final rawRank = json['rank'];
    if (rawRank is! int || rawRank < 1 || rawRank > 3) {
      throw const FormatException('Invalid recommendation rank');
    }
    final rawDirection = json['direction'];
    final direction = rawDirection == null
        ? RecommendationDirection.fallbackForRank(rawRank)
        : RecommendationDirection.fromApiCode(rawDirection);
    if (direction == null || !direction.isAllowedForRank(rawRank)) {
      throw const FormatException('Invalid recommendation direction');
    }
    return RecommendationItem(
      rank: rawRank,
      direction: direction,
      top: json['top'] as String,
      bottom: json['bottom'] as String,
      outer: json['outer'] as String?,
    );
  }

  final int rank;
  final RecommendationDirection direction;
  final String top;
  final String bottom;
  final String? outer;
}
