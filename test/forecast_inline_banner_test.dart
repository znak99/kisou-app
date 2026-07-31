import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/shell_provider.dart';
import 'package:kisou_app/services/ad_gateway.dart';
import 'package:kisou_app/widgets/forecast_inline_banner.dart';

void main() {
  testWidgets('loaded banner uses platform height and hidden tab disposes it', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('banner', height: 57);
    final gateway = _FakeBannerGateway()..results.add(handle);
    final container = _container(gateway);
    addTearDown(container.dispose);
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump();

    expect(find.text('banner'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('surface-banner'))).height,
      57,
    );

    container.read(shellTabProvider.notifier).setTab(ShellTab.home);
    await tester.pump();
    expect(find.text('banner'), findsNothing);
    await tester.pump();
    expect(handle.disposeCalls, 1);
  });

  testWidgets('disabled state occupies zero space and makes no ad request', (
    tester,
  ) async {
    final gateway = _FakeBannerGateway();
    final container = _container(gateway, ready: false);
    addTearDown(container.dispose);
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);

    await tester.pumpWidget(_app(container));
    await tester.pump();

    expect(tester.getSize(find.byType(ForecastInlineBanner)).height, 0);
    expect(gateway.loadCalls, 0);
  });

  testWidgets('native disposal failure is contained after banner removal', (
    tester,
  ) async {
    final handle = _FakeBannerHandle(
      'banner',
      disposeError: StateError('native disposal failed'),
    );
    final gateway = _FakeBannerGateway()..results.add(handle);
    final container = _container(gateway);
    addTearDown(container.dispose);
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump();
    container.read(shellTabProvider.notifier).setTab(ShellTab.home);
    await tester.pump();
    await tester.pump();

    expect(handle.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale hidden-tab load is disposed and never mounted', (
    tester,
  ) async {
    final first = Completer<InlineBannerHandle>();
    final second = Completer<InlineBannerHandle>();
    final gateway = _FakeBannerGateway()
      ..results.addAll([first.future, second.future]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    expect(gateway.loadCalls, 1);

    container.read(shellTabProvider.notifier).setTab(ShellTab.home);
    await tester.pump();
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);
    await tester.pump();
    expect(gateway.loadCalls, 2);

    final stale = _FakeBannerHandle('stale');
    first.complete(stale);
    await tester.pump();
    await tester.pump();
    expect(stale.disposeCalls, 1);
    expect(find.text('stale'), findsNothing);

    second.complete(_FakeBannerHandle('current'));
    await tester.pump();
    await tester.pump();
    expect(find.text('current'), findsOneWidget);
  });

  testWidgets('no-fill retries are bounded and leave zero space', (
    tester,
  ) async {
    final gateway = _FakeBannerGateway()
      ..results.addAll(List<Object>.filled(4, StateError('no fill')));
    final container = _container(gateway, zeroRetryDelays: true);
    addTearDown(container.dispose);
    container.read(shellTabProvider.notifier).setTab(ShellTab.forecast);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 4);
    expect(tester.getSize(find.byType(ForecastInlineBanner)).height, 0);
  });
}

ProviderContainer _container(
  _FakeBannerGateway gateway, {
  bool ready = true,
  bool zeroRetryDelays = false,
}) {
  return ProviderContainer(
    overrides: [
      adsRuntimePolicyProvider.overrideWithValue(
        const AdsRuntimePolicy(
          enabled: true,
          platform: KisouAdPlatform.android,
          ids: AdConfig.androidSamples,
          usesOfficialTestAds: true,
        ),
      ),
      adGatewayProvider.overrideWithValue(gateway),
      adsProvider.overrideWith(() => _ReadyAdsController(ready: ready)),
      if (zeroRetryDelays)
        bannerRetryDelaysProvider.overrideWithValue(const [
          Duration.zero,
          Duration.zero,
          Duration.zero,
        ]),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 320, child: ForecastInlineBanner()),
        ),
      ),
    ),
  );
}

class _ReadyAdsController extends AdsController {
  _ReadyAdsController({required this.ready});

  final bool ready;

  @override
  AdsState build() {
    return AdsState(
      enabled: true,
      consentInProgress: false,
      canRequestAds: ready,
      sdkInitialized: ready,
      privacyOptionsRequired: false,
      generation: 1,
    );
  }
}

class _FakeBannerGateway implements AdGateway {
  final List<Object> results = [];
  int loadCalls = 0;

  @override
  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  }) async {
    loadCalls++;
    final result = results.removeAt(0);
    if (result is Future<InlineBannerHandle>) {
      return result;
    }
    if (result is InlineBannerHandle) {
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
  Future<RewardedAdHandle> loadRewarded({required String adUnitId}) =>
      throw UnimplementedError();

  @override
  Future<void> requestConsentInfoUpdate() => throw UnimplementedError();

  @override
  Future<void> showPrivacyOptionsForm() => throw UnimplementedError();
}

class _FakeBannerHandle implements InlineBannerHandle {
  _FakeBannerHandle(this.label, {this.height = 50, this.disposeError});

  final String label;
  final Object? disposeError;
  @override
  final double height;
  int disposeCalls = 0;

  @override
  Widget buildWidget() =>
      SizedBox.expand(key: ValueKey('surface-$label'), child: Text(label));

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (disposeError case final error?) {
      throw error;
    }
  }
}
