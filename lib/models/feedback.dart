class FeedbackRequest {
  const FeedbackRequest({
    required this.feedbackValue,
    required this.actualTop,
    required this.actualBottom,
    required this.actualOuter,
    this.date,
    this.timeSlots,
    this.recommendationContext,
    this.appliedRecommendationRank,
  });

  final String feedbackValue;
  final String actualTop;
  final String actualBottom;
  final String? actualOuter;

  /// Date this feedback applies to (YYYY-MM-DD, JST). Null means today.
  final String? date;

  /// Parts of the day the user was outside (multi-select), or null.
  final List<String>? timeSlots;

  /// Opaque context that binds today's displayed recommendation to the API.
  final String? recommendationContext;

  /// Rank explicitly applied through the recommendation shortcut, or null.
  final int? appliedRecommendationRank;

  Map<String, dynamic> toJson() {
    return {
      'feedback_value': feedbackValue,
      'actual_top': actualTop,
      'actual_bottom': actualBottom,
      'actual_outer': actualOuter,
      if (date != null) 'date': date,
      if (timeSlots != null && timeSlots!.isNotEmpty) 'time_slots': timeSlots,
      if (recommendationContext != null)
        'recommendation_context': recommendationContext,
      if (appliedRecommendationRank != null)
        'applied_recommendation_rank': appliedRecommendationRank,
    };
  }
}

class FeedbackResponse {
  const FeedbackResponse({
    required this.id,
    required this.date,
    required this.feedbackValue,
    required this.actualTop,
    required this.actualBottom,
    required this.actualOuter,
    required this.createdAt,
    required this.updatedAt,
    this.timeSlots,
    this.appliedRecommendationRank,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    final rawTimeSlots = (json['time_slots'] as List<dynamic>?)?.cast<String>();
    return FeedbackResponse(
      id: json['id'] as String,
      date: json['date'] as String,
      feedbackValue: json['feedback_value'] as String,
      actualTop: json['actual_top'] as String,
      actualBottom: json['actual_bottom'] as String,
      actualOuter: json['actual_outer'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      timeSlots: rawTimeSlots
          ?.map((slot) => slot == 'FORENOON' ? 'MORNING' : slot)
          .toSet()
          .toList(growable: false),
      appliedRecommendationRank: _parseAppliedRecommendationRank(
        json['applied_recommendation_rank'],
      ),
    );
  }

  final String id;
  final String date;
  final String feedbackValue;
  final String actualTop;
  final String actualBottom;
  final String? actualOuter;
  final String createdAt;
  final String updatedAt;
  final List<String>? timeSlots;
  final int? appliedRecommendationRank;
}

int? _parseAppliedRecommendationRank(Object? value) {
  if (value is int && value >= 1 && value <= 3) {
    return value;
  }
  return null;
}

class FeedbackTodayResponse {
  const FeedbackTodayResponse({required this.exists, required this.feedback});

  factory FeedbackTodayResponse.fromJson(Map<String, dynamic> json) {
    final feedbackJson = json['feedback'] as Map<String, dynamic>?;
    return FeedbackTodayResponse(
      exists: json['exists'] as bool,
      feedback: feedbackJson == null
          ? null
          : FeedbackResponse.fromJson(feedbackJson),
    );
  }

  const FeedbackTodayResponse.empty() : exists = false, feedback = null;

  final bool exists;
  final FeedbackResponse? feedback;
}

class FeedbackRecentDay {
  const FeedbackRecentDay({required this.date, required this.feedback});

  factory FeedbackRecentDay.fromJson(Map<String, dynamic> json) {
    final feedbackJson = json['feedback'] as Map<String, dynamic>?;
    return FeedbackRecentDay(
      date: DateTime.parse(json['date'] as String),
      feedback: feedbackJson == null
          ? null
          : FeedbackResponse.fromJson(feedbackJson),
    );
  }

  final DateTime date;
  final FeedbackResponse? feedback;
}

class FeedbackRecentResponse {
  const FeedbackRecentResponse({required this.days});

  factory FeedbackRecentResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackRecentResponse(
      days: (json['days'] as List<dynamic>)
          .map((day) => FeedbackRecentDay.fromJson(day as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<FeedbackRecentDay> days;
}
