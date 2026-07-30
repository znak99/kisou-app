import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/app_links.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/providers/external_link_provider.dart';
import 'package:kisou_app/widgets/weather_data_attribution.dart';

void main() {
  testWidgets('shows both links and modification notice at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalUrlLauncherProvider.overrideWithValue((_) async => true),
        ],
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const Scaffold(body: WeatherDataAttribution()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(AppStrings.openMeteoDataAttributionSemantics),
      ),
      matchesSemantics(
        label: AppStrings.openMeteoDataAttributionSemantics,
        isLink: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(AppStrings.openMeteoLicenseSemantics),
      ),
      matchesSemantics(
        label: AppStrings.openMeteoLicenseSemantics,
        isLink: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('opens source and license URLs independently', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const Scaffold(body: WeatherDataAttribution()),
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.openMeteoDataAttribution));
    await tester.pump();
    await tester.tap(find.text(AppStrings.openMeteoLicense));
    await tester.pump();

    expect(launched, [
      AppLinks.openMeteo,
      AppLinks.creativeCommonsAttribution40,
    ]);
  });

  testWidgets('reports external-link failures', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalUrlLauncherProvider.overrideWithValue((_) async => false),
        ],
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const Scaffold(body: WeatherDataAttribution()),
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.openMeteoLicense));
    await tester.pump();

    expect(find.text(AppStrings.externalLinkOpenFailed), findsOneWidget);
  });
}
