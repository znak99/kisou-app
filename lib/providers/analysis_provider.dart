import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import 'api_provider.dart';

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  return AnalysisService(ref.watch(apiClientProvider));
});

final analysisProvider =
    AsyncNotifierProvider<AnalysisController, AnalysisResponse>(
      AnalysisController.new,
      retry: (_, _) => null,
    );

class AnalysisController extends AsyncNotifier<AnalysisResponse> {
  @override
  Future<AnalysisResponse> build() {
    return ref.read(analysisServiceProvider).getAnalysis();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(analysisServiceProvider).getAnalysis();
    });
  }

  Future<void> retry() async {
    state = const AsyncLoading<AnalysisResponse>();
    state = await AsyncValue.guard(() {
      return ref.read(analysisServiceProvider).getAnalysis();
    });
  }
}
