import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ad_reward.dart';
import '../services/ad_gateway.dart';
import '../services/ad_reward_service.dart';
import 'ads_provider.dart';
import 'api_provider.dart';
import 'outlook_quota_provider.dart';

final adRewardServiceProvider = Provider<AdRewardService>((ref) {
  return AdRewardService(ref.watch(apiClientProvider));
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
  bool _challengeOutcomeUncertain = false;
  bool _serverCreditConfirmed = false;

  @override
  RewardFlowState build() {
    ref.onDispose(() {
      _generation++;
    });
    return const RewardFlowState.idle();
  }

  Future<void> earnCredit() async {
    if (!state.canRequestNewChallenge || _challengeOutcomeUncertain) {
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
    var challengeIssued = false;
    _serverCreditConfirmed = false;
    try {
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

      state = const RewardFlowState(phase: RewardFlowPhase.issuingChallenge);
      _challengeOutcomeUncertain = true;
      final challenge = await ref
          .read(adRewardServiceProvider)
          .issueChallenge(policy.platform, policy.ids.rewardedId);
      _challengeOutcomeUncertain = false;
      challengeIssued = true;
      _activeChallengeId = challenge.id;
      _settlementExpiresAt = challenge.settlementExpiresAt;
      if (!_isCurrent(operation)) {
        return;
      }
      if (!_adRequestStillAllowed(consentGeneration)) {
        throw StateError('Ad consent changed before rewarded presentation.');
      }

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
        if (challengeIssued || _challengeOutcomeUncertain) {
          await ref.read(outlookQuotaProvider.notifier).refresh();
        }
        if (!_isCurrent(operation)) {
          return;
        }
        state = RewardFlowState(
          phase: RewardFlowPhase.failed,
          retryAllowed: !_challengeOutcomeUncertain,
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
    _pollFuture = _poll(operation);
    await _pollFuture;
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
          _activeChallengeId = null;
          _serverCreditConfirmed = false;
          state = RewardFlowState(
            phase: RewardFlowPhase.credited,
            settlementExpiresAt: status.settlementExpiresAt,
          );
          return true;
        }
        return !_isCurrent(operation);
      case AdRewardChallengeState.consumed:
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (_isCurrent(operation)) {
          _activeChallengeId = null;
          _serverCreditConfirmed = false;
          state = RewardFlowState(
            phase: RewardFlowPhase.failed,
            settlementExpiresAt: status.settlementExpiresAt,
          );
        }
        return true;
      case AdRewardChallengeState.expired:
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (_isCurrent(operation)) {
          _activeChallengeId = null;
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

  Future<void> refreshAfterResume() async {
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
      _activeChallengeId = null;
      _serverCreditConfirmed = false;
      state = RewardFlowState(
        phase: RewardFlowPhase.credited,
        settlementExpiresAt: _settlementExpiresAt,
      );
      return;
    }
    final challengeId = _activeChallengeId;
    if (challengeId == null ||
        (state.phase != RewardFlowPhase.settling &&
            state.phase != RewardFlowPhase.delayed) ||
        _pollFuture != null && state.phase == RewardFlowPhase.settling) {
      return;
    }
    try {
      final status = await ref
          .read(adRewardServiceProvider)
          .getChallenge(challengeId);
      final done = await _handleStatus(operation, status);
      if (!done && _isCurrent(operation)) {
        state = RewardFlowState(
          phase: RewardFlowPhase.delayed,
          settlementExpiresAt: status.settlementExpiresAt,
        );
      }
    } catch (_) {
      // Keep the delayed state; another resume or explicit quota refresh can
      // recover without issuing or showing another ad.
    }
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
}
