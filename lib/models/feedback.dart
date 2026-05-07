class FeedbackRequest {
  const FeedbackRequest({
    required this.feedbackValue,
    required this.actualTop,
    required this.actualBottom,
    required this.actualOuter,
  });

  final String feedbackValue;
  final String actualTop;
  final String actualBottom;
  final String? actualOuter;

  Map<String, dynamic> toJson() {
    return {
      'feedback_value': feedbackValue,
      'actual_top': actualTop,
      'actual_bottom': actualBottom,
      'actual_outer': actualOuter,
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
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackResponse(
      id: json['id'] as String,
      date: json['date'] as String,
      feedbackValue: json['feedback_value'] as String,
      actualTop: json['actual_top'] as String,
      actualBottom: json['actual_bottom'] as String,
      actualOuter: json['actual_outer'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
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
