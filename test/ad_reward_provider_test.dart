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
import 'package:kisou_app/services/ad_reward_operation_store.dart';
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
    final store = _MemoryAdRewardOperationStore();
    final gateway = _FakeRewardGateway(events, StateError('no fill'));
    final service = _FakeAdRewardService(events);
    final setup = await _setup(gateway, service, operationStore: store);
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(events, ['load:${AdConfig.androidSamples.rewardedId}']);
    expect(store.operation, isNull);
    expect(store.writeCalls, 0);
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

  test(
    'new UUID is persisted after ad load and immediately before issuance',
    () async {
      final events = <String>[];
      final load = Completer<RewardedAdHandle>();
      final store = _MemoryAdRewardOperationStore();
      var now = DateTime.utc(2026, 7, 31);
      AdRewardOperation? operationAtIssue;
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited)
        ..onIssue = () => operationAtIssue = store.operation;
      final setup = await _setup(
        _FakeRewardGateway(events, load.future),
        service,
        development: true,
        operationStore: store,
        clock: () => now,
      );
      addTearDown(setup.container.dispose);

      final earning = setup.container
          .read(adRewardProvider.notifier)
          .earnCredit();
      while (events.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(store.operation, isNull);
      expect(store.writeCalls, 0);
      now = now.add(const Duration(minutes: 2));
      load.complete(_FakeRewardedHandle(events));
      await earning;

      expect(operationAtIssue?.stage, AdRewardOperationStage.issuing);
      expect(operationAtIssue?.createdAt, now);
      expect(service.issueCalls, 1);
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
    final second = controller.earnCredit();
    expect(identical(first, second), isTrue);
    expect(gateway.loadCalls, 1);

    load.complete(_FakeRewardedHandle(events));
    await Future.wait([first, second]);
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
      final setup = await _setup(gateway, service, development: true);
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
    'lost challenge response retries the same durable UUID without showing',
    () async {
      final events = <String>[];
      final handle = _FakeRewardedHandle(events);
      final gateway = _FakeRewardGateway(events, handle);
      final service = _FakeAdRewardService(events)
        ..issueError = DioException(
          requestOptions: RequestOptions(path: '/ads/rewards/challenges'),
          type: DioExceptionType.connectionError,
        );
      final setup = await _setup(gateway, service, development: true);
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      await controller.earnCredit();
      final state = setup.container.read(adRewardProvider);
      expect(state.phase, RewardFlowPhase.failed);
      expect(state.retryAllowed, isTrue);
      expect(setup.quotaController.refreshCalls, 1);
      expect(handle.showCalls, 0);

      service
        ..issueError = null
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      setup.quotaController.applyServerQuota(_quota(remaining: 0));
      await controller.earnCredit();
      expect(gateway.loadCalls, 2);
      expect(service.issueCalls, 2);
      expect(service.requestedIdempotencyKeys, [
        '11111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111',
      ]);
      expect(handle.showCalls, 1);
    },
  );

  test('challenge mismatch never shows the already loaded ad', () async {
    final events = <String>[];
    final handle = _FakeRewardedHandle(events);
    final gateway = _FakeRewardGateway(events, handle);
    final store = _MemoryAdRewardOperationStore();
    final keys = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ];
    final request = RequestOptions(path: '/ads/rewards/challenges');
    final service = _FakeAdRewardService(events)
      ..issueError = DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 409),
        type: DioExceptionType.badResponse,
      );
    final setup = await _setup(
      gateway,
      service,
      development: true,
      operationStore: store,
      idempotencyKeyFactory: () => keys.removeAt(0),
    );
    addTearDown(setup.container.dispose);
    final controller = setup.container.read(adRewardProvider.notifier);

    await controller.earnCredit();

    expect(service.requestedAdUnitId, AdConfig.androidSamples.rewardedId);
    expect(handle.showCalls, 0);
    expect(events.last, 'dispose');
    expect(store.operation, isNull);

    service
      ..issueError = null
      ..issueResult = _challenge()
      ..confirmResult = _status(AdRewardChallengeState.credited);
    setup.quotaController.applyServerQuota(_quota(remaining: 0));
    await controller.earnCredit();

    expect(service.requestedIdempotencyKeys, [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ]);
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

  test('secure operation write failure prevents challenge issuance', () async {
    final events = <String>[];
    final store = _MemoryAdRewardOperationStore()
      ..writeError = StateError('secure storage unavailable');
    final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
    final service = _FakeAdRewardService(events)..issueResult = _challenge();
    final setup = await _setup(gateway, service, operationStore: store);
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(gateway.loadCalls, 1);
    expect(service.issueCalls, 0);
    expect(setup.container.read(adRewardProvider).retryAllowed, isFalse);
  });

  test('process restart replays a lost response with the same UUID', () async {
    final store = _MemoryAdRewardOperationStore();
    final firstEvents = <String>[];
    final firstService = _FakeAdRewardService(firstEvents)
      ..issueError = DioException(
        requestOptions: RequestOptions(path: '/ads/rewards/challenges'),
        type: DioExceptionType.connectionError,
      );
    final first = await _setup(
      _FakeRewardGateway(firstEvents, _FakeRewardedHandle(firstEvents)),
      firstService,
      operationStore: store,
    );
    await first.container.read(adRewardProvider.notifier).earnCredit();
    first.container.dispose();

    final secondEvents = <String>[];
    final secondHandle = _FakeRewardedHandle(secondEvents);
    final secondService = _FakeAdRewardService(secondEvents)
      ..issueResult = _challenge()
      ..confirmResult = _status(AdRewardChallengeState.credited);
    final second = await _setup(
      _FakeRewardGateway(secondEvents, secondHandle),
      secondService,
      development: true,
      operationStore: store,
    );
    addTearDown(second.container.dispose);

    await second.container.read(adRewardProvider.notifier).earnCredit();

    expect(firstService.requestedIdempotencyKeys, [
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(secondService.requestedIdempotencyKeys, [
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(secondHandle.showCalls, 1);
    expect(store.operation, isNull);
  });

  test(
    'restart recovers when response arrived before issued state persisted',
    () async {
      final store = _MemoryAdRewardOperationStore()..failWriteCall = 2;
      final firstEvents = <String>[];
      final firstService = _FakeAdRewardService(firstEvents)
        ..issueResult = _challenge();
      final first = await _setup(
        _FakeRewardGateway(firstEvents, _FakeRewardedHandle(firstEvents)),
        firstService,
        operationStore: store,
      );

      await first.container.read(adRewardProvider.notifier).earnCredit();
      expect(store.operation?.stage, AdRewardOperationStage.issuing);
      first.container.dispose();

      store.failWriteCall = null;
      final secondEvents = <String>[];
      final secondHandle = _FakeRewardedHandle(secondEvents);
      final secondService = _FakeAdRewardService(secondEvents)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final second = await _setup(
        _FakeRewardGateway(secondEvents, secondHandle),
        secondService,
        development: true,
        operationStore: store,
      );
      addTearDown(second.container.dispose);

      await second.container.read(adRewardProvider.notifier).earnCredit();

      expect(secondService.requestedIdempotencyKeys, [
        '11111111-1111-4111-8111-111111111111',
      ]);
      expect(secondHandle.showCalls, 1);
    },
  );

  test('presented operation restarts by polling without another ad', () async {
    final events = <String>[];
    final store = _MemoryAdRewardOperationStore()
      ..operation = _presentedOperation();
    final gateway = _FakeRewardGateway(events, _FakeRewardedHandle(events));
    final service = _FakeAdRewardService(events)
      ..pollResults.addAll([
        _status(AdRewardChallengeState.pending),
        _status(AdRewardChallengeState.credited),
      ]);
    final setup = await _setup(
      gateway,
      service,
      operationStore: store,
      pollingDelays: const [Duration.zero],
    );
    addTearDown(setup.container.dispose);

    setup.container.read(adRewardProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(gateway.loadCalls, 0);
    expect(service.issueCalls, 0);
    expect(service.pollCalls, 2);
    expect(
      setup.container.read(adRewardProvider).phase,
      RewardFlowPhase.credited,
    );
  });

  test(
    'startup restore and an immediate tap share one operation read',
    () async {
      final events = <String>[];
      final read = Completer<AdRewardOperationSnapshot>();
      final store = _MemoryAdRewardOperationStore()..snapshotRead = read;
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge()
        ..confirmResult = _status(AdRewardChallengeState.credited);
      final setup = await _setup(
        _FakeRewardGateway(events, _FakeRewardedHandle(events)),
        service,
        development: true,
        operationStore: store,
      );
      addTearDown(setup.container.dispose);
      final controller = setup.container.read(adRewardProvider.notifier);

      final earning = controller.earnCredit();
      await Future<void>.delayed(Duration.zero);
      expect(store.readCalls, 1);
      read.complete(
        AdRewardOperationSnapshot(
          operation: null,
          accountGeneration: store.accountGeneration,
        ),
      );
      await earning;

      expect(store.readCalls, 1);
      expect(service.issueCalls, 1);
    },
  );

  test('disposing during a delayed restore performs no ad work', () async {
    final events = <String>[];
    final read = Completer<AdRewardOperationSnapshot>();
    final store = _MemoryAdRewardOperationStore()..snapshotRead = read;
    final service = _FakeAdRewardService(events)..issueResult = _challenge();
    final setup = await _setup(
      _FakeRewardGateway(events, _FakeRewardedHandle(events)),
      service,
      operationStore: store,
    );
    setup.container.read(adRewardProvider);
    await Future<void>.delayed(Duration.zero);

    setup.container.dispose();
    read.complete(
      AdRewardOperationSnapshot(
        operation: _issuingOperation(),
        accountGeneration: store.accountGeneration,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.issueCalls, 0);
    expect(events, isEmpty);
  });

  test(
    'credited replay with quota loss leaves delayed recovery, not busy',
    () async {
      final events = <String>[];
      final store = _MemoryAdRewardOperationStore()
        ..operation = _issuingOperation();
      final handle = _FakeRewardedHandle(events);
      final service = _FakeAdRewardService(events)
        ..issueResult = _challenge(status: AdRewardChallengeState.credited);
      final setup = await _setup(
        _FakeRewardGateway(events, handle),
        service,
        operationStore: store,
        pollingDelays: const [],
      );
      addTearDown(setup.container.dispose);
      setup.quotaController.refreshSucceeds = false;

      await setup.container.read(adRewardProvider.notifier).earnCredit();

      final state = setup.container.read(adRewardProvider);
      expect(handle.showCalls, 0);
      expect(state.phase, RewardFlowPhase.delayed);
      expect(state.isBusy, isFalse);
      expect(store.operation?.stage, AdRewardOperationStage.presented);
    },
  );

  test('settling replay polls and never presents the loaded ad', () async {
    final events = <String>[];
    final store = _MemoryAdRewardOperationStore()
      ..operation = _issuingOperation();
    final handle = _FakeRewardedHandle(events);
    final service = _FakeAdRewardService(events)
      ..issueResult = _challenge(status: AdRewardChallengeState.settling)
      ..pollResults.add(_status(AdRewardChallengeState.credited));
    final setup = await _setup(
      _FakeRewardGateway(events, handle),
      service,
      operationStore: store,
      pollingDelays: const [Duration.zero],
    );
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(handle.showCalls, 0);
    expect(
      setup.container.read(adRewardProvider).phase,
      RewardFlowPhase.credited,
    );
  });

  test('expired replay clears the UUID and never presents the ad', () async {
    final events = <String>[];
    final store = _MemoryAdRewardOperationStore()
      ..operation = _issuingOperation();
    final handle = _FakeRewardedHandle(events);
    final service = _FakeAdRewardService(events)
      ..issueResult = _challenge(status: AdRewardChallengeState.expired);
    final setup = await _setup(
      _FakeRewardGateway(events, handle),
      service,
      operationStore: store,
    );
    addTearDown(setup.container.dispose);

    await setup.container.read(adRewardProvider.notifier).earnCredit();

    expect(handle.showCalls, 0);
    expect(store.operation, isNull);
    expect(
      setup.container.read(adRewardProvider).phase,
      RewardFlowPhase.failed,
    );
  });
}

Future<_RewardSetup> _setup(
  _FakeRewardGateway gateway,
  _FakeAdRewardService service, {
  bool development = false,
  List<Duration> pollingDelays = const [Duration.zero],
  _MemoryAdRewardOperationStore? operationStore,
  String Function()? idempotencyKeyFactory,
  DateTime Function()? clock,
}) async {
  final quotaController = _TestQuotaController();
  final store = operationStore ?? _MemoryAdRewardOperationStore();
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
      adRewardOperationStoreProvider.overrideWithValue(store),
      adRewardIdempotencyKeyFactoryProvider.overrideWithValue(
        idempotencyKeyFactory ?? () => '11111111-1111-4111-8111-111111111111',
      ),
      adRewardClockProvider.overrideWithValue(
        clock ?? () => DateTime.utc(2026, 7, 31),
      ),
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
  void Function()? onIssue;
  AdRewardChallengeStatus? confirmResult;
  final List<AdRewardChallengeStatus> pollResults = [];
  int issueCalls = 0;
  int confirmCalls = 0;
  int pollCalls = 0;
  String? requestedAdUnitId;
  final List<String> requestedIdempotencyKeys = [];

  @override
  Future<AdRewardChallenge> issueChallenge(
    KisouAdPlatform platform,
    String adUnitId, {
    required String idempotencyKey,
  }) async {
    issueCalls++;
    onIssue?.call();
    requestedAdUnitId = adUnitId;
    requestedIdempotencyKeys.add(idempotencyKey);
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

AdRewardChallenge _challenge({
  AdRewardChallengeState status = AdRewardChallengeState.pending,
}) {
  final creditedAt =
      status == AdRewardChallengeState.credited ||
          status == AdRewardChallengeState.consumed
      ? DateTime.utc(2026, 8, 1, 0, 30)
      : null;
  return AdRewardChallenge(
    id: '123e4567-e89b-42d3-a456-426614174000',
    platform: KisouAdPlatform.android,
    status: status,
    expiresAt: DateTime.utc(2026, 8, 1),
    settlementExpiresAt: DateTime.utc(2026, 8, 1, 1),
    creditedAt: creditedAt,
    consumedAt: status == AdRewardChallengeState.consumed
        ? DateTime.utc(2026, 8, 1, 0, 45)
        : null,
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

AdRewardOperation _issuingOperation({
  String idempotencyKey = '11111111-1111-4111-8111-111111111111',
}) {
  return AdRewardOperation.issuing(
    idempotencyKey: idempotencyKey,
    platform: KisouAdPlatform.android,
    adUnitId: AdConfig.androidSamples.rewardedId,
    createdAt: DateTime.utc(2026, 7, 31),
  );
}

AdRewardOperation _presentedOperation() {
  return _issuingOperation()
      .withIssuedChallenge(
        challengeId: '123e4567-e89b-42d3-a456-426614174000',
        expiresAt: DateTime.utc(2026, 8, 1),
        settlementExpiresAt: DateTime.utc(2026, 8, 1, 1),
      )
      .asPresented();
}

class _MemoryAdRewardOperationStore extends AdRewardOperationStore {
  AdRewardOperation? operation;
  Object? readError;
  Object? writeError;
  Object? deleteError;
  int writeCalls = 0;
  int deleteCalls = 0;
  int? failWriteCall;
  int accountGeneration = 0;
  int readCalls = 0;
  Completer<AdRewardOperationSnapshot>? snapshotRead;

  @override
  Future<AdRewardOperation?> read() async {
    if (readError case final error?) {
      throw error;
    }
    return operation;
  }

  @override
  Future<AdRewardOperationSnapshot> readSnapshot() async {
    readCalls++;
    if (snapshotRead case final completer?) {
      return completer.future;
    }
    return AdRewardOperationSnapshot(
      operation: await read(),
      accountGeneration: accountGeneration,
    );
  }

  @override
  Future<void> write(AdRewardOperation next) async {
    writeCalls++;
    if (writeError case final error?) {
      throw error;
    }
    if (writeCalls == failWriteCall) {
      throw StateError('operation write failed');
    }
    operation = next;
  }

  @override
  Future<void> writeIfCurrent(
    AdRewardOperation next, {
    required int accountGeneration,
  }) async {
    if (accountGeneration != this.accountGeneration) {
      throw const StaleAdRewardAccountOperationException();
    }
    await write(next);
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    if (deleteError case final error?) {
      throw error;
    }
    operation = null;
  }

  @override
  Future<void> deleteIfCurrent({required int accountGeneration}) async {
    if (accountGeneration != this.accountGeneration) {
      throw const StaleAdRewardAccountOperationException();
    }
    await delete();
  }

  @override
  Future<void> closeWritesAndClear() async {
    accountGeneration++;
    await delete();
  }
}
