import 'package:dio/dio.dart';

import '../config/ad_config.dart';
import '../models/ad_reward.dart';

class AdRewardService {
  const AdRewardService(this._dio);

  final Dio _dio;

  Future<AdRewardChallenge> issueChallenge(
    KisouAdPlatform platform,
    String adUnitId, {
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ads/rewards/challenges',
      data: {
        'platform': platform == KisouAdPlatform.android ? 'android' : 'ios',
        'ad_unit_id': adUnitId,
        'idempotency_key': idempotencyKey,
      },
    );
    return AdRewardChallenge.fromJson(_requiredData(response));
  }

  Future<AdRewardChallengeStatus> getChallenge(String challengeId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/ads/rewards/challenges/$challengeId',
    );
    return AdRewardChallengeStatus.fromJson(_requiredData(response));
  }

  Future<AdRewardChallengeStatus> confirmDevelopmentReward(
    String challengeId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ads/rewards/challenges/$challengeId/development-confirm',
    );
    return AdRewardChallengeStatus.fromJson(_requiredData(response));
  }

  Map<String, dynamic> _requiredData(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const AdRewardServiceException('Reward response is empty.');
    }
    return data;
  }
}

class AdRewardServiceException implements Exception {
  const AdRewardServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
