import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/services/ad_reward_service.dart';

void main() {
  test(
    'challenge request carries the exact platform and loaded ad unit',
    () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          },
        ),
      );
      final service = AdRewardService(dio);

      await expectLater(
        service.issueChallenge(
          KisouAdPlatform.android,
          AdConfig.androidSamples.rewardedId,
          idempotencyKey: '11111111-1111-4111-8111-111111111111',
        ),
        throwsA(isA<DioException>()),
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/ads/rewards/challenges');
      expect(captured.data, {
        'platform': 'android',
        'ad_unit_id': AdConfig.androidSamples.rewardedId,
        'idempotency_key': '11111111-1111-4111-8111-111111111111',
      });
    },
  );
}
