import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ad_reward.dart';
import '../services/ad_gateway.dart';
import '../services/ad_reward_operation_store.dart';
import '../services/ad_reward_service.dart';
import 'ads_provider.dart';
import 'api_provider.dart';
import 'outlook_quota_provider.dart';

final adRewardServiceProvider = Provider<AdRewardService>((ref) {
  return AdRewardService(ref.watch(apiClientProvider));
});

final adRewardOperationStoreProvider = Provider<AdRewardOperationStore>((ref) {
  return AdRewardOperationStore();
});

final adRewardIdempotencyKeyFactoryProvider = Provider<String Function()>((
  ref,
) {
  const uuid = Uuid();
  return uuid.v4;
});

final adRewardClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

final rewardPollingDelaysProvider = Provider<List<Duration>>((ref) {
  return const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
  ];
});

enum RewardFlowPhase {
  idle,
  loadingAd,
  issuingChallenge,
  showingAd,
  settling,
  credited,
  delayed,
  dismissed,
  failed,
}

class RewardFlowState {
  const RewardFlowState({
    required this.phase,
    this.retryAllowed = true,
    this.settlementExpiresAt,
    this.error,
  });

  const RewardFlowState.idle() : this(phase: RewardFlowPhase.idle);

  final RewardFlowPhase phase;
  final bool retryAllowed;
  final DateTime? settlementExpiresAt;
  final Object? error;

  bool get isBusy =>
      phase == RewardFlowPhase.loadingAd ||
      phase == RewardFlowPhase.issuingChallenge ||
      phase == RewardFlowPhase.showingAd ||
      phase == RewardFlowPhase.settling;

  bool get canRequestNewChallenge =>
      retryAllowed &&
      !isBusy &&
      (phase == RewardFlowPhase.idle ||
          phase == RewardFlowPhase.dismissed ||
          phase == RewardFlowPhase.failed ||
          phase == RewardFlowPhase.credited);
}

final adRewardProvider = NotifierProvider<AdRewardController, RewardFlowState>(
  AdRewardController.new,
);

class AdRewardController extends Notifier<RewardFlowState> {
  int _generation = 0;
  String? _activeChallengeId;
  DateTime? _settlementExpiresAt;
  Future<void>? _pollFuture;
  Future<AdRewardOperation?>? _restoreFuture;
  Future<void>? _earnFuture;
  Future<void>? _startupRecoveryFuture;
  Future<void>? _resumeRecoveryFuture;
  AdRewardOperation? _pendingOperation;
  int? _storeAccountGeneration;
  bool _operationStoreRestored = false;
  bool _serverCreditConfirmed = false;

  @override
  RewardFlowState build() {
    ref.onDispose(() {
      _generation++;
    });
    if (ref.read(adsRuntimePolicyProvider).enabled) {
      final operation = _generation;
      late final Future<void> startup;
      startup = Future<void>.microtask(() => _restoreAfterBuild(operation))
          .catchError((_) {})
          .whenComplete(() {
            if (identical(_startupRecoveryFuture, startup)) {
              _startupRecoveryFuture = null;
            }
          });
      _startupRecoveryFuture = startup;
      unawaited(startup);
    }
    return const RewardFlowState.idle();
  }

  Future<void> earnCredit() {
    if (_earnFuture != null) {
      return _earnFuture!;
    }
    return _earnFuture ??= _earnCredit().whenComplete(() {
      _earnFuture = null;
    });
  }

  Future<void> _earnCredit() async {
    final startupRecovery = _startupRecoveryFuture;
    if (startupRecovery != null) {
      await startupRecovery;
    }
    if (!state.canRequestNewChallenge) {
      return;
    }
    final policy = ref.read(adsRuntimePolicyProvider);
    final ads = ref.read(adsProvider);
    final quota = ref.read(outlookQuotaProvider).value;
    if (!policy.enabled ||
        !ads.mayLoadAds ||
        quota == null ||
        quota.totalRemaining > 0 ||
        !quota.adsAvailable) {
      return;
    }

    final operation = ++_generation;
    final consentGeneration = ads.generation;
    RewardedAdHandle? ad;
    _serverCreditConfirmed = false;
    try {
      var pending = await _restoreOperation();
      if (!_isCurrent(operation)) {
        return;
      }
      if (pending?.stage == AdRewardOperationStage.presented) {
        await _recoverPresentedOperation(operation, pending!);
        return;
      }
      pending = await _validateRestoredIssuanceOperation(policy, pending);
      if (!_isCurrent(operation)) {
        return;
      }

      state = const RewardFlowState(phase: RewardFlowPhase.loadingAd);
      ad = await ref
          .read(adGatewayProvider)
          .loadRewarded(adUnitId: policy.ids.rewardedId);
      if (!_isCurrent(operation)) {
        return;
      }
      if (!_adRequestStillAllowed(consentGeneration)) {
        throw StateError('Ad consent changed while the rewarded ad loaded.');
      }

      pending ??= await _createIssuanceOperation(policy);
      if (!_isCurrent(operation)) {
        return;
      }
      if (!_adRequestStillAllowed(consentGeneration)) {
        throw StateError('Ad consent changed before challenge issuance.');
      }

      state = const RewardFlowState(phase: RewardFlowPhase.issuingChallenge);
      final challenge = await ref
          .read(adRewardServiceProvider)
          .issueChallenge(
            policy.platform,
            policy.ids.rewardedId,
            idempotencyKey: pending.idempotencyKey,
          );
      _activeChallengeId = challenge.id;
      _settlementExpiresAt = challenge.settlementExpiresAt;
      if (!_isCurrent(operation)) {
        return;
      }
      if (!_adRequestStillAllowed(consentGeneration)) {
        throw StateError('Ad consent changed before rewarded presentation.');
      }
      if (challenge.platform != policy.platform ||
          pending.challengeId != null && pending.challengeId != challenge.id) {
        throw StateError('The replayed reward challenge does not match.');
      }

      if (challenge.status != AdRewardChallengeState.pending) {
        await _handleReplayedStatus(operation, pending, challenge);
        return;
      }
      final issued = pending.withIssuedChallenge(
        challengeId: challenge.id,
        expiresAt: challenge.expiresAt,
        settlementExpiresAt: challenge.settlementExpiresAt,
      );
      await _writePendingOperation(issued);
      if (!_isCurrent(operation)) {
        return;
      }
      _pendingOperation = issued;
      final presented = issued.asPresented();
      // Persist the no-second-show boundary before entering the native SDK.
      await _writePendingOperation(presented);
      if (!_isCurrent(operation)) {
        return;
      }
      _pendingOperation = presented;

      state = RewardFlowState(
        phase: RewardFlowPhase.showingAd,
        settlementExpiresAt: challenge.settlementExpiresAt,
      );
      final presentation = await ad.show(customData: challenge.challenge);
      await _disposeRewardedAd(ad);
      ad = null;
      if (!_isCurrent(operation)) {
        return;
      }
      if (presentation == RewardedPresentationResult.dismissed) {
        await _clearPendingOperation();
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (!_isCurrent(operation)) {
          return;
        }
        state = RewardFlowState(
          phase: RewardFlowPhase.dismissed,
          settlementExpiresAt: challenge.settlementExpiresAt,
        );
        return;
      }

      AdRewardChallengeStatus initialStatus = challenge;
      state = RewardFlowState(
        phase: RewardFlowPhase.settling,
        settlementExpiresAt: challenge.settlementExpiresAt,
      );
      if (policy.usesOfficialTestAds) {
        try {
          initialStatus = await ref
              .read(adRewardServiceProvider)
              .confirmDevelopmentReward(challenge.id);
        } catch (_) {
          // A development-confirm response can be lost after the server
          // commits. Poll the known challenge instead of showing another ad.
        }
      }
      if (!_isCurrent(operation)) {
        return;
      }
      await _settle(operation, initialStatus);
    } catch (error) {
      if (_isCurrent(operation)) {
        final statusCode = error is DioException
            ? error.response?.statusCode
            : null;
        if (statusCode == 409) {
          // The server has definitively rejected this semantic replay. Keep
          // this tap failed; only a later explicit tap may create a new UUID.
          try {
            await _clearPendingOperation();
          } catch (_) {
            // A failed secure delete remains fail-closed below.
          }
        }
        if (_pendingOperation != null || statusCode == 409) {
          await ref.read(outlookQuotaProvider.notifier).refresh();
        }
        if (!_isCurrent(operation)) {
          return;
        }
        state = RewardFlowState(
          phase: RewardFlowPhase.failed,
          retryAllowed: statusCode == 409 || _pendingOperation != null,
          settlementExpiresAt: _settlementExpiresAt,
          error: error,
        );
      }
    } finally {
      if (ad != null) {
        await _disposeRewardedAd(ad);
      }
    }
  }

  Future<AdRewardOperation?> _validateRestoredIssuanceOperation(
    AdsRuntimePolicy policy,
    AdRewardOperation? existing,
  ) async {
    final now = ref.read(adRewardClockProvider)();
    if (existing != null) {
      final matches =
          existing.platform == policy.platform &&
          existing.adUnitId == policy.ids.rewardedId;
      final replayExpired = !now.isBefore(existing.issueReplayDeadline);
      if (!matches && !replayExpired) {
        throw StateError(
          'A reward request for another ad configuration is unresolved.',
        );
      }
      if (replayExpired) {
        await _clearPendingOperation();
        existing = null;
      }
    }
    if (existing != null) {
      return existing;
    }
    return null;
  }

  Future<AdRewardOperation> _createIssuanceOperation(
    AdsRuntimePolicy policy,
  ) async {
    final now = ref.read(adRewardClockProvider)();
    final operation = AdRewardOperation.issuing(
      idempotencyKey: ref.read(adRewardIdempotencyKeyFactoryProvider)(),
      platform: policy.platform,
      adUnitId: policy.ids.rewardedId,
      createdAt: now,
    );
    // No API call may occur unless this exact UUID is durable.
    await _writePendingOperation(operation);
    _pendingOperation = operation;
    return operation;
  }

  Future<void> _handleReplayedStatus(
    int operation,
    AdRewardOperation pending,
    AdRewardChallenge challenge,
  ) async {
    switch (challenge.status) {
      case AdRewardChallengeState.pending:
        throw StateError('Pending replay must continue to presentation.');
      case AdRewardChallengeState.settling:
        final presented = pending
            .withIssuedChallenge(
              challengeId: challenge.id,
              expiresAt: challenge.expiresAt,
              settlementExpiresAt: challenge.settlementExpiresAt,
            )
            .asPresented();
        await _writePendingOperation(presented);
        if (!_isCurrent(operation)) {
          return;
        }
        _pendingOperation = presented;
        await _settle(operation, challenge);
        return;
      case AdRewardChallengeState.credited:
        final presented = pending
            .withIssuedChallenge(
              challengeId: challenge.id,
              expiresAt: challenge.expiresAt,
              settlementExpiresAt: challenge.settlementExpiresAt,
            )
            .asPresented();
        await _writePendingOperation(presented);
        if (!_isCurrent(operation)) {
          return;
        }
        _pendingOperation = presented;
        final done = await _handleStatus(operation, challenge);
        if (!done && _isCurrent(operation)) {
          await _settle(operation, challenge);
        }
        return;
      case AdRewardChallengeState.consumed:
      case AdRewardChallengeState.expired:
        final done = await _handleStatus(operation, challenge);
        if (!done && _isCurrent(operation)) {
          state = RewardFlowState(
            phase: RewardFlowPhase.delayed,
            retryAllowed: false,
            settlementExpiresAt: challenge.settlementExpiresAt,
          );
        }
        return;
    }
  }

  Future<void> _settle(
    int operation,
    AdRewardChallengeStatus initialStatus,
  ) async {
    final immediate = await _handleStatus(operation, initialStatus);
    if (immediate) {
      return;
    }
    state = RewardFlowState(
      phase: RewardFlowPhase.settling,
      settlementExpiresAt: initialStatus.settlementExpiresAt,
    );
    final poll = _poll(operation);
    _pollFuture = poll;
    await poll.whenComplete(() {
      if (identical(_pollFuture, poll)) {
        _pollFuture = null;
      }
    });
  }

  Future<void> _poll(int operation) async {
    final challengeId = _activeChallengeId;
    if (challengeId == null) {
      return;
    }
    for (final delay in ref.read(rewardPollingDelaysProvider)) {
      await Future<void>.delayed(delay);
      if (!_isCurrent(operation)) {
        return;
      }
      try {
        final status = await ref
            .read(adRewardServiceProvider)
            .getChallenge(challengeId);
        if (await _handleStatus(operation, status)) {
          return;
        }
      } catch (_) {
        // SSV and the status endpoint can be delayed independently. Continue
        // the bounded schedule, then offer resume-based recovery.
      }
    }
    if (_isCurrent(operation)) {
      state = RewardFlowState(
        phase: RewardFlowPhase.delayed,
        settlementExpiresAt: _settlementExpiresAt,
      );
    }
  }

  Future<bool> _handleStatus(
    int operation,
    AdRewardChallengeStatus status,
  ) async {
    if (!_isCurrent(operation)) {
      return true;
    }
    _settlementExpiresAt = status.settlementExpiresAt;
    switch (status.status) {
      case AdRewardChallengeState.credited:
        _serverCreditConfirmed = true;
        final refreshed = await ref
            .read(outlookQuotaProvider.notifier)
            .refreshFromServer();
        final quota = ref.read(outlookQuotaProvider).value;
        if (_isCurrent(operation) &&
            refreshed &&
            quota != null &&
            quota.totalRemaining > 0) {
          await _clearPendingOperation();
          if (!_isCurrent(operation)) {
            return true;
          }
          _serverCreditConfirmed = false;
          state = RewardFlowState(
            phase: RewardFlowPhase.credited,
            settlementExpiresAt: status.settlementExpiresAt,
          );
          return true;
        }
        return !_isCurrent(operation);
      case AdRewardChallengeState.consumed:
        await _clearPendingOperation();
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (_isCurrent(operation)) {
          _serverCreditConfirmed = false;
          state = RewardFlowState(
            phase: RewardFlowPhase.failed,
            settlementExpiresAt: status.settlementExpiresAt,
          );
        }
        return true;
      case AdRewardChallengeState.expired:
        await _clearPendingOperation();
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (_isCurrent(operation)) {
          _serverCreditConfirmed = false;
          state = RewardFlowState(
            phase: RewardFlowPhase.failed,
            settlementExpiresAt: status.settlementExpiresAt,
          );
        }
        return true;
      case AdRewardChallengeState.pending:
      case AdRewardChallengeState.settling:
        return false;
    }
  }

  Future<void> refreshAfterResume() {
    return _resumeRecoveryFuture ??= _refreshAfterResume().whenComplete(() {
      _resumeRecoveryFuture = null;
    });
  }

  Future<void> _refreshAfterResume() async {
    final operation = _generation;
    final quotaRefreshed = await ref
        .read(outlookQuotaProvider.notifier)
        .refreshFromServer();
    if (!_isCurrent(operation)) {
      return;
    }
    final quota = ref.read(outlookQuotaProvider).value;
    if (_serverCreditConfirmed &&
        quotaRefreshed &&
        quota != null &&
        quota.totalRemaining > 0) {
      await _clearPendingOperation();
      if (!_isCurrent(operation)) {
        return;
      }
      _serverCreditConfirmed = false;
      state = RewardFlowState(
        phase: RewardFlowPhase.credited,
        settlementExpiresAt: _settlementExpiresAt,
      );
      return;
    }
    final pending = await _restoreOperation();
    if (!_isCurrent(operation)) {
      return;
    }
    if (pending == null) {
      return;
    }
    if (pending.stage != AdRewardOperationStage.presented) {
      if (!state.isBusy) {
        state = RewardFlowState(
          phase: RewardFlowPhase.failed,
          retryAllowed: true,
          settlementExpiresAt: pending.settlementExpiresAt,
        );
      }
      return;
    }
    if (_pollFuture != null && state.phase == RewardFlowPhase.settling) {
      return;
    }
    await _recoverPresentedOperation(operation, pending);
  }

  void pausePollingForBackground() {
    if (state.phase != RewardFlowPhase.settling) {
      return;
    }
    _generation++;
    _pollFuture = null;
    state = RewardFlowState(
      phase: RewardFlowPhase.delayed,
      settlementExpiresAt: _settlementExpiresAt,
    );
  }

  void resetMessage() {
    if (!state.isBusy) {
      state = const RewardFlowState.idle();
    }
  }

  bool _isCurrent(int operation) => operation == _generation;

  bool _adRequestStillAllowed(int consentGeneration) {
    final ads = ref.read(adsProvider);
    return ads.generation == consentGeneration && ads.mayLoadAds;
  }

  Future<void> _disposeRewardedAd(RewardedAdHandle ad) async {
    try {
      await ad.dispose();
    } catch (_) {
      // Native cleanup is best-effort and must not replace the authoritative
      // reward state or surface as an unhandled UI Future.
    }
  }

  Future<void> _restoreAfterBuild(int operation) async {
    try {
      final pending = await _restoreOperation();
      if (!_isCurrent(operation)) {
        return;
      }
      if (pending == null) {
        return;
      }
      if (pending.stage == AdRewardOperationStage.presented) {
        await refreshAfterResume();
        if (!_isCurrent(operation)) {
          return;
        }
      } else if (!state.isBusy) {
        state = RewardFlowState(
          phase: RewardFlowPhase.failed,
          retryAllowed: true,
          settlementExpiresAt: pending.settlementExpiresAt,
        );
      }
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      state = RewardFlowState(
        phase: RewardFlowPhase.failed,
        retryAllowed: false,
        error: error,
      );
    }
  }

  Future<AdRewardOperation?> _restoreOperation() {
    if (_operationStoreRestored) {
      return Future.value(_pendingOperation);
    }
    if (_pendingOperation case final operation?) {
      return Future.value(operation);
    }
    final operationGeneration = _generation;
    return _restoreFuture ??= ref
        .read(adRewardOperationStoreProvider)
        .readSnapshot()
        .then((snapshot) {
          if (_isCurrent(operationGeneration)) {
            _storeAccountGeneration = snapshot.accountGeneration;
            _pendingOperation = snapshot.operation;
            _operationStoreRestored = true;
            _activeChallengeId = snapshot.operation?.challengeId;
            _settlementExpiresAt = snapshot.operation?.settlementExpiresAt;
          }
          return snapshot.operation;
        })
        .whenComplete(() {
          _restoreFuture = null;
        });
  }

  Future<void> _recoverPresentedOperation(
    int operation,
    AdRewardOperation pending,
  ) async {
    final challengeId = pending.challengeId;
    if (challengeId == null) {
      throw StateError('Presented reward operation has no challenge ID.');
    }
    _activeChallengeId = challengeId;
    _settlementExpiresAt = pending.settlementExpiresAt;
    state = RewardFlowState(
      phase: RewardFlowPhase.settling,
      settlementExpiresAt: pending.settlementExpiresAt,
    );
    try {
      final status = await ref
          .read(adRewardServiceProvider)
          .getChallenge(challengeId);
      if (await _handleStatus(operation, status)) {
        return;
      }
      if (_isCurrent(operation)) {
        await _settle(operation, status);
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        state = RewardFlowState(
          phase: RewardFlowPhase.delayed,
          retryAllowed: false,
          settlementExpiresAt: pending.settlementExpiresAt,
        );
      }
    }
  }

  Future<void> _clearPendingOperation() async {
    final accountGeneration = _storeAccountGeneration;
    if (accountGeneration == null) {
      throw StateError('Ad reward operation store was not restored.');
    }
    await ref
        .read(adRewardOperationStoreProvider)
        .deleteIfCurrent(accountGeneration: accountGeneration);
    _pendingOperation = null;
    _activeChallengeId = null;
    _settlementExpiresAt = null;
  }

  Future<void> _writePendingOperation(AdRewardOperation operation) async {
    final accountGeneration = _storeAccountGeneration;
    if (accountGeneration == null) {
      throw StateError('Ad reward operation store was not restored.');
    }
    await ref
        .read(adRewardOperationStoreProvider)
        .writeIfCurrent(operation, accountGeneration: accountGeneration);
  }
}
