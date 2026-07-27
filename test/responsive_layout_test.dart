import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/screens/onboarding/steps/gender_step.dart';
import 'package:kisou_app/screens/onboarding/steps/sensitivity_step.dart';

void main() {
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
}
