class RecommendationItem {
  const RecommendationItem({
    required this.rank,
    required this.top,
    required this.bottom,
    required this.outer,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      rank: json['rank'] as int,
      top: json['top'] as String,
      bottom: json['bottom'] as String,
      outer: json['outer'] as String?,
    );
  }

  final int rank;
  final String top;
  final String bottom;
  final String? outer;
}
