class AnalysisResponse {
  const AnalysisResponse({
    required this.offsetValue,
    required this.tendency,
    required this.totalFeedbacks,
    required this.feedbackCounts,
    required this.history,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
      offsetValue: (json['offset_value'] as num?)?.toDouble() ?? 0,
      tendency: json['tendency'] as String? ?? 'neutral',
      totalFeedbacks: json['total_feedbacks'] as int? ?? 0,
      feedbackCounts: FeedbackCounts.fromJson(
        json['feedback_counts'] as Map<String, dynamic>? ?? const {},
      ),
      history: (json['history'] as List<dynamic>? ?? const [])
          .map((item) {
            return AnalysisHistoryItem.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
    );
  }

  final double offsetValue;
  final String tendency;
  final int totalFeedbacks;
  final FeedbackCounts feedbackCounts;
  final List<AnalysisHistoryItem> history;
}

class FeedbackCounts {
  const FeedbackCounts({
    required this.cold,
    required this.perfect,
    required this.hot,
  });

  factory FeedbackCounts.fromJson(Map<String, dynamic> json) {
    return FeedbackCounts(
      cold: json['cold'] as int? ?? 0,
      perfect: json['perfect'] as int? ?? 0,
      hot: json['hot'] as int? ?? 0,
    );
  }

  final int cold;
  final int perfect;
  final int hot;

  int get total => cold + perfect + hot;
}

class AnalysisHistoryItem {
  const AnalysisHistoryItem({
    required this.date,
    required this.feedbackValue,
    required this.tempHigh,
    required this.tempLow,
    required this.humidity,
    required this.offsetAtTime,
  });

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    return AnalysisHistoryItem(
      date: json['date'] as String,
      feedbackValue: json['feedback_value'] as String,
      tempHigh: (json['temp_high'] as num?)?.toDouble(),
      tempLow: (json['temp_low'] as num?)?.toDouble(),
      humidity: json['humidity'] as int?,
      offsetAtTime: (json['offset_at_time'] as num?)?.toDouble() ?? 0,
    );
  }

  final String date;
  final String feedbackValue;
  final double? tempHigh;
  final double? tempLow;
  final int? humidity;
  final double offsetAtTime;
}
