import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/widgets/feedback_sheet.dart';

void main() {
  testWidgets('shows male feedback options and enables next after clothing', (
    WidgetTester tester,
  ) async {
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

    expect(find.text(AppStrings.feedbackClothingTitle), findsOneWidget);
    // 새 상단 섹션(날짜·시간대)이 먼저 보인다.
    expect(find.text(AppStrings.feedbackDateLabel), findsOneWidget);
    expect(find.text(AppStrings.feedbackTimeSlotsTitle), findsOneWidget);
    expect(find.text(AppStrings.slotMorning), findsOneWidget);
    expect(find.text('シャツ'), findsNothing);
    expect(find.text('ショートパンツ'), findsNothing);
    expect(find.text('スカート'), findsNothing);
    // 아우터 섹션은 접혀 내려갔으니 스크롤해서 확인.
    await tester.drag(
      find.text(AppStrings.feedbackTops),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text(AppStrings.noOuter), findsWidgets);

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(nextButton.onPressed, isNull);

    await tester.ensureVisible(find.text('半袖').first);
    await tester.pump();
    await tester.tap(find.text('半袖').first);
    await tester.pump();
    await tester.ensureVisible(find.text('長ズボン').first);
    await tester.pump();
    await tester.tap(find.text('長ズボン').first);
    await tester.pump();

    final enabledNextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(enabledNextButton.onPressed, isNotNull);
  });
}
