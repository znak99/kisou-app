import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/services/ad_gateway.dart';

void main() {
  test('disabled policy performs no UMP, SDK, or ad call', () async {
    final gateway = _FakeAdGateway();
    final container = _container(gateway, enabled: false);
    addTearDown(container.dispose);

    await container.read(adsProvider.notifier).start();
    await container.read(adsProvider.notifier).start();

    expect(gateway.calls, isEmpty);
    expect(container.read(adsProvider).mayLoadAds, isFalse);
  });

  test('startup performs UMP in order and initializes the SDK once', () async {
    final gateway = _FakeAdGateway(canRequest: true, privacyRequired: true);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await Future.wait([
      container.read(adsProvider.notifier).start(),
      container.read(adsProvider.notifier).start(),
    ]);

    expect(gateway.calls, ['request', 'form', 'can', 'privacy', 'initialize']);
    final state = container.read(adsProvider);
    expect(state.canRequestAds, isTrue);
    expect(state.sdkInitialized, isTrue);
    expect(state.privacyOptionsRequired, isTrue);
  });

  test('eligibility is rechecked even when UMP update fails', () async {
    final gateway = _FakeAdGateway(
      requestError: StateError('UMP unavailable'),
      canRequest: true,
    );
    final container = _container(gateway);
    addTearDown(container.dispose);

    await container.read(adsProvider.notifier).start();

    expect(gateway.calls, ['request', 'can', 'privacy', 'initialize']);
    expect(container.read(adsProvider).mayLoadAds, isTrue);
    expect(container.read(adsProvider).error, isA<StateError>());
  });

  test(
    'resume retry recovers eligibility and SDK initialization failures',
    () async {
      final gateway = _FakeAdGateway(canRequest: false, initializeFailures: 1);
      final container = _container(gateway);
      addTearDown(container.dispose);

      await container.read(adsProvider.notifier).start();
      expect(container.read(adsProvider).sdkInitialized, isFalse);

      gateway.canRequest = true;
      await container.read(adsProvider.notifier).retryInitialization();
      expect(container.read(adsProvider).sdkInitialized, isFalse);
      expect(container.read(adsProvider).canRequestAds, isTrue);

      await container.read(adsProvider.notifier).retryInitialization();
      expect(container.read(adsProvider).sdkInitialized, isTrue);
      expect(gateway.calls.where((call) => call == 'initialize'), hasLength(2));
    },
  );

  test(
    'privacy form is exposed only when required and refreshes eligibility',
    () async {
      final gateway = _FakeAdGateway(canRequest: true, privacyRequired: true);
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adsProvider.notifier).start();

      gateway.privacyRequired = false;
      await container.read(adsProvider.notifier).showPrivacyOptions();

      expect(
        gateway.calls.where((call) => call == 'privacyForm'),
        hasLength(1),
      );
      expect(container.read(adsProvider).privacyOptionsRequired, isFalse);
      expect(gateway.calls.where((call) => call == 'initialize'), hasLength(1));
    },
  );
}

ProviderContainer _container(_FakeAdGateway gateway, {bool enabled = true}) {
  return ProviderContainer(
    overrides: [
      adsRuntimePolicyProvider.overrideWithValue(
        AdsRuntimePolicy(
          enabled: enabled,
          platform: KisouAdPlatform.android,
          ids: AdConfig.androidSamples,
          usesOfficialTestAds: true,
        ),
      ),
      adGatewayProvider.overrideWithValue(gateway),
    ],
  );
}

class _FakeAdGateway implements AdGateway {
  _FakeAdGateway({
    this.requestError,
    this.canRequest = false,
    this.privacyRequired = false,
    this.initializeFailures = 0,
  });

  final List<String> calls = [];
  Object? requestError;
  bool canRequest;
  bool privacyRequired;
  int initializeFailures;

  @override
  Future<bool> canRequestAds() async {
    calls.add('can');
    return canRequest;
  }

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    if (initializeFailures > 0) {
      initializeFailures--;
      throw StateError('temporary SDK failure');
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    calls.add('privacy');
    return privacyRequired;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    calls.add('form');
  }

  @override
  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RewardedAdHandle> loadRewarded({required String adUnitId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestConsentInfoUpdate() async {
    calls.add('request');
    if (requestError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    calls.add('privacyForm');
  }
}
