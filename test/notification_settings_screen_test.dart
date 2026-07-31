import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/providers/push_provider.dart';
import 'package:kisou_app/screens/profile/notification_settings_screen.dart';

void main() {
  testWidgets('notification settings reflow at 320dp and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const state = PushSettingsState(
      available: true,
      preferences: PushPreferences(
        morningEnabled: true,
        morningTime: NotificationTime(hour: 7, minute: 0),
        eveningEnabled: true,
        eveningTime: NotificationTime(hour: 20, minute: 0),
      ),
      permission: PushPermissionState.blocked,
      registrationReady: false,
    );
    await _pump(tester, state);

    expect(find.text(AppStrings.pushMorningTitle), findsOneWidget);
    expect(find.text(AppStrings.pushPermissionBlocked), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.fling(
      find.byType(ListView),
      const Offset(0, -3000),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.pushEveningTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime-unavailable state remains usable and offers retry', (
    tester,
  ) async {
    await _pump(tester, const PushSettingsState.unavailable());

    expect(find.text(AppStrings.pushUnavailable), findsOneWidget);
    expect(find.widgetWithText(FilledButton, AppStrings.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, PushSettingsState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushSettingsProvider.overrideWith(
          () => _StaticPushSettingsController(state),
        ),
      ],
      child: MaterialApp(
        theme: KisouTheme.light(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: const NotificationSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _StaticPushSettingsController extends PushSettingsController {
  _StaticPushSettingsController(this.fixedState);

  final PushSettingsState fixedState;

  @override
  Future<PushSettingsState> build() async => fixedState;
}
