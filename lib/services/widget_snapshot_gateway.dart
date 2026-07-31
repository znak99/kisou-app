import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/widget_recommendation.dart';

typedef WidgetHomeRouteHandler = void Function();

abstract interface class WidgetSnapshotGateway {
  Future<void> writeReady(WidgetRecommendation recommendation);

  /// Atomically replaces account data with a durable signed-out tombstone,
  /// clears any cold-start widget route, and asks native widgets to reload.
  ///
  /// Completion means all three steps completed. Mobile failures must surface
  /// so the account-transition coordinator can preserve auth and retry.
  Future<void> closeAccount();

  Future<bool> consumeInitialHomeRoute();

  void setHomeRouteHandler(WidgetHomeRouteHandler? handler);
}

class MethodChannelWidgetSnapshotGateway implements WidgetSnapshotGateway {
  MethodChannelWidgetSnapshotGateway({
    MethodChannel channel = const MethodChannel('jp.kisou/widget'),
  }) : _channel = channel;

  final MethodChannel _channel;
  WidgetHomeRouteHandler? _routeHandler;
  var _routeGeneration = 0;
  var _accountEpoch = 0;
  var _routesEnabled = true;

  @override
  Future<void> writeReady(WidgetRecommendation recommendation) async {
    final envelope = jsonEncode(recommendation.toReadyEnvelopeJson());
    final accountEpoch = _accountEpoch;
    try {
      await _channel.invokeMethod<void>('writeSnapshot', envelope);
      if (accountEpoch == _accountEpoch && !_routesEnabled) {
        _routeGeneration += 1;
        _routesEnabled = true;
      }
    } on MissingPluginException {
      if (_isMobileProcess) rethrow;
      if (accountEpoch == _accountEpoch && !_routesEnabled) {
        _routeGeneration += 1;
        _routesEnabled = true;
      }
    }
  }

  @override
  Future<void> closeAccount() async {
    final routesWereEnabled = _routesEnabled;
    _accountEpoch += 1;
    final closeEpoch = _accountEpoch;
    _routeGeneration += 1;
    _routesEnabled = false;
    try {
      await _channel.invokeMethod<void>('closeAccount');
    } on MissingPluginException {
      if (_isMobileProcess) {
        _restoreRouteLeaseAfterCloseFailure(routesWereEnabled, closeEpoch);
        rethrow;
      }
    } catch (_) {
      _restoreRouteLeaseAfterCloseFailure(routesWereEnabled, closeEpoch);
      rethrow;
    }
    if (closeEpoch == _accountEpoch) {
      _routeGeneration += 1;
      _routesEnabled = false;
    }
  }

  @override
  Future<bool> consumeInitialHomeRoute() async {
    final generation = _routeGeneration;
    try {
      final pending =
          await _channel.invokeMethod<bool>('consumeInitialWidgetRoute') ??
          false;
      return pending && _routesEnabled && generation == _routeGeneration;
    } on MissingPluginException {
      if (_isMobileProcess) rethrow;
      return false;
    }
  }

  @override
  void setHomeRouteHandler(WidgetHomeRouteHandler? handler) {
    _routeGeneration += 1;
    _routeHandler = handler;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'widgetHomeRoute') {
        throw MissingPluginException('Unknown widget callback.');
      }
      // A native pending route remains durable until Dart acknowledges it.
      final generation = _routeGeneration;
      final pending = await consumeInitialHomeRoute();
      if (pending && _routesEnabled && generation == _routeGeneration) {
        _routeHandler?.call();
      }
    });
  }

  void _restoreRouteLeaseAfterCloseFailure(
    bool routesWereEnabled,
    int closeEpoch,
  ) {
    if (closeEpoch != _accountEpoch) return;
    _routeGeneration += 1;
    _routesEnabled = routesWereEnabled;
  }
}

bool get _isMobileProcess => Platform.isAndroid || Platform.isIOS;
