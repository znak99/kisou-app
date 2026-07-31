import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/clothing_tags.dart';
import 'package:kisou_app/models/widget_recommendation.dart';
import 'package:kisou_app/services/widget_recommendation_coordinator.dart';
import 'package:kisou_app/services/widget_recommendation_service.dart';
import 'package:kisou_app/services/widget_snapshot_gateway.dart';

void main() {
  test('success is cooled down for three hours', () async {
    var now = DateTime.utc(2026, 7, 31, 3);
    final source = _QueueSource()
      ..enqueueValue(_recommendation())
      ..enqueueValue(_recommendation(feeling: 'COOL'));
    final gateway = _RecordingGateway();
    final coordinator = WidgetRecommendationCoordinator(
      service: source,
      gateway: gateway,
      now: () => now,
    );

    expect(await coordinator.refreshIfDue(), WidgetRefreshResult.updated);
    now = now.add(const Duration(hours: 2, minutes: 59));
    expect(await coordinator.refreshIfDue(), WidgetRefreshResult.skipped);
    now = now.add(const Duration(minutes: 1));
    expect(await coordinator.refreshIfDue(), WidgetRefreshResult.updated);
    expect(source.calls, 2);
    expect(gateway.writes, hasLength(2));
  });

  test(
    'a latest forced failure supersedes the prior success cooldown',
    () async {
      var now = DateTime.utc(2026, 7, 31, 3);
      final source = _QueueSource()
        ..enqueueValue(_recommendation())
        ..enqueueError(StateError('offline'))
        ..enqueueValue(_recommendation(feeling: 'COLD'));
      final coordinator = WidgetRecommendationCoordinator(
        service: source,
        gateway: _RecordingGateway(),
        now: () => now,
      );

      expect(await coordinator.refreshIfDue(), WidgetRefreshResult.updated);
      now = now.add(const Duration(minutes: 5));
      expect(
        await coordinator.refreshIfDue(force: true),
        WidgetRefreshResult.unavailable,
      );
      now = now.add(const Duration(seconds: 59));
      expect(await coordinator.refreshIfDue(), WidgetRefreshResult.skipped);
      now = now.add(const Duration(seconds: 1));
      expect(await coordinator.refreshIfDue(), WidgetRefreshResult.updated);
      expect(source.calls, 3);
    },
  );

  test(
    'a same-account mutation discards an older in-flight response',
    () async {
      final first = Completer<WidgetRecommendation>();
      final source = _QueueSource()
        ..enqueueFuture(first.future)
        ..enqueueValue(_recommendation(feeling: 'COLD'));
      final gateway = _RecordingGateway();
      final coordinator = WidgetRecommendationCoordinator(
        service: source,
        gateway: gateway,
      );

      final refresh = coordinator.refreshIfDue();
      await _until(() => source.calls == 1);
      coordinator.beginRecommendationMutation();
      first.complete(_recommendation(feeling: 'HOT'));
      await Future<void>.delayed(Duration.zero);
      expect(gateway.writes, isEmpty);

      coordinator.endRecommendationMutation(changed: true);
      expect(await refresh, WidgetRefreshResult.updated);

      expect(source.calls, 2);
      expect(gateway.writes.single.feeling, 'COLD');
    },
  );

  test('refresh waits for the mutation commit before fetching', () async {
    final source = _QueueSource()..enqueueValue(_recommendation());
    final coordinator = WidgetRecommendationCoordinator(
      service: source,
      gateway: _RecordingGateway(),
    );
    coordinator.beginRecommendationMutation();

    final refresh = coordinator.refreshIfDue();
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 0);

    coordinator.endRecommendationMutation(changed: true);
    expect(await refresh, WidgetRefreshResult.updated);
    expect(source.calls, 1);
  });

  test(
    'account close drains a native write then writes tombstone last',
    () async {
      final gateway = _RecordingGateway()..pauseWrite();
      final coordinator = WidgetRecommendationCoordinator(
        service: _QueueSource()..enqueueValue(_recommendation()),
        gateway: gateway,
      );

      final refresh = coordinator.refreshIfDue();
      await gateway.writeStarted.future;
      final close = coordinator.closeAccount();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.events, ['write:start']);

      gateway.releaseWrite();
      expect(await refresh, WidgetRefreshResult.closed);
      await close;

      expect(gateway.events, ['write:start', 'write:finish', 'close']);
      expect(
        await coordinator.refreshIfDue(force: true),
        WidgetRefreshResult.closed,
      );
    },
  );

  test(
    'close invalidates an old network lease before native storage',
    () async {
      final response = Completer<WidgetRecommendation>();
      final source = _QueueSource()..enqueueFuture(response.future);
      final gateway = _RecordingGateway();
      final coordinator = WidgetRecommendationCoordinator(
        service: source,
        gateway: gateway,
      );

      final refresh = coordinator.refreshIfDue();
      await _until(() => source.calls == 1);
      final close = coordinator.closeAccount();
      response.complete(_recommendation());

      expect(await refresh, WidgetRefreshResult.closed);
      await close;
      expect(gateway.writes, isEmpty);
      expect(gateway.events, ['close']);
    },
  );

  test(
    'deactivate fences a disposed account response without native writes',
    () async {
      final response = Completer<WidgetRecommendation>();
      final source = _QueueSource()..enqueueFuture(response.future);
      final gateway = _RecordingGateway();
      final coordinator = WidgetRecommendationCoordinator(
        service: source,
        gateway: gateway,
      );

      final refresh = coordinator.refreshIfDue();
      await _until(() => source.calls == 1);
      coordinator.deactivate();
      await gateway.closeAccount();
      response.complete(_recommendation());

      expect(await refresh, WidgetRefreshResult.closed);
      expect(gateway.writes, isEmpty);
      expect(gateway.events, ['close']);
    },
  );

  test(
    'concurrent close calls share one generation and native boundary',
    () async {
      final gateway = _RecordingGateway()..pauseClose();
      final coordinator = WidgetRecommendationCoordinator(
        service: _QueueSource(),
        gateway: gateway,
      );

      final first = coordinator.closeAccount();
      await gateway.closeStarted.future;
      final second = coordinator.closeAccount();
      expect(identical(first, second), isTrue);

      gateway.releaseClose();
      await Future.wait([first, second]);
      expect(gateway.events, ['close']);
    },
  );

  test('deactivate prevents a failed in-flight close from reopening', () async {
    final gateway = _RecordingGateway()
      ..pauseClose()
      ..closeError = StateError('close failed');
    final coordinator = WidgetRecommendationCoordinator(
      service: _QueueSource()..enqueueValue(_recommendation()),
      gateway: gateway,
    );

    final close = coordinator.closeAccount();
    await gateway.closeStarted.future;
    coordinator.deactivate();
    gateway.releaseClose();

    await expectLater(close, throwsStateError);
    expect(
      await coordinator.refreshIfDue(force: true),
      WidgetRefreshResult.closed,
    );
    expect(gateway.writes, isEmpty);
  });

  test('deactivate releases a mutation-gated worker as closed', () async {
    final coordinator = WidgetRecommendationCoordinator(
      service: _QueueSource()..enqueueValue(_recommendation()),
      gateway: _RecordingGateway(),
    );
    coordinator.beginRecommendationMutation();
    final refresh = coordinator.refreshIfDue(force: true);

    coordinator.deactivate();

    expect(await refresh, WidgetRefreshResult.closed);
    coordinator.endRecommendationMutation(changed: true);
  });

  test('native close failure is surfaced so auth can be preserved', () async {
    final source = _QueueSource()..enqueueValue(_recommendation());
    final gateway = _RecordingGateway()..closeError = StateError('disk full');
    final coordinator = WidgetRecommendationCoordinator(
      service: source,
      gateway: gateway,
    );

    await expectLater(coordinator.closeAccount(), throwsStateError);
    expect(gateway.writes, isEmpty);
    expect(await coordinator.refreshIfDue(), WidgetRefreshResult.updated);
    expect(source.calls, 1);

    gateway.closeError = null;
    await coordinator.closeAccount();
    expect(gateway.events.last, 'close');
    expect(
      await coordinator.refreshIfDue(force: true),
      WidgetRefreshResult.closed,
    );
  });

  test(
    'offline close rollback remains open for a later forced restore',
    () async {
      final source = _QueueSource()
        ..enqueueError(StateError('offline'))
        ..enqueueValue(_recommendation(feeling: 'COOL'));
      final gateway = _RecordingGateway()
        ..closeError = StateError('reload failed');
      final coordinator = WidgetRecommendationCoordinator(
        service: source,
        gateway: gateway,
      );

      await expectLater(coordinator.closeAccount(), throwsStateError);
      expect(await coordinator.refreshIfDue(), WidgetRefreshResult.unavailable);
      expect(source.calls, 1);
      gateway.closeError = null;

      expect(
        await coordinator.refreshIfDue(force: true),
        WidgetRefreshResult.updated,
      );
      expect(gateway.writes.single.feeling, 'COOL');
    },
  );
}

WidgetRecommendation _recommendation({String feeling = 'PERFECT'}) {
  return WidgetRecommendation(
    date: DateTime(2026, 7, 31),
    validUntil: DateTime.utc(2026, 7, 31, 15),
    feeling: feeling,
    top: ClothingTop.shortSleeve,
    bottom: ClothingBottom.longPants,
    outer: ClothingOuter.lightOuter,
  );
}

class _QueueSource implements WidgetRecommendationSource {
  final _responses = Queue<Future<WidgetRecommendation> Function()>();
  var calls = 0;

  void enqueueValue(WidgetRecommendation value) {
    _responses.add(() async => value);
  }

  void enqueueFuture(Future<WidgetRecommendation> value) {
    _responses.add(() => value);
  }

  void enqueueError(Object error) {
    _responses.add(() async => throw error);
  }

  @override
  Future<WidgetRecommendation> getToday() {
    calls += 1;
    return _responses.removeFirst()();
  }
}

class _RecordingGateway implements WidgetSnapshotGateway {
  final events = <String>[];
  final writes = <WidgetRecommendation>[];
  var writeStarted = Completer<void>();
  var closeStarted = Completer<void>();
  Completer<void>? _writeGate;
  Completer<void>? _closeGate;
  Object? closeError;

  void pauseWrite() {
    writeStarted = Completer<void>();
    _writeGate = Completer<void>();
  }

  void releaseWrite() {
    _writeGate?.complete();
    _writeGate = null;
  }

  void pauseClose() {
    closeStarted = Completer<void>();
    _closeGate = Completer<void>();
  }

  void releaseClose() {
    _closeGate?.complete();
    _closeGate = null;
  }

  @override
  Future<void> writeReady(WidgetRecommendation recommendation) async {
    events.add('write:start');
    if (!writeStarted.isCompleted) writeStarted.complete();
    final gate = _writeGate;
    if (gate != null) await gate.future;
    writes.add(recommendation);
    events.add('write:finish');
  }

  @override
  Future<void> closeAccount() async {
    events.add('close');
    if (!closeStarted.isCompleted) closeStarted.complete();
    final gate = _closeGate;
    if (gate != null) await gate.future;
    final error = closeError;
    if (error != null) throw error;
  }

  @override
  Future<bool> consumeInitialHomeRoute() async => false;

  @override
  void setHomeRouteHandler(WidgetHomeRouteHandler? handler) {}
}

Future<void> _until(bool Function() condition) async {
  for (var index = 0; index < 20 && !condition(); index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
