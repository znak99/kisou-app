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

  test('parses today feedback response', () {
    final response = FeedbackTodayResponse.fromJson({
      'exists': true,
      'feedback': {
        'id': 'feedback-id',
        'date': '2026-05-07',
        'feedback_value': 'hot',
        'actual_top': 'THIN_LONG',
        'actual_bottom': 'SKIRT',
        'actual_outer': 'JACKET',
        'created_at': '2026-05-07T00:00:00Z',
        'updated_at': '2026-05-07T00:00:00Z',
      },
    });

    expect(response.exists, isTrue);
    expect(response.feedback?.feedbackValue, 'hot');
    expect(response.feedback?.actualOuter, 'JACKET');
  });
}
