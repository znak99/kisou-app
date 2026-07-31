import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/ad_config.dart';
import '../services/ad_gateway.dart';

class AdsRuntimePolicy {
  const AdsRuntimePolicy({
    required this.enabled,
    required this.platform,
    required this.ids,
    required this.usesOfficialTestAds,
  });

  final bool enabled;
  final KisouAdPlatform platform;
  final AdUnitIds ids;
  final bool usesOfficialTestAds;
}

final adsRuntimePolicyProvider = Provider<AdsRuntimePolicy>((ref) {
  final platform = AdConfig.isSupportedPlatform
      ? AdConfig.platform
      : KisouAdPlatform.android;
  return AdsRuntimePolicy(
    enabled: AdConfig.shouldUseAds,
    platform: platform,
    ids: AdConfig.idsFor(platform),
    usesOfficialTestAds: AdConfig.usesOfficialTestAds,
  );
});

final adGatewayProvider = Provider<AdGateway>((ref) {
  return GoogleMobileAdsGateway();
});

class AdsState {
  const AdsState({
    required this.enabled,
    required this.consentInProgress,
    required this.canRequestAds,
    required this.sdkInitialized,
    required this.privacyOptionsRequired,
    required this.generation,
    this.error,
  });

  factory AdsState.initial({required bool enabled}) {
    return AdsState(
      enabled: enabled,
      consentInProgress: false,
      canRequestAds: false,
      sdkInitialized: false,
      privacyOptionsRequired: false,
      generation: 0,
    );
  }

  final bool enabled;
  final bool consentInProgress;
  final bool canRequestAds;
  final bool sdkInitialized;
  final bool privacyOptionsRequired;
  final int generation;
  final Object? error;

  bool get mayLoadAds =>
      enabled && !consentInProgress && canRequestAds && sdkInitialized;
}

final adsProvider = NotifierProvider<AdsController, AdsState>(
  AdsController.new,
);

class AdsController extends Notifier<AdsState> {
  Future<void>? _startFuture;
  Future<void>? _privacyFuture;
  Future<void>? _retryFuture;
  bool _started = false;

  @override
  AdsState build() {
    return AdsState.initial(
      enabled: ref.read(adsRuntimePolicyProvider).enabled,
    );
  }

  Future<void> start() {
    if (_started) {
      return _startFuture ?? Future<void>.value();
    }
    _started = true;
    return _startFuture = _start();
  }

  Future<void> _start() async {
    final policy = ref.read(adsRuntimePolicyProvider);
    if (!policy.enabled) {
      return;
    }
    state = AdsState(
      enabled: true,
      consentInProgress: true,
      canRequestAds: false,
      sdkInitialized: false,
      privacyOptionsRequired: false,
      generation: state.generation + 1,
    );
    final gateway = ref.read(adGatewayProvider);
    Object? consentError;
    try {
      await gateway.requestConsentInfoUpdate();
      await gateway.loadAndShowConsentFormIfRequired();
    } catch (error) {
      consentError = error;
    }
    await _readEligibilityAndInitialize(
      gateway,
      priorError: consentError,
      incrementGeneration: true,
    );
  }

  Future<void> showPrivacyOptions() {
    if (!state.enabled || !state.privacyOptionsRequired) {
      return Future<void>.value();
    }
    return _privacyFuture ??= _showPrivacyOptions().whenComplete(() {
      _privacyFuture = null;
    });
  }

  Future<void> retryInitialization() {
    if (!state.enabled || state.consentInProgress || state.sdkInitialized) {
      return Future<void>.value();
    }
    return _retryFuture ??= _retryInitialization().whenComplete(() {
      _retryFuture = null;
    });
  }

  Future<void> _retryInitialization() {
    return _readEligibilityAndInitialize(
      ref.read(adGatewayProvider),
      priorError: null,
      incrementGeneration: true,
    );
  }

  Future<void> _showPrivacyOptions() async {
    final gateway = ref.read(adGatewayProvider);
    state = AdsState(
      enabled: state.enabled,
      consentInProgress: true,
      canRequestAds: state.canRequestAds,
      sdkInitialized: state.sdkInitialized,
      privacyOptionsRequired: state.privacyOptionsRequired,
      generation: state.generation + 1,
    );
    Object? formError;
    try {
      await gateway.showPrivacyOptionsForm();
    } catch (error) {
      formError = error;
    }
    await _readEligibilityAndInitialize(
      gateway,
      priorError: formError,
      incrementGeneration: true,
    );
  }

  Future<void> _readEligibilityAndInitialize(
    AdGateway gateway, {
    required Object? priorError,
    required bool incrementGeneration,
  }) async {
    var canRequest = false;
    var privacyRequired = false;
    var initialized = state.sdkInitialized;
    Object? error = priorError;
    try {
      canRequest = await gateway.canRequestAds();
    } catch (eligibilityError) {
      error ??= eligibilityError;
    }
    try {
      privacyRequired = await gateway.isPrivacyOptionsRequired();
    } catch (privacyError) {
      error ??= privacyError;
    }
    if (canRequest && !initialized) {
      try {
        await gateway.initialize();
        initialized = true;
      } catch (initializationError) {
        error ??= initializationError;
      }
    }
    state = AdsState(
      enabled: true,
      consentInProgress: false,
      canRequestAds: canRequest,
      sdkInitialized: initialized,
      privacyOptionsRequired: privacyRequired,
      generation: state.generation + (incrementGeneration ? 1 : 0),
      error: error,
    );
  }
}
