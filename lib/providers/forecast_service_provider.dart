import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/forecast_service.dart';
import 'api_provider.dart';

final forecastServiceProvider = Provider<ForecastService>((ref) {
  return ForecastService(ref.watch(apiClientProvider));
});
