class AnalysisResponse {
  const AnalysisResponse({
    required this.tendency,
    required this.totalFeedbacks,
    required this.feedbackCounts,
    required this.history,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['feedback_counts'] as Map<String, dynamic>? ?? {};
    return AnalysisResponse(
      tendency: json['tendency'] as String? ?? 'neutral',
      totalFeedbacks: (json['total_feedbacks'] as num?)?.toInt() ?? 0,
      feedbackCounts: AnalysisFeedbackCounts(
        cold: (rawCounts['cold'] as num?)?.toInt() ?? 0,
        perfect: (rawCounts['perfect'] as num?)?.toInt() ?? 0,
        hot: (rawCounts['hot'] as num?)?.toInt() ?? 0,
      ),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnalysisHistoryItem.fromJson)
          .toList(growable: false),
    );
  }

  final String tendency;
  final int totalFeedbacks;
  final AnalysisFeedbackCounts feedbackCounts;
  final List<AnalysisHistoryItem> history;
}

class AnalysisFeedbackCounts {
  const AnalysisFeedbackCounts({
    required this.cold,
    required this.perfect,
    required this.hot,
  });

  final int cold;
  final int perfect;
  final int hot;
}

class AnalysisHistoryItem {
  const AnalysisHistoryItem({
    required this.date,
    required this.feedbackValue,
    required this.tempHigh,
    required this.tempLow,
    required this.humidity,
  });

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    return AnalysisHistoryItem(
      date: DateTime.parse(json['date'] as String),
      feedbackValue: json['feedback_value'] as String? ?? 'perfect',
      tempHigh: (json['temp_high'] as num?)?.toDouble(),
      tempLow: (json['temp_low'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toInt(),
    );
  }

  final DateTime date;
  final String feedbackValue;
  final double? tempHigh;
  final double? tempLow;
  final int? humidity;
}
