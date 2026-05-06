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
    expect(find.text('シャツ'), findsNothing);
    expect(find.text('ショートパンツ'), findsNothing);
    expect(find.text('スカート'), findsNothing);
    expect(find.text(AppStrings.noOuter), findsWidgets);

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.text('半袖').first);
    await tester.pump();
    await tester.tap(find.text('長ズボン').first);
    await tester.pump();

    final enabledNextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(enabledNextButton.onPressed, isNotNull);
  });
}
