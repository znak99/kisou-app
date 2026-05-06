import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback.dart';
import '../services/feedback_service.dart';
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
    final status = await ref.read(feedbackServiceProvider).getTodayFeedback();
    state = AsyncData(status);
  }

  Future<FeedbackResponse> submit(FeedbackRequest request) async {
    final response = await ref
        .read(feedbackServiceProvider)
        .submitFeedback(request);
    state = AsyncData(FeedbackTodayResponse(exists: true, feedback: response));
    return response;
  }
}
