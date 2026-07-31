import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/feedback.dart';

void main() {
  test('serializes feedback request with snake case fields', () {
    const request = FeedbackRequest(
      feedbackValue: 'cold',
      actualTop: 'SHORT_SLEEVE',
      actualBottom: 'LONG_PANTS',
      actualOuter: null,
    );

    expect(request.toJson(), {
      'feedback_value': 'cold',
      'actual_top': 'SHORT_SLEEVE',
      'actual_bottom': 'LONG_PANTS',
      'actual_outer': null,
    });
  });

  test('serializes recommendation attribution only when supplied', () {
    const request = FeedbackRequest(
      feedbackValue: 'cold',
      actualTop: 'SHORT_SLEEVE',
      actualBottom: 'LONG_PANTS',
      actualOuter: null,
      recommendationContext: 'signed-context',
      appliedRecommendationRank: 1,
    );

    expect(request.toJson(), {
      'feedback_value': 'cold',
      'actual_top': 'SHORT_SLEEVE',
      'actual_bottom': 'LONG_PANTS',
      'actual_outer': null,
      'recommendation_context': 'signed-context',
      'applied_recommendation_rank': 1,
    });
  });

  test('parses today feedback response', () {
    final response = FeedbackTodayResponse.fromJson({
      'exists': true,
      'feedback': {
        'id': 'feedback-id',
        'date': '2026-05-07',
        'feedback_value': 'hot',
        'actual_top': 'THIN_LONG',
        'actual_bottom': 'SKIRT',
        'actual_outer': 'CARDIGAN',
        'applied_recommendation_rank': 1,
        'created_at': '2026-05-07T00:00:00Z',
        'updated_at': '2026-05-07T00:00:00Z',
      },
    });

    expect(response.exists, isTrue);
    expect(response.feedback?.feedbackValue, 'hot');
    expect(response.feedback?.actualOuter, 'CARDIGAN');
    expect(response.feedback?.appliedRecommendationRank, 1);
  });

  test('parses recent feedback and maps legacy forenoon slot', () {
    final response = FeedbackRecentResponse.fromJson({
      'days': [
        {'date': '2026-07-29', 'feedback': null},
        {
          'date': '2026-07-28',
          'feedback': {
            'id': 'feedback-id',
            'date': '2026-07-28',
            'feedback_value': 'perfect',
            'actual_top': 'SHORT_SLEEVE',
            'actual_bottom': 'LONG_PANTS',
            'actual_outer': null,
            'time_slots': ['FORENOON'],
            'created_at': '2026-07-28T00:00:00Z',
            'updated_at': '2026-07-28T00:00:00Z',
          },
        },
      ],
    });

    expect(response.days, hasLength(2));
    expect(response.days.first.feedback, isNull);
    expect(response.days.last.feedback?.timeSlots, ['MORNING']);
    expect(response.days.last.feedback?.appliedRecommendationRank, isNull);
  });

  test('ignores malformed optional applied ranks', () {
    Map<String, dynamic> feedbackJson(Object? rank) => {
      'id': 'feedback-id',
      'date': '2026-07-31',
      'feedback_value': 'perfect',
      'actual_top': 'THIN_LONG',
      'actual_bottom': 'LONG_PANTS',
      'actual_outer': null,
      'applied_recommendation_rank': rank,
      'created_at': '2026-07-31T00:00:00Z',
      'updated_at': '2026-07-31T00:00:00Z',
    };

    expect(
      FeedbackResponse.fromJson(feedbackJson(1.9)).appliedRecommendationRank,
      isNull,
    );
    expect(
      FeedbackResponse.fromJson(feedbackJson(999)).appliedRecommendationRank,
      isNull,
    );
  });
}
