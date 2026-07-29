import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/utils/jp_date.dart';
import 'package:kisou_app/widgets/feedback_sheet.dart';

void main() {
  testWidgets('shows the smaller time-slot error only after tapping next', (
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

    expect(find.text(AppStrings.feedbackWhenTitle), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    // 날짜·시간대가 독립된 첫 단계에 표시된다.
    expect(find.text(AppStrings.feedbackDateLabel), findsOneWidget);
    expect(find.text(AppStrings.feedbackTimeSlotsTitle), findsOneWidget);
    expect(find.text(AppStrings.slotMorning), findsOneWidget);
    expect(find.text('8〜11時'), findsOneWidget);
    expect(find.text('シャツ'), findsNothing);
    expect(find.text('ハーフパンツ'), findsNothing);
    expect(find.text('ショートパンツ'), findsNothing);
    expect(find.text('スカート'), findsNothing);
    expect(find.text(AppStrings.feedbackTimeSlotsRequired), findsNothing);
    expect(find.text(AppStrings.feedbackTimeSlotsHelp), findsOneWidget);

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    // 누락 오류는 버튼을 눌렀을 때만 표시되어야 하므로 활성 상태다.
    expect(nextButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
    await tester.pumpAndSettle();

    final timeError = tester.widget<Text>(
      find.text(AppStrings.feedbackTimeSlotsRequired),
    );
    expect(timeError.style?.fontSize, 11);
    expect(find.text(AppStrings.feedbackTimeSlotsHelp), findsNothing);
    expect(find.text(AppStrings.feedbackFeelingTitle), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.slotMorning));
    await tester.tap(find.text(AppStrings.slotMorning));
    await tester.pump();
    expect(find.text(AppStrings.feedbackTimeSlotsRequired), findsNothing);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
    await tester.pump();
    expect(find.text(AppStrings.feedbackClothingTitle), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    // 남성 프로필도 실제 착용 기록에서는 모든 하의를 선택할 수 있다.
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -360));
    await tester.pump();
    expect(find.text('半ズボン'), findsOneWidget);
    expect(find.text('ショートパンツ'), findsOneWidget);
    expect(find.text('スカート'), findsOneWidget);
  });

  testWidgets('switches within the sheet and restores a recent saved record', (
    WidgetTester tester,
  ) async {
    final today = jstToday();
    final yesterday = today.subtract(const Duration(days: 1));
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/feedback/today') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'exists': false, 'feedback': null},
              ),
            );
            return;
          }
          if (options.path == '/feedback/recent') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'days': [
                    for (var daysAgo = 0; daysAgo < 8; daysAgo++)
                      {
                        'date': formatIsoDate(
                          today.subtract(Duration(days: daysAgo)),
                        ),
                        'feedback': daysAgo == 1
                            ? {
                                'id': 'saved-feedback',
                                'date': formatIsoDate(yesterday),
                                'feedback_value': 'perfect',
                                'actual_top': 'LONG_SLEEVE',
                                'actual_bottom': 'LONG_PANTS',
                                'actual_outer': null,
                                'time_slots': ['MORNING'],
                                'created_at': '2026-07-28T00:00:00Z',
                                'updated_at': '2026-07-28T00:00:00Z',
                              }
                            : null,
                      },
                  ],
                },
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Unexpected request: ${options.path}',
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: const MaterialApp(
          home: Scaffold(
            body: FeedbackSheet(gender: 'male', initialFeedback: null),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('${AppStrings.feedbackDateToday} ${formatJpDate(today)}'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackDateSelectTitle), findsOneWidget);
    expect(find.text(AppStrings.feedbackDateYesterday), findsOneWidget);
    expect(find.text(AppStrings.feedbackRecorded), findsOneWidget);

    await tester.tap(find.text(AppStrings.feedbackDateYesterday));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackWhenTitle), findsOneWidget);
    expect(find.text(AppStrings.feedbackEditingSaved), findsOneWidget);
    expect(find.text(formatJpDate(yesterday)), findsOneWidget);
  });
}
