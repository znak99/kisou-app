import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/models/ad_reward.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/providers/ad_reward_provider.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/services/ad_gateway.dart';
import 'package:kisou_app/services/ad_reward_service.dart';

void main() {
  test(
    'loads first, issues with the same unit, sets SSV, then confirms dev',
    () async {
      final events = <String>[];
      final handle = _FakeRewardedHandle(events);
      final gateway = _FakeRewardGateway(events, handle);
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final setup = await _setup(gateway, service, development: true);
      addTearDown(setup.container.dispose);

      await setup.container.read(adRewardProvider.notifier).earnCredit();

      expect(events, [
        'load:${AdConfig.androidSamples.rewardedId}',
        'issue:${AdConfig.androidSamples.rewardedId}',
        'show:${_challengeText()}',
        'dispose',
        'confirm',
      ]);
      expect(handle.showCalls, 1);
      expect(setup.quotaController.refreshCalls, 1);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
    },
  );

  test('ad load failure never requests a server challenge', () async {
    final events = <String>[];
    final gateway = _FakeRewardGateway(events, StateError('no fill'));
    final service = _FakeAdRewardService(events);
    final setup = await _setup(gateway, service);
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(events, ['load:${AdConfig.androidSamples.rewardedId}']);
    expect(service.issueCalls, 0);
    expect(
      setup.container.read(adRewardProvider).phase,
      RewardFlowPhase.failed,
    );
  });

  test(
    'native ad disposal failure does not replace a credited result',
    () async {
      final events = <String>[];
      final gateway = _FakeRewardGateway(
        events,
        _FakeRewardedHandle(
          events,
          disposeError: StateError('native disposal failed'),
        ),
      );
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final setup = await _setup(gateway, service, development: true);
      addTearDown(setup.container.dispose);

      await expectLater(
        setup.container.read(adRewardProvider.notifier).earnCredit(),
        completes,
      );

      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
    },
  );

  test('rapid duplicate tap starts one ad load and one challenge', () async {
    final events = <String>[];
    final load = Completer<RewardedAdHandle>();
    final gateway = _FakeRewardGateway(events, load.future);
    final service = _FakeAdRewardService(events)
      ..issueResult = _challenge()
      ..confirmResult = _status(AdRewardChallengeState.credited);
    final setup = await _setup(gateway, service, development: true);
    addTearDown(setup.container.dispose);
    final controller = setup.container.read(adRewardProvider.notifier);

    final first = controller.earnCredit();
    await Future<void>.delayed(Duration.zero);
    await controller.earnCredit();
    expect(gateway.loadCalls, 1);

    load.complete(_FakeRewardedHandle(events));
    await first;
    expect(service.issueCalls, 1);
  });

  test(
    'consent change during ad load disposes it without a challenge',
    () async {
      final events = <String>[];
      final load = Completer<RewardedAdHandle>();
      final handle = _FakeRewardedHandle(events);
      final gateway = _FakeRewardGateway(events, load.future);
      final service = _FakeAdRewardService(events);
      final setup = await _setup(gateway, service);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      final earning = controller.earnCredit();
      await Future<void>.delayed(Duration.zero);
      (setup.container.read(adsProvider.notifier) as _ReadyAdsController)
          .revokeConsent();
      load.complete(handle);
      await earning;

      expect(service.issueCalls, 0);
      expect(handle.showCalls, 0);
      expect(events, ['load:${AdConfig.androidSamples.rewardedId}', 'dispose']);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.failed,
      );
    },
  );

  test(
    'consent change after challenge refreshes quota and never shows',
    () async {
      final events = <String>[];
      final handle = _FakeRewardedHandle(events);
      final gateway = _FakeRewardGateway(events, handle);
      final issue = Completer<AdRewardChallenge>();
      final service = _FakeAdRewardService(events)..issueFuture = issue.future;
      final setup = await _setup(gateway, service);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      final earning = controller.earnCredit();
      while (service.issueCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      (setup.container.read(adsProvider.notifier) as _ReadyAdsController)
          .revokeConsent();
      issue.complete(_challenge());
      await earning;

      expect(handle.showCalls, 0);
      expect(handle.disposeCalls, 1);
      expect(setup.quotaController.refreshCalls, 1);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.failed,
      );
    },
  );

  test(
    'dismissed ad refreshes reservation before allowing another tap',
    () async {
      final events = <String>[];
      final handle = _FakeRewardedHandle(
        events,
        result: RewardedPresentationResult.dismissed,
      );
      final gateway = _FakeRewardGateway(events, handle);
      final service = _FakeAdRewardService(events)..issueResult = _challenge();
      final setup = await _setup(gateway, service);
      addTearDown(setup.container.dispose);

      await setup.container.read(adRewardProvider.notifier).earnCredit();

      expect(handle.showCalls, 1);
      expect(setup.quotaController.refreshCalls, 1);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.dismissed,
      );
    },
  );

  test(
    'lost challenge response refreshes quota, blocks retry, and never shows',
    () async {
      final events = <String>[];
      final handle = _FakeRewardedHandle(events);
      final gateway = _FakeRewardGateway(events, handle);
      final service = _FakeAdRewardService(events)
        ..issueError = DioException(
          requestOptions: RequestOptions(path: '/ads/rewards/challenges'),
          type: DioExceptionType.connectionError,
        );
      final setup = await _setup(gateway, service);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      await controller.earnCredit();
      final state = setup.container.read(adRewardProvider);
      expect(state.phase, RewardFlowPhase.failed);
      expect(state.retryAllowed, isFalse);
      expect(setup.quotaController.refreshCalls, 1);
      expect(handle.showCalls, 0);

      await controller.earnCredit();
      expect(gateway.loadCalls, 1);
      expect(service.issueCalls, 1);
    },
  );

  test('challenge mismatch never shows the already loaded ad', () async {
    final events = <String>[];
    final handle = _FakeRewardedHandle(events);
    final gateway = _FakeRewardGateway(events, handle);
    final request = RequestOptions(path: '/ads/rewards/challenges');
    final service = _FakeAdRewardService(events)
      ..issueError = DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 409),
        type: DioExceptionType.badResponse,
      );
    final setup = await _setup(gateway, service);
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(service.requestedAdUnitId, AdConfig.androidSamples.rewardedId);
    expect(handle.showCalls, 0);
    expect(events.last, 'dispose');
  });

  test(
    'production waits through settling until server credits the reward',
    () async {
      final events = <String>[];
      final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..pollResults.addAll([
          _status(AdRewardChallengeState.settling),
          _status(AdRewardChallengeState.credited),
        ]);
      final setup = await _setup(
        gateway,
        service,
        pollingDelays: const [Duration.zero, Duration.zero],
      );
      addTearDown(setup.container.dispose);

      await setup.container.read(adRewardProvider.notifier).earnCredit();

      expect(service.confirmCalls, 0);
      expect(service.pollCalls, 2);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
      expect(setup.quotaController.refreshCalls, 1);
    },
  );

  test(
    'credited state can start another challenge after its credit is consumed',
    () async {
      final events = <String>[];
      final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final setup = await _setup(gateway, service, development: true);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      await controller.earnCredit();
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );

      setup.quotaController.applyServerQuota(_quota(remaining: 0));
      await controller.earnCredit();

      expect(gateway.loadCalls, 2);
      expect(service.issueCalls, 2);
      expect(service.confirmCalls, 2);
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
    },
  );

  test(
    'credited status blocks another ad until quota refresh succeeds',
    () async {
      final events = <String>[];
      final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final setup = await _setup(gateway, service, development: true);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);
      setup.quotaController.refreshSucceeds = false;

      await controller.earnCredit();

      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.delayed,
      );
      await controller.earnCredit();
      expect(gateway.loadCalls, 1);

      setup.quotaController.refreshSucceeds = true;
      await controller.refreshAfterResume();

      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
      expect(
        setup.container.read(outlookQuotaProvider).requireValue.totalRemaining,
        1,
      );
      expect(gateway.loadCalls, 1);
    },
  );

  test(
    'delayed settlement is recovered on app resume without another ad',
    () async {
      final events = <String>[];
      final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..pollResults.addAll([
          _status(AdRewardChallengeState.pending),
          _status(AdRewardChallengeState.pending),
          _status(AdRewardChallengeState.credited),
        ]);
      final setup = await _setup(
        gateway,
        service,
        pollingDelays: const [Duration.zero, Duration.zero],
      );
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      await controller.earnCredit();
      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.delayed,
      );

      await controller.refreshAfterResume();

      expect(
        setup.container.read(adRewardProvider).phase,
        RewardFlowPhase.credited,
      );
      expect(gateway.loadCalls, 1);
    },
  );
}

Future<_RewardSetup> _setup(
  _FakeRewardGateway gateway,
  _FakeAdRewardService service, {
  bool development = false,
  List<Duration> pollingDelays = const [Duration.zero],
}) async {
  final quotaController = _TestQuotaController();
  final container = ProviderContainer(
    overrides: [
      adsRuntimePolicyProvider.overrideWithValue(
        AdsRuntimePolicy(
          enabled: true,
          platform: KisouAdPlatform.android,
          ids: AdConfig.androidSamples,
          usesOfficialTestAds: development,
        ),
      ),
      adsProvider.overrideWith(_ReadyAdsController.new),
      adGatewayProvider.overrideWithValue(gateway),
      adRewardServiceProvider.overrideWithValue(service),
      outlookQuotaProvider.overrideWith(() => quotaController),
      rewardPollingDelaysProvider.overrideWithValue(pollingDelays),
    ],
  );
  await container.read(outlookQuotaProvider.future);
  return _RewardSetup(container, quotaController);
}

class _RewardSetup {
  const _RewardSetup(this.container, this.quotaController);

  final ProviderContainer container;
  final _TestQuotaController quotaController;
}

class _ReadyAdsController extends AdsController {
  @override
  AdsState build() {
    return const AdsState(
      enabled: true,
      consentInProgress: false,
      canRequestAds: true,
      sdkInitialized: true,
      privacyOptionsRequired: false,
      generation: 1,
    );
  }

  void revokeConsent() {
    state = AdsState(
      enabled: true,
      consentInProgress: true,
      canRequestAds: false,
      sdkInitialized: true,
      privacyOptionsRequired: true,
      generation: state.generation + 1,
    );
  }
}

class _TestQuotaController extends OutlookQuotaController {
  int refreshCalls = 0;
  bool refreshSucceeds = true;

  @override
  Future<OutlookQuota> build() async => _quota(remaining: 0);

  @override
  Future<bool> refreshFromServer() async {
    refreshCalls++;
    if (!refreshSucceeds) {
      return false;
    }
    state = AsyncData(_quota(remaining: 1));
    return true;
  }
}

class _FakeRewardGateway implements AdGateway {
  _FakeRewardGateway(this.events, this.loadResult);

  final List<String> events;
  final Object loadResult;
  int loadCalls = 0;

  @override
  Future<RewardedAdHandle> loadRewarded({required String adUnitId}) async {
    loadCalls++;
    events.add('load:$adUnitId');
    final result = loadResult;
    if (result is Future<RewardedAdHandle>) {
      return result;
    }
    if (result is RewardedAdHandle) {
      return result;
    }
    throw result;
  }

  @override
  Future<bool> canRequestAds() => throw UnimplementedError();

  @override
  Future<void> initialize() => throw UnimplementedError();

  @override
  Future<bool> isPrivacyOptionsRequired() => throw UnimplementedError();

  @override
  Future<void> loadAndShowConsentFormIfRequired() => throw UnimplementedError();

  @override
  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  }) => throw UnimplementedError();

  @override
  Future<void> requestConsentInfoUpdate() => throw UnimplementedError();

  @override
  Future<void> showPrivacyOptionsForm() => throw UnimplementedError();
}

class _FakeRewardedHandle implements RewardedAdHandle {
  _FakeRewardedHandle(
    this.events, {
    this.result = RewardedPresentationResult.earned,
    this.disposeError,
  });

  final List<String> events;
  final RewardedPresentationResult result;
  final Object? disposeError;
  int showCalls = 0;
  int disposeCalls = 0;

  @override
  Future<RewardedPresentationResult> show({required String customData}) async {
    showCalls++;
    events.add('show:$customData');
    return result;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    events.add('dispose');
    if (disposeError case final error?) {
      throw error;
    }
  }
}

class _FakeAdRewardService extends AdRewardService {
  _FakeAdRewardService(this.events) : super(Dio());

  final List<String> events;
  AdRewardChallenge? issueResult;
  Future<AdRewardChallenge>? issueFuture;
  Object? issueError;
  AdRewardChallengeStatus? confirmResult;
  final List<AdRewardChallengeStatus> pollResults = [];
  int issueCalls = 0;
  int confirmCalls = 0;
  int pollCalls = 0;
  String? requestedAdUnitId;

  @override
  Future<AdRewardChallenge> issueChallenge(
    KisouAdPlatform platform,
    String adUnitId,
  ) async {
    issueCalls++;
    requestedAdUnitId = adUnitId;
    events.add('issue:$adUnitId');
    if (issueError case final error?) {
      throw error;
    }
    return issueFuture ?? issueResult!;
  }

  @override
  Future<AdRewardChallengeStatus> confirmDevelopmentReward(
    String challengeId,
  ) async {
    confirmCalls++;
    events.add('confirm');
    return confirmResult!;
  }

  @override
  Future<AdRewardChallengeStatus> getChallenge(String challengeId) async {
    pollCalls++;
    return pollResults.removeAt(0);
  }
}

AdRewardChallenge _challenge() {
  return AdRewardChallenge(
    id: '123e4567-e89b-42d3-a456-426614174000',
    platform: KisouAdPlatform.android,
    status: AdRewardChallengeState.pending,
    expiresAt: DateTime.utc(2026, 8, 1),
    settlementExpiresAt: DateTime.utc(2026, 8, 1, 1),
    creditedAt: null,
    consumedAt: null,
    challenge: _challengeText(),
  );
}

AdRewardChallengeStatus _status(AdRewardChallengeState status) {
  return AdRewardChallengeStatus(
    id: '123e4567-e89b-42d3-a456-426614174000',
    platform: KisouAdPlatform.android,
    status: status,
    expiresAt: DateTime.utc(2026, 8, 1),
    settlementExpiresAt: DateTime.utc(2026, 8, 1, 1),
    creditedAt: status == AdRewardChallengeState.credited
        ? DateTime.utc(2026, 8, 1, 0, 30)
        : null,
    consumedAt: null,
  );
}

OutlookQuota _quota({required int remaining}) {
  return OutlookQuota(
    date: '2026-07-31',
    freeLimit: 3,
    freeUsed: 3 - remaining,
    freeRemaining: remaining,
    rewardCredits: 0,
    totalRemaining: remaining,
    resetsAt: DateTime.utc(2026, 7, 31, 15),
    adsAvailable: remaining == 0,
  );
}

String _challengeText() => List.filled(43, 'A').join();
