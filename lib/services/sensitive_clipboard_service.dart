import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Copies a sensitive value and removes it after a short period when it has not
/// been replaced by the user in the meantime.
class SensitiveClipboardService {
  SensitiveClipboardService({
    Duration clearAfter = const Duration(seconds: 60),
    Future<void> Function(String value)? write,
    Future<String?> Function()? read,
  }) : _clearAfter = clearAfter,
       _write =
           write ?? ((value) => Clipboard.setData(ClipboardData(text: value))),
       _read =
           read ??
           (() async {
             final data = await Clipboard.getData(Clipboard.kTextPlain);
             return data?.text;
           });

  final Duration _clearAfter;
  final Future<void> Function(String value) _write;
  final Future<String?> Function() _read;

  Timer? _clearTimer;
  Digest? _lastSensitiveFingerprint;
  Future<void> _pendingWrite = Future<void>.value();
  var _copyRevision = 0;
  static const _retryAfterCleanupFailure = Duration(seconds: 5);

  Future<int> copy(String value) async {
    final copyRevision = ++_copyRevision;
    _lastSensitiveFingerprint = _fingerprint(value);
    _scheduleClear(copyRevision, _clearAfter);
    try {
      await _writeSerially(value);
      return copyRevision;
    } catch (error, stackTrace) {
      await _clearBestEffort(copyRevision);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> clearIfUnchanged() {
    return _clearRevisionIfUnchanged(_copyRevision);
  }

  Future<void> clearCopyIfUnchanged(int copyRevision) {
    return _clearRevisionIfUnchanged(copyRevision);
  }

  Future<void> _clearRevisionIfUnchanged(int copyRevision) async {
    if (copyRevision != _copyRevision) {
      return;
    }
    final expected = _lastSensitiveFingerprint;
    _clearTimer?.cancel();
    _clearTimer = null;
    if (expected == null) {
      return;
    }
    try {
      await _pendingWrite;
      if (copyRevision != _copyRevision) {
        return;
      }
      final current = await _read();
      if (copyRevision != _copyRevision) {
        return;
      }
      if (current != null && _fingerprint(current) == expected) {
        await _writeSerially('');
      }
      if (copyRevision == _copyRevision) {
        _lastSensitiveFingerprint = null;
      }
    } catch (_) {
      if (copyRevision == _copyRevision && _lastSensitiveFingerprint != null) {
        _scheduleClear(copyRevision, _retryAfterCleanupFailure);
      }
      rethrow;
    }
  }

  Future<void> _writeSerially(String value) {
    final operation = _pendingWrite.then((_) => _write(value));
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void dispose() {
    unawaited(_clearBestEffort(_copyRevision));
  }

  Future<void> _clearBestEffort(int copyRevision) async {
    try {
      await _clearRevisionIfUnchanged(copyRevision);
    } catch (_) {
      // Timer/disposal cleanup cannot surface a platform clipboard failure.
    }
  }

  void _scheduleClear(int copyRevision, Duration delay) {
    _clearTimer?.cancel();
    _clearTimer = Timer(delay, () {
      unawaited(_clearBestEffort(copyRevision));
    });
  }

  Digest _fingerprint(String value) {
    return sha256.convert(utf8.encode(value));
  }
}
