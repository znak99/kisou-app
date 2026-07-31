import 'dart:async';

import '../services/widget_recommendation_service.dart';
import '../services/widget_snapshot_gateway.dart';

enum WidgetRefreshResult { updated, skipped, unavailable, closed }

/// Serializes widget refreshes and fences account/mutation races.
///
/// The coordinator never stores or exposes authentication data. Networking is
/// performed only by [WidgetRecommendationService] through the app's
/// authenticated Dio client; native widgets can only read the resulting
/// privacy-minimized envelope.
class WidgetRecommendationCoordinator {
  WidgetRecommendationCoordinator({
    required WidgetRecommendationSource service,
    required WidgetSnapshotGateway gateway,
    DateTime Function()? now,
    Duration minimumRefreshInterval = const Duration(hours: 3),
  }) : _service = service,
       _gateway = gateway,
       _now = now ?? DateTime.now,
       _minimumRefreshInterval = minimumRefreshInterval;

  final WidgetRecommendationSource _service;
  final WidgetSnapshotGateway _gateway;
  final DateTime Function() _now;
  final Duration _minimumRefreshInterval;
  static const _failureRetryInterval = Duration(minutes: 1);

  Future<WidgetRefreshResult>? _refreshWorker;
  Future<void>? _closeWorker;
  DateTime? _lastSuccessAt;
  DateTime? _lastFailureAt;
  var _accountGeneration = 0;
  var _requestedRefreshRevision = 0;
  var _activeRecommendationMutations = 0;
  Completer<void>? _mutationGate;
  var _closed = false;

  /// Fences an authenticated operation that can change today's rank-1 result.
  ///
  /// Any response already in flight becomes stale immediately. A replacement
  /// fetch waits until all overlapping mutations have finished.
  void beginRecommendationMutation() {
    if (_closed) return;
    _requestedRefreshRevision += 1;
    _activeRecommendationMutations += 1;
    _mutationGate ??= Completer<void>();
  }

  /// Releases a mutation fence and schedules an immediate post-commit refresh.
  void endRecommendationMutation({required bool changed}) {
    if (_activeRecommendationMutations == 0) {
      return;
    }
    _activeRecommendationMutations -= 1;
    if (_activeRecommendationMutations == 0) {
      final gate = _mutationGate;
      _mutationGate = null;
      gate?.complete();
    }
    if (changed && !_closed) {
      unawaited(refreshIfDue(force: true));
    }
  }

  Future<WidgetRefreshResult> refreshIfDue({bool force = false}) {
    if (_closed) {
      return Future.value(WidgetRefreshResult.closed);
    }
    final now = _now().toUtc();
    if (!force && _refreshWorker == null) {
      final lastFailure = _lastFailureAt;
      final lastSuccess = _lastSuccessAt;
      final failureIsLatest =
          lastFailure != null &&
          (lastSuccess == null || !lastFailure.isBefore(lastSuccess));
      if (failureIsLatest) {
        final sinceFailure = _elapsedSince(now, lastFailure);
        if (sinceFailure != null && sinceFailure < _failureRetryInterval) {
          return Future.value(WidgetRefreshResult.skipped);
        }
      } else {
        final sinceSuccess = _elapsedSince(now, lastSuccess);
        if (sinceSuccess != null && sinceSuccess < _minimumRefreshInterval) {
          return Future.value(WidgetRefreshResult.skipped);
        }
      }
    }

    if (force || _refreshWorker == null) {
      _requestedRefreshRevision += 1;
    }
    final existing = _refreshWorker;
    if (existing != null) {
      return existing;
    }

    final accountGeneration = _accountGeneration;
    late final Future<WidgetRefreshResult> worker;
    worker = _runRefreshLoop(accountGeneration).whenComplete(() {
      if (identical(_refreshWorker, worker)) {
        _refreshWorker = null;
      }
    });
    _refreshWorker = worker;
    return worker;
  }

  /// Invalidates this coordinator without touching native storage.
  ///
  /// Provider disposal can race with an old network response. The auth
  /// transition owns the final tombstone; this synchronous fence only prevents
  /// the disposed account from publishing a later ready snapshot.
  void deactivate() {
    _closed = true;
    _accountGeneration += 1;
    _requestedRefreshRevision += 1;
    _activeRecommendationMutations = 0;
    final gate = _mutationGate;
    _mutationGate = null;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  Future<WidgetRefreshResult> _runRefreshLoop(int accountGeneration) async {
    var result = WidgetRefreshResult.unavailable;
    while (!_closed && accountGeneration == _accountGeneration) {
      final refreshRevision = _requestedRefreshRevision;
      final mutationGate = _mutationGate;
      if (mutationGate != null) {
        await mutationGate.future;
        if (_closed || accountGeneration != _accountGeneration) {
          return WidgetRefreshResult.closed;
        }
        if (refreshRevision != _requestedRefreshRevision) {
          continue;
        }
      }
      try {
        final recommendation = await _service.getToday();
        if (_closed || accountGeneration != _accountGeneration) {
          return WidgetRefreshResult.closed;
        }
        if (refreshRevision != _requestedRefreshRevision) {
          // A profile, feedback, or reset mutation superseded this response.
          // Discard it before native storage and fetch the newest revision.
          continue;
        }
        await _gateway.writeReady(recommendation);
        _lastSuccessAt = _now().toUtc();
        _lastFailureAt = null;
        result = WidgetRefreshResult.updated;
      } catch (_) {
        // Offline and transient errors preserve an existing same-JST-day
        // native snapshot. Native expiry checks hide it at the day boundary.
        _lastFailureAt = _now().toUtc();
        result = WidgetRefreshResult.unavailable;
      }

      if (_closed || accountGeneration != _accountGeneration) {
        return WidgetRefreshResult.closed;
      }
      if (refreshRevision == _requestedRefreshRevision) {
        return result;
      }
      // A forced mutation arrived during the native write. The old snapshot
      // may have existed briefly, but this worker does not finish until the
      // newest revision has replaced it (or the refresh is unavailable).
    }
    return WidgetRefreshResult.closed;
  }

  Future<void> closeAccount() {
    final existing = _closeWorker;
    if (existing != null) {
      return existing;
    }
    if (_closed) {
      return Future.value();
    }
    // Synchronous invalidation prevents a refresh started in the next event
    // loop turn from acquiring the old account lease.
    _closed = true;
    _accountGeneration += 1;
    _requestedRefreshRevision += 1;
    late final Future<void> worker;
    final closeGeneration = _accountGeneration;
    worker = _performClose(closeGeneration).whenComplete(() {
      if (identical(_closeWorker, worker)) {
        _closeWorker = null;
      }
    });
    _closeWorker = worker;
    return worker;
  }

  Future<void> _performClose(int closeGeneration) async {
    // Drain a request or native write that already acquired the old lease,
    // then make the signed-out envelope the last durable mutation.
    final refresh = _refreshWorker;
    if (refresh != null) {
      await refresh;
    }
    try {
      await _gateway.closeAccount();
    } catch (_) {
      if (_closed && closeGeneration == _accountGeneration) {
        // The outer auth transition keeps the old credentials on failure.
        // Reopen only this failed close generation and clear cooldowns. A
        // subsequent normal or explicit home refresh may restore a partially
        // published tombstone, while cleanup-recovery screens cannot
        // accidentally resurrect an already-closed account.
        _closed = false;
        _accountGeneration += 1;
        _requestedRefreshRevision += 1;
        _lastSuccessAt = null;
        _lastFailureAt = null;
      }
      rethrow;
    }
  }
}

Duration? _elapsedSince(DateTime now, DateTime? earlier) {
  if (earlier == null) return null;
  final elapsed = now.difference(earlier);
  // A wall-clock rollback must not extend a refresh suppression window.
  return elapsed.isNegative ? null : elapsed;
}
