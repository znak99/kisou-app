import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedPresentationResult { earned, dismissed }

abstract interface class InlineBannerHandle {
  double get height;

  Widget buildWidget();

  Future<void> dispose();
}

abstract interface class RewardedAdHandle {
  Future<RewardedPresentationResult> show({required String customData});

  Future<void> dispose();
}

abstract interface class AdGateway {
  Future<void> requestConsentInfoUpdate();

  Future<void> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<bool> isPrivacyOptionsRequired();

  Future<void> showPrivacyOptionsForm();

  Future<void> initialize();

  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  });

  Future<RewardedAdHandle> loadRewarded({required String adUnitId});
}

class GoogleMobileAdsGateway implements AdGateway {
  Future<void>? _initializeFuture;

  @override
  Future<void> requestConsentInfoUpdate() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(AdGatewayException(error.message));
        }
      },
    );
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    return _runConsentForm(
      ConsentForm.loadAndShowConsentFormIfRequired,
      operationName: 'required consent form',
    );
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    return _runConsentForm(
      ConsentForm.showPrivacyOptionsForm,
      operationName: 'privacy options form',
    );
  }

  @override
  Future<void> initialize() async {
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    final attempt = _initializeOnce();
    _initializeFuture = attempt;
    try {
      await attempt;
    } catch (_) {
      if (identical(_initializeFuture, attempt)) {
        _initializeFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initializeOnce() async {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
    );
    await MobileAds.instance.initialize();
  }

  @override
  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  }) async {
    if (width <= 0) {
      throw const AdGatewayException('Banner width must be positive.');
    }
    final completer = Completer<InlineBannerHandle>();
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(width),
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          unawaited(
            _completeLoadedBanner(ad: ad, banner: banner, completer: completer),
          );
        },
        onAdFailedToLoad: (ad, error) {
          if (!completer.isCompleted) {
            completer.completeError(AdGatewayException(error.message));
          }
          unawaited(_disposeAdSafely(ad));
        },
      ),
    );
    try {
      await banner.load();
    } catch (error, stackTrace) {
      await _disposeAdSafely(banner);
      Error.throwWithStackTrace(error, stackTrace);
    }
    return completer.future;
  }

  @override
  Future<RewardedAdHandle> loadRewarded({required String adUnitId}) async {
    final completer = Completer<RewardedAdHandle>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(nonPersonalizedAds: true),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (completer.isCompleted) {
              unawaited(_disposeAdSafely(ad));
              return;
            }
            completer.complete(_GoogleRewardedAdHandle(ad));
          },
          onAdFailedToLoad: (error) {
            if (!completer.isCompleted) {
              completer.completeError(AdGatewayException(error.message));
            }
          },
        ),
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    return completer.future;
  }
}

Future<void> _runConsentForm(
  Future<void> Function(OnConsentFormDismissedListener) operation, {
  required String operationName,
}) async {
  var callbackInvoked = false;
  FormError? callbackError;
  try {
    await operation((error) {
      callbackInvoked = true;
      callbackError = error;
    });
  } catch (error) {
    throw AdGatewayException('$operationName failed: $error');
  }
  if (!callbackInvoked) {
    throw AdGatewayException('$operationName completed without a callback.');
  }
  if (callbackError case final error?) {
    throw AdGatewayException(error.message);
  }
}

Future<void> _completeLoadedBanner({
  required Ad ad,
  required BannerAd banner,
  required Completer<InlineBannerHandle> completer,
}) async {
  if (completer.isCompleted) {
    await _disposeAdSafely(ad);
    return;
  }
  try {
    final platformSize = await banner.getPlatformAdSize();
    if (completer.isCompleted) {
      await _disposeAdSafely(ad);
      return;
    }
    if (platformSize == null || platformSize.height <= 0) {
      completer.completeError(
        const AdGatewayException(
          'The loaded banner did not report a platform size.',
        ),
      );
      await _disposeAdSafely(ad);
      return;
    }
    completer.complete(
      _GoogleInlineBannerHandle(banner, platformSize.height.toDouble()),
    );
  } catch (error, stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    await _disposeAdSafely(ad);
  }
}

Future<void> _disposeAdSafely(Ad ad) async {
  try {
    await ad.dispose();
  } catch (_) {
    // The owning operation has already completed. Disposal failures must not
    // strand its caller, and the native SDK cannot be recovered from here.
  }
}

class _GoogleInlineBannerHandle implements InlineBannerHandle {
  _GoogleInlineBannerHandle(this._ad, this.height);

  final BannerAd _ad;

  @override
  final double height;

  @override
  Widget buildWidget() => AdWidget(ad: _ad);

  @override
  Future<void> dispose() => _disposeAdSafely(_ad);
}

class _GoogleRewardedAdHandle implements RewardedAdHandle {
  _GoogleRewardedAdHandle(this._ad);

  final RewardedAd _ad;
  bool _shown = false;

  @override
  Future<RewardedPresentationResult> show({required String customData}) async {
    if (_shown) {
      throw const AdGatewayException('A rewarded ad can only be shown once.');
    }
    _shown = true;
    final completer = Completer<RewardedPresentationResult>();
    var earned = false;
    _ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) {
        if (!completer.isCompleted) {
          completer.complete(
            earned
                ? RewardedPresentationResult.earned
                : RewardedPresentationResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        if (!completer.isCompleted) {
          completer.completeError(AdGatewayException(error.message));
        }
      },
    );
    await _ad.setServerSideOptions(
      ServerSideVerificationOptions(customData: customData),
    );
    try {
      await _ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    return completer.future;
  }

  @override
  Future<void> dispose() => _disposeAdSafely(_ad);
}

class AdGatewayException implements Exception {
  const AdGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}
