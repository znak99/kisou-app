import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import '../models/push_notification.dart';

const pushPermissionPromptCountStorageKey = 'push_permission_prompt_count_v1';
const pushDeliveryReceiptStorageKey = 'push_delivery_receipts_v3';

class PushPermissionHistory {
  PushPermissionHistory({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesFactory;

  Future<int> readCount() async {
    final value =
        (await _preferencesFactory()).getInt(
          pushPermissionPromptCountStorageKey,
        ) ??
        0;
    return value < 0 ? 0 : value;
  }

  Future<int> recordPrompt() async {
    final preferences = await _preferencesFactory();
    final current =
        preferences.getInt(pushPermissionPromptCountStorageKey) ?? 0;
    final next = current < 2 ? current + 1 : 2;
    await preferences.setInt(pushPermissionPromptCountStorageKey, next);
    return next;
  }
}

enum PushDeliveryReceiptStage { foreground, navigationPending, navigated }

class PushDeliveryReceiptStore {
  PushDeliveryReceiptStore({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  static const maxReceipts = 64;
  static final _lock = Lock();

  final Future<SharedPreferences> Function() _preferencesFactory;

  Future<bool> markForegroundIfNew(PushNotificationIntent intent) {
    return _lock.synchronized(() async {
      final state = await _readState();
      if (state.receipts.any(
        (receipt) => receipt.deliveryId == intent.deliveryId,
      )) {
        return false;
      }
      state.receipts.add(
        _PushDeliveryReceipt(
          deliveryId: intent.deliveryId,
          type: intent.type,
          clientRevision: intent.clientRevision,
          stage: PushDeliveryReceiptStage.foreground,
        ),
      );
      await _writeState(state);
      return true;
    });
  }

  /// Reserves a route durably before it enters the in-memory navigation queue.
  ///
  /// A duplicate pending event is not queued twice in one process. A later
  /// process restores it through [pendingNavigations].
  Future<bool> reserveNavigation(PushNotificationIntent intent) {
    return _lock.synchronized(() async {
      final state = await _readState();
      final index = state.receipts.indexWhere(
        (receipt) => receipt.deliveryId == intent.deliveryId,
      );
      if (index >= 0) {
        final current = state.receipts[index];
        if (current.type != intent.type) {
          throw const PushDeliveryReceiptReadException();
        }
        if (current.clientRevision != intent.clientRevision) {
          throw const PushDeliveryReceiptReadException();
        }
        if (current.stage == PushDeliveryReceiptStage.navigated ||
            current.stage == PushDeliveryReceiptStage.navigationPending) {
          return false;
        }
        state.receipts[index] = _PushDeliveryReceipt(
          deliveryId: intent.deliveryId,
          type: intent.type,
          clientRevision: intent.clientRevision,
          stage: PushDeliveryReceiptStage.navigationPending,
        );
      } else {
        state.receipts.add(
          _PushDeliveryReceipt(
            deliveryId: intent.deliveryId,
            type: intent.type,
            clientRevision: intent.clientRevision,
            stage: PushDeliveryReceiptStage.navigationPending,
          ),
        );
      }
      await _writeState(state);
      return true;
    });
  }

  Future<List<PushNotificationIntent>> pendingNavigations() {
    return _lock.synchronized(() async {
      final state = await _readState();
      return List.unmodifiable([
        for (final receipt in state.receipts)
          if (receipt.stage == PushDeliveryReceiptStage.navigationPending)
            PushNotificationIntent(
              type: receipt.type,
              deliveryId: receipt.deliveryId,
              clientRevision: receipt.clientRevision,
            ),
      ]);
    });
  }

  Future<void> completeNavigation(String deliveryId) {
    return _lock.synchronized(() async {
      final state = await _readState();
      final index = state.receipts.indexWhere(
        (receipt) => receipt.deliveryId == deliveryId,
      );
      if (index < 0 ||
          state.receipts[index].stage !=
              PushDeliveryReceiptStage.navigationPending) {
        throw const PushDeliveryReceiptReadException();
      }
      final current = state.receipts[index];
      state.receipts[index] = _PushDeliveryReceipt(
        deliveryId: current.deliveryId,
        type: current.type,
        clientRevision: current.clientRevision,
        stage: PushDeliveryReceiptStage.navigated,
      );
      await _writeState(state);
    });
  }

  /// Discards unfinished routes at an account boundary while preserving IDs,
  /// so an already delivered notification cannot route for the next user.
  Future<void> discardUnfinished() {
    return _lock.synchronized(() async {
      final state = await _readState();
      await _discardUnfinishedState(state);
    });
  }

  /// Closes consume-once state after the durable push account boundary exists.
  ///
  /// Corrupt receipt JSON is safe to remove only here: the higher unregister
  /// revision (or a fresh revision-zero record after conservative Firebase
  /// cleanup) rejects every payload issued for the previous account.
  Future<void> discardUnfinishedAtAccountBoundary() {
    return _lock.synchronized(() async {
      final preferences = await _preferencesFactory();
      try {
        final state = _PushDeliveryReceiptState(
          preferences: preferences,
          receipts: _decode(
            preferences.getString(pushDeliveryReceiptStorageKey),
          ),
        );
        await _discardUnfinishedState(state);
      } on PushDeliveryReceiptReadException {
        final removed = await preferences.remove(pushDeliveryReceiptStorageKey);
        if (!removed &&
            preferences.containsKey(pushDeliveryReceiptStorageKey)) {
          throw const PushDeliveryReceiptWriteException();
        }
      }
    });
  }

  Future<void> _discardUnfinishedState(_PushDeliveryReceiptState state) async {
    var changed = false;
    for (var index = 0; index < state.receipts.length; index++) {
      final current = state.receipts[index];
      if (current.stage == PushDeliveryReceiptStage.navigated) {
        continue;
      }
      changed = true;
      state.receipts[index] = _PushDeliveryReceipt(
        deliveryId: current.deliveryId,
        type: current.type,
        clientRevision: current.clientRevision,
        stage: PushDeliveryReceiptStage.navigated,
      );
    }
    if (changed) {
      await _writeState(state);
    }
  }

  Future<_PushDeliveryReceiptState> _readState() async {
    final preferences = await _preferencesFactory();
    return _PushDeliveryReceiptState(
      preferences: preferences,
      receipts: _decode(preferences.getString(pushDeliveryReceiptStorageKey)),
    );
  }

  Future<void> _writeState(_PushDeliveryReceiptState state) async {
    while (state.receipts.length > maxReceipts) {
      state.receipts.removeAt(0);
    }
    final encoded = jsonEncode({
      'version': 3,
      'receipts': [
        for (final receipt in state.receipts)
          {
            'delivery_id': receipt.deliveryId,
            'type': _encodeType(receipt.type),
            'client_revision': receipt.clientRevision,
            'stage': receipt.stage.name,
          },
      ],
    });
    final written = await state.preferences.setString(
      pushDeliveryReceiptStorageKey,
      encoded,
    );
    if (!written) {
      throw const PushDeliveryReceiptWriteException();
    }
  }

  List<_PushDeliveryReceipt> _decode(String? encoded) {
    if (encoded == null) {
      return [];
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          decoded['version'] != 3 ||
          decoded['receipts'] is! List<dynamic>) {
        throw const FormatException('Invalid push delivery receipts.');
      }
      final rawReceipts = decoded['receipts'] as List<dynamic>;
      if (rawReceipts.length > maxReceipts) {
        throw const FormatException('Too many push delivery receipts.');
      }
      final seen = <String>{};
      return [for (final raw in rawReceipts) _decodeReceipt(raw, seen)];
    } on FormatException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const PushDeliveryReceiptReadException(),
        stackTrace,
      );
    }
  }

  _PushDeliveryReceipt _decodeReceipt(Object? value, Set<String> seen) {
    if (value is! Map<String, dynamic> ||
        value.length != 4 ||
        value['delivery_id'] is! String ||
        !_uuidV4Pattern.hasMatch(value['delivery_id'] as String) ||
        !seen.add(value['delivery_id'] as String)) {
      throw const FormatException('Invalid push delivery receipt.');
    }
    final clientRevision = value['client_revision'];
    if (clientRevision is! int ||
        clientRevision < 1 ||
        clientRevision > PushNotificationIntent.maxPushClientRevision) {
      throw const FormatException('Invalid receipt client revision.');
    }
    final stage = switch (value['stage']) {
      'foreground' => PushDeliveryReceiptStage.foreground,
      'navigationPending' => PushDeliveryReceiptStage.navigationPending,
      'navigated' => PushDeliveryReceiptStage.navigated,
      _ => throw const FormatException('Invalid push delivery stage.'),
    };
    final type = switch (value['type']) {
      'morning_recommendation' => PushNotificationType.morningRecommendation,
      'evening_feedback' => PushNotificationType.eveningFeedback,
      _ => throw const FormatException('Invalid push delivery type.'),
    };
    return _PushDeliveryReceipt(
      deliveryId: value['delivery_id'] as String,
      type: type,
      clientRevision: clientRevision,
      stage: stage,
    );
  }
}

class _PushDeliveryReceipt {
  const _PushDeliveryReceipt({
    required this.deliveryId,
    required this.type,
    required this.clientRevision,
    required this.stage,
  });

  final String deliveryId;
  final PushNotificationType type;
  final int clientRevision;
  final PushDeliveryReceiptStage stage;
}

class _PushDeliveryReceiptState {
  const _PushDeliveryReceiptState({
    required this.preferences,
    required this.receipts,
  });

  final SharedPreferences preferences;
  final List<_PushDeliveryReceipt> receipts;
}

class PushDeliveryReceiptReadException implements Exception {
  const PushDeliveryReceiptReadException();
}

class PushDeliveryReceiptWriteException implements Exception {
  const PushDeliveryReceiptWriteException();
}

String _encodeType(PushNotificationType type) {
  return switch (type) {
    PushNotificationType.morningRecommendation => 'morning_recommendation',
    PushNotificationType.eveningFeedback => 'evening_feedback',
  };
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
