import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/screens/forecast/outlook_screen.dart';
import 'package:kisou_app/screens/onboarding/steps/gender_step.dart';
import 'package:kisou_app/screens/onboarding/steps/sensitivity_step.dart';
import 'package:kisou_app/widgets/app_bottom_nav.dart';
import 'package:kisou_app/widgets/feedback_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding choices fit a short narrow screen at large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenderStep(
            selectedValue: null,
            onSelected: (_) {},
            onNext: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SensitivityStep(
            coldSensitivity: 'normal',
            heatSensitivity: 'normal',
            onColdSelected: (_) {},
            onHeatSelected: (_) {},
            onNext: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('major input screens fit the approved portrait phone matrix', (
    WidgetTester tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ];
    const scales = [1.0, 1.3, 2.0];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in sizes) {
      for (final scale in scales) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenderStep(
                selectedValue: null,
                onSelected: (_) {},
                onNext: () {},
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'gender ${size.width}×${size.height} / ${scale}x',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SensitivityStep(
                coldSensitivity: 'normal',
                heatSensitivity: 'normal',
                onColdSelected: (_) {},
                onHeatSelected: (_) {},
                onNext: () {},
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'sensitivity ${size.width}×${size.height} / ${scale}x',
        );

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: OutlookScreen())),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'outlook ${size.width}×${size.height} / ${scale}x',
        );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: FeedbackSheet(gender: 'male', initialFeedback: null),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'feedback ${size.width}×${size.height} / ${scale}x',
        );
      }
    }
  });

  testWidgets('outlook and feedback remain scrollable at 200% text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OutlookScreen())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(AppStrings.forecastOutlookEmptyBody),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.forecastOutlookEmptyBody), findsOneWidget);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FeedbackSheet(gender: 'male', initialFeedback: null),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(AppStrings.next),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.next), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation announces and activates the current tab', (
    WidgetTester tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    final currentTab = find.bySemanticsLabel(
      AppStrings.selectedTab(AppStrings.tabHome),
    );
    expect(
      tester.getSemantics(currentTab),
      matchesSemantics(
        label: AppStrings.selectedTab(AppStrings.tabHome),
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.bySemanticsLabel(AppStrings.tabForecast));
    expect(tappedIndex, 1);
  });
}
