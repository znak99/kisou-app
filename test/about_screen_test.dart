import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/screens/profile/about_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('about screen shows app identity, version, and licenses', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: AppStrings.appName,
      packageName: 'ud.znak99.kisou',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(theme: KisouTheme.light(), home: const AboutKisouScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.aboutDescription), findsOneWidget);
    expect(find.text('1.2.3 (45)'), findsOneWidget);
    expect(find.text(AppStrings.openSourceLicenses), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
