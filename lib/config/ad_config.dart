import 'package:flutter/foundation.dart';

import 'api_config.dart';

enum KisouAdPlatform { android, ios }

class AdUnitIds {
  const AdUnitIds({
    required this.appId,
    required this.bannerId,
    required this.rewardedId,
  });

  final String appId;
  final String bannerId;
  final String rewardedId;
}

class AdConfig {
  const AdConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  static const androidSamples = AdUnitIds(
    appId: 'ca-app-pub-3940256099942544~3347511713',
    bannerId: 'ca-app-pub-3940256099942544/9214589741',
    rewardedId: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const iosSamples = AdUnitIds(
    appId: 'ca-app-pub-3940256099942544~1458002511',
    bannerId: 'ca-app-pub-3940256099942544/2435281174',
    rewardedId: 'ca-app-pub-3940256099942544/1712485313',
  );

  static const _androidProduction = AdUnitIds(
    appId: String.fromEnvironment('ADMOB_ANDROID_APP_ID'),
    bannerId: String.fromEnvironment('ADMOB_ANDROID_BANNER_ID'),
    rewardedId: String.fromEnvironment('ADMOB_ANDROID_REWARDED_ID'),
  );
  static const _iosProduction = AdUnitIds(
    appId: String.fromEnvironment('ADMOB_IOS_APP_ID'),
    bannerId: String.fromEnvironment('ADMOB_IOS_BANNER_ID'),
    rewardedId: String.fromEnvironment('ADMOB_IOS_REWARDED_ID'),
  );

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static KisouAdPlatform get platform {
    if (kIsWeb) {
      throw StateError('AdMob is available only on Android and iOS.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => KisouAdPlatform.android,
      TargetPlatform.iOS => KisouAdPlatform.ios,
      _ => throw StateError('AdMob is available only on Android and iOS.'),
    };
  }

  static bool get shouldUseAds =>
      enabled &&
      isSupportedPlatform &&
      !ApiConfig.outlookScreenshotFixtureEnabled;

  static bool get usesOfficialTestAds => ApiConfig.isDevelopment;

  static AdUnitIds idsFor(KisouAdPlatform target) {
    if (ApiConfig.isDevelopment || !enabled) {
      return target == KisouAdPlatform.android ? androidSamples : iosSamples;
    }
    return target == KisouAdPlatform.android
        ? _androidProduction
        : _iosProduction;
  }

  static AdUnitIds get ids => idsFor(platform);

  static void validateRuntime() {
    validateAdConfiguration(
      enabled: enabled,
      supportedPlatform: isSupportedPlatform,
      isDevelopment: ApiConfig.isDevelopment,
      androidIds: _androidProduction,
      iosIds: _iosProduction,
    );
  }
}

void validateAdConfiguration({
  required bool enabled,
  required bool supportedPlatform,
  required bool isDevelopment,
  required AdUnitIds androidIds,
  required AdUnitIds iosIds,
}) {
  if (!enabled) {
    return;
  }
  if (!supportedPlatform) {
    throw StateError('ADS_ENABLED=true is supported only on Android and iOS.');
  }
  if (isDevelopment) {
    return;
  }
  _validateProductionIds('Android', androidIds);
  _validateProductionIds('iOS', iosIds);
}

void _validateProductionIds(String platformName, AdUnitIds ids) {
  if (!_isLiveAppId(ids.appId)) {
    throw StateError(
      '$platformName production AdMob App ID is missing, malformed, or a '
      'Google sample ID.',
    );
  }
  if (!_isLiveAdUnitId(ids.bannerId)) {
    throw StateError(
      '$platformName production banner ID is missing, malformed, or a '
      'Google sample ID.',
    );
  }
  if (!_isLiveAdUnitId(ids.rewardedId)) {
    throw StateError(
      '$platformName production rewarded ID is missing, malformed, or a '
      'Google sample ID.',
    );
  }
}

bool _isLiveAppId(String value) =>
    RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(value) &&
    !value.startsWith('ca-app-pub-3940256099942544');

bool _isLiveAdUnitId(String value) =>
    RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(value) &&
    !value.startsWith('ca-app-pub-3940256099942544');
