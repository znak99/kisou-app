import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/clothing_tags.dart';
import 'package:kisou_app/models/widget_recommendation.dart';
import 'package:kisou_app/services/widget_snapshot_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jp.kisou/widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('writes only the strict privacy-minimized ready envelope', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    await gateway.writeReady(_recommendation());

    expect(captured?.method, 'writeSnapshot');
    final raw = captured!.arguments as String;
    expect(
      raw,
      '{"schema_version":1,"state":"ready","date":"2026-07-31",'
      '"valid_until":"2026-07-31T15:00:00Z","feeling":"PERFECT",'
      '"recommendation":{"top":"SHORT_SLEEVE","bottom":"LONG_PANTS",'
      '"outer":null}}',
    );
    final envelope = jsonDecode(raw);
    expect(envelope, {
      'schema_version': 1,
      'state': 'ready',
      'date': '2026-07-31',
      'valid_until': '2026-07-31T15:00:00Z',
      'feeling': 'PERFECT',
      'recommendation': {
        'top': 'SHORT_SLEEVE',
        'bottom': 'LONG_PANTS',
        'outer': null,
      },
    });
    for (final privateField in [
      'token',
      'nickname',
      'location',
      'weather',
      'context',
      'region',
    ]) {
      expect(raw, isNot(contains(privateField)));
    }
  });

  test('close disables routes until the next ready write succeeds', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'consumeInitialWidgetRoute') return true;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    await gateway.closeAccount();
    expect(await gateway.consumeInitialHomeRoute(), isFalse);
    await gateway.writeReady(_recommendation());
    expect(await gateway.consumeInitialHomeRoute(), isTrue);

    expect(calls.map((call) => call.method), [
      'closeAccount',
      'consumeInitialWidgetRoute',
      'writeSnapshot',
      'consumeInitialWidgetRoute',
    ]);
    expect(calls.first.arguments, isNull);
  });

  test('native storage failures remain visible to account cleanup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'WIDGET_STORAGE_FAILED');
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    await expectLater(
      gateway.closeAccount(),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'warm callback queues only after native pending acknowledgement',
    () async {
      final consume = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'consumeInitialWidgetRoute') return consume.future;
        return false;
      });
      final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);
      var routeCalls = 0;
      gateway.setHomeRouteHandler(() => routeCalls += 1);

      final response = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('widgetHomeRoute'),
        ),
        (_) => response.complete(),
      );
      await Future<void>.delayed(Duration.zero);
      expect(routeCalls, 0);

      consume.complete(true);
      await response.future;

      expect(routeCalls, 1);
      gateway.setHomeRouteHandler(null);
    },
  );

  test('warm callback with no native pending route is ignored', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeInitialWidgetRoute') return false;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);
    var routeCalls = 0;
    gateway.setHomeRouteHandler(() => routeCalls += 1);

    final response = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('widgetHomeRoute'),
      ),
      (_) => response.complete(),
    );
    await response.future;

    expect(routeCalls, 0);
  });

  test('close generation rejects a delayed prior-account callback', () async {
    final consume = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeInitialWidgetRoute') return consume.future;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);
    var routeCalls = 0;
    gateway.setHomeRouteHandler(() => routeCalls += 1);

    final response = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('widgetHomeRoute'),
      ),
      (_) => response.complete(),
    );
    await Future<void>.delayed(Duration.zero);
    await gateway.closeAccount();
    consume.complete(true);
    await response.future;
    expect(routeCalls, 0);

    await gateway.writeReady(_recommendation());
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeInitialWidgetRoute') return true;
      return null;
    });
    final readyResponse = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('widgetHomeRoute'),
      ),
      (_) => readyResponse.complete(),
    );
    await readyResponse.future;
    expect(routeCalls, 1);
  });

  test('handler replacement invalidates a delayed callback lease', () async {
    final consume = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeInitialWidgetRoute') return consume.future;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);
    var firstCalls = 0;
    var secondCalls = 0;
    gateway.setHomeRouteHandler(() => firstCalls += 1);

    final response = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('widgetHomeRoute'),
      ),
      (_) => response.complete(),
    );
    await Future<void>.delayed(Duration.zero);
    gateway.setHomeRouteHandler(() => secondCalls += 1);
    consume.complete(true);
    await response.future;

    expect(firstCalls, 0);
    expect(secondCalls, 0);
  });

  test('failed ready write does not reopen a closed route lease', () async {
    var failWrite = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'writeSnapshot' && failWrite) {
        throw PlatformException(code: 'WIDGET_STORAGE_FAILED');
      }
      if (call.method == 'consumeInitialWidgetRoute') return true;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    await gateway.closeAccount();
    failWrite = true;
    await expectLater(
      gateway.writeReady(_recommendation()),
      throwsA(isA<PlatformException>()),
    );
    expect(await gateway.consumeInitialHomeRoute(), isFalse);
  });

  test('an older ready completion cannot reopen a newer close epoch', () async {
    final write = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'writeSnapshot') {
        await write.future;
        return null;
      }
      if (call.method == 'consumeInitialWidgetRoute') return true;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    final staleWrite = gateway.writeReady(_recommendation());
    await Future<void>.delayed(Duration.zero);
    await gateway.closeAccount();
    write.complete();
    await staleWrite;

    expect(await gateway.consumeInitialHomeRoute(), isFalse);
  });

  test('failed close restores the previous account route lease', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'closeAccount') {
        throw PlatformException(code: 'WIDGET_STORAGE_FAILED');
      }
      if (call.method == 'consumeInitialWidgetRoute') return true;
      return null;
    });
    final gateway = MethodChannelWidgetSnapshotGateway(channel: channel);

    await expectLater(
      gateway.closeAccount(),
      throwsA(isA<PlatformException>()),
    );
    expect(await gateway.consumeInitialHomeRoute(), isTrue);
  });
}

WidgetRecommendation _recommendation() {
  return WidgetRecommendation(
    date: DateTime(2026, 7, 31),
    validUntil: DateTime.utc(2026, 7, 31, 15),
    feeling: 'PERFECT',
    top: ClothingTop.shortSleeve,
    bottom: ClothingBottom.longPants,
    outer: null,
  );
}
