import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/providers/travel_plan_provider.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:kisou_app/screens/forecast/travel_plans_screen.dart';
import 'package:kisou_app/services/travel_notification_service.dart';

void main() {
  testWidgets('shows a saved offline plan and its notification state', (
    tester,
  ) async {
    final repository = MemoryTravelPlanRepository(
      now: () => DateTime.utc(2026, 7, 31),
    );
    final notifications = MemoryTravelNotificationGateway();
    final container = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelPlanProvider.future);
    await container
        .read(travelPlanProvider.notifier)
        .create(
          TravelPlanDraft(
            cityCode: 'tokyo',
            departureAtUtc: DateTime.utc(2030, 8, 10),
            reminder: TravelReminder.dayBefore,
          ),
          requestNotificationPermission: true,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const TravelPlansScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('東京'), findsOneWidget);
    expect(find.text(AppStrings.travelNotificationScheduled), findsOneWidget);
    expect(find.byTooltip(AppStrings.travelDelete), findsOneWidget);
  });

  testWidgets('missing notification target fails safely', (tester) async {
    final container = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const TravelPlansScreen(focusPlanId: 999),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.travelPlanNotFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an explicit error when the selected reminder is past', (
    tester,
  ) async {
    final repository = MemoryTravelPlanRepository();
    final container = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelPlanProvider.future);
    await container
        .read(travelPlanProvider.notifier)
        .create(
          TravelPlanDraft(
            cityCode: 'tokyo',
            departureAtUtc: DateTime.now().toUtc().add(
              const Duration(hours: 1),
            ),
            reminder: TravelReminder.none,
          ),
          requestNotificationPermission: false,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: KisouTheme.light(),
          home: const TravelPlansScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.travelEdit));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TravelReminder>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.travelReminderThreeHours).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.travelUpdate));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.travelReminderNotFuture), findsOneWidget);
  });

  for (final width in [320.0, 375.0, 430.0]) {
    for (final textScale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'summary, manager and editor fit ${width.toInt()}dp at ${textScale}x',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 568);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          final repository = MemoryTravelPlanRepository(
            now: () => DateTime.utc(2026, 7, 31),
          );
          await repository.create(
            TravelPlanDraft(
              cityCode: 'tokyo',
              departureAtUtc: DateTime.utc(2030, 8, 10),
              reminder: TravelReminder.none,
            ),
          );
          final container = ProviderContainer(
            overrides: [
              travelPlanRepositoryProvider.overrideWithValue(repository),
              travelNotificationGatewayProvider.overrideWithValue(
                MemoryTravelNotificationGateway(),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: KisouTheme.light(),
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: child!,
                  );
                },
                home: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: TravelUpcomingSection(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text(AppStrings.travelManage));
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.travelEdit), findsOneWidget);
          expect(find.byTooltip(AppStrings.travelDelete), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.text(AppStrings.travelEdit));
          await tester.tap(find.text(AppStrings.travelEdit));
          await tester.pumpAndSettle();
          final reminderField = find.byType(
            DropdownButtonFormField<TravelReminder>,
          );
          await tester.scrollUntilVisible(
            reminderField,
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(reminderField, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
