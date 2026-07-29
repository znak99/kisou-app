import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback.dart';
import '../services/feedback_service.dart';
import '../utils/jp_date.dart';
import 'api_provider.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(ref.watch(apiClientProvider));
});

final feedbackProvider =
    AsyncNotifierProvider<FeedbackController, FeedbackTodayResponse>(
      FeedbackController.new,
      retry: (_, _) => null,
    );

class FeedbackController extends AsyncNotifier<FeedbackTodayResponse> {
  @override
  Future<FeedbackTodayResponse> build() {
    return ref.read(feedbackServiceProvider).getTodayFeedback();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(feedbackServiceProvider).getTodayFeedback();
    });
  }

  Future<FeedbackResponse> submit(FeedbackRequest request) async {
    final response = await ref
        .read(feedbackServiceProvider)
        .submitFeedback(request);
    // This provider represents TODAY's feedback status. A back-dated
    // submission must not flip today's button to "done".
    if (response.date == formatIsoDate(jstToday())) {
      state = AsyncData(
        FeedbackTodayResponse(exists: true, feedback: response),
      );
    }
    return response;
  }

  Future<FeedbackRecentResponse> getRecentFeedback() {
    return ref.read(feedbackServiceProvider).getRecentFeedback();
  }
}
