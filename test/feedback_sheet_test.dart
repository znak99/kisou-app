import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/feedback.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/providers/home_provider.dart';
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
    expect(find.text(AppStrings.feedbackUseRecommendation), findsNothing);
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

  testWidgets('submits the pinned home context and explicitly applied rank', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submittedBody;
    final dio = _feedbackFlowDio(onSubmit: (body) => submittedBody = body);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: const _HomePrimedFeedbackSheet(),
      ),
    );
    await tester.pumpAndSettle();

    await _goToClothingStep(tester);
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.feedbackUseRecommendation),
    );
    await tester.pump();
    await _goToFeelingStep(tester);
    await tester.tap(find.text(AppStrings.feedbackCold));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.feedbackSave),
    );
    await tester.pumpAndSettle();

    expect(submittedBody?['recommendation_context'], 'pinned-home-context');
    expect(submittedBody?['applied_recommendation_rank'], 1);
    expect(submittedBody?['actual_top'], 'SHORT_SLEEVE');
    expect(submittedBody?['actual_bottom'], 'LONG_PANTS');
    expect(submittedBody?['actual_outer'], isNull);
  });

  testWidgets('keeps the sheet-open context across the JST midnight boundary', (
    WidgetTester tester,
  ) async {
    var currentDate = DateTime(2026, 7, 31);
    Map<String, dynamic>? submittedBody;
    final dio = _feedbackFlowDio(
      homeDate: '2026-07-31',
      onSubmit: (body) => submittedBody = body,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: _HomePrimedFeedbackSheet(todayProvider: () => currentDate),
      ),
    );
    await tester.pumpAndSettle();

    await _goToClothingStep(tester);
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.feedbackUseRecommendation),
    );
    await tester.pump();
    currentDate = DateTime(2026, 8, 1);
    await _goToFeelingStep(tester);
    await tester.tap(find.text(AppStrings.feedbackCold));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.feedbackSave),
    );
    await tester.pumpAndSettle();

    expect(submittedBody?['date'], '2026-07-31');
    expect(submittedBody?['recommendation_context'], 'pinned-home-context');
    expect(submittedBody?['applied_recommendation_rank'], 1);
  });

  testWidgets(
    'manual clothing change clears the applied rank but keeps context',
    (WidgetTester tester) async {
      Map<String, dynamic>? submittedBody;
      final dio = _feedbackFlowDio(onSubmit: (body) => submittedBody = body);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(dio)],
          child: const _HomePrimedFeedbackSheet(),
        ),
      );
      await tester.pumpAndSettle();

      await _goToClothingStep(tester);
      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          AppStrings.feedbackUseRecommendation,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('薄手の羽織り'));
      await tester.pump();
      await _goToFeelingStep(tester);
      await tester.tap(find.text(AppStrings.feedbackCold));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.feedbackSave),
      );
      await tester.pumpAndSettle();

      expect(submittedBody?['recommendation_context'], 'pinned-home-context');
      expect(submittedBody, isNot(contains('applied_recommendation_rank')));
      expect(submittedBody?['actual_outer'], 'LIGHT_OUTER');
    },
  );

  testWidgets('does not attach today home attribution to a past-date record', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submittedBody;
    final dio = _feedbackFlowDio(onSubmit: (body) => submittedBody = body);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: const _HomePrimedFeedbackSheet(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.feedbackDateYesterday));
    await tester.pumpAndSettle();
    await _goToClothingStep(tester);

    expect(find.text(AppStrings.feedbackUseRecommendation), findsNothing);
    await tester.tap(find.bySemanticsLabel(AppStrings.noOuter));
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('半袖'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.bySemanticsLabel('半袖'));
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('長ズボン'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.bySemanticsLabel('長ズボン'));
    await tester.pump();
    await _goToFeelingStep(tester);
    await tester.tap(find.text(AppStrings.feedbackCold));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.feedbackSave),
    );
    await tester.pumpAndSettle();

    expect(submittedBody, isNot(contains('recommendation_context')));
    expect(submittedBody, isNot(contains('applied_recommendation_rank')));
  });

  testWidgets('preserves a saved applied rank when editing a past record', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submittedBody;
    final dio = _feedbackFlowDio(onSubmit: (body) => submittedBody = body);
    final yesterday = jstToday().subtract(const Duration(days: 1));
    final saved = FeedbackResponse(
      id: 'saved-feedback',
      date: formatIsoDate(yesterday),
      feedbackValue: 'perfect',
      actualTop: 'SHORT_SLEEVE',
      actualBottom: 'LONG_PANTS',
      actualOuter: null,
      timeSlots: const ['MORNING'],
      appliedRecommendationRank: 1,
      createdAt: '2026-07-30T00:00:00Z',
      updatedAt: '2026-07-30T00:00:00Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(dio)],
        child: MaterialApp(
          home: Scaffold(
            body: FeedbackSheet(gender: 'male', initialFeedback: saved),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.feedbackUseRecommendation), findsNothing);
    await _goToFeelingStep(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.feedbackUpdateSave),
    );
    await tester.pumpAndSettle();

    expect(submittedBody, isNot(contains('recommendation_context')));
    expect(submittedBody?['applied_recommendation_rank'], 1);
  });
}

class _HomePrimedFeedbackSheet extends ConsumerWidget {
  const _HomePrimedFeedbackSheet({this.todayProvider});

  final DateTime Function()? todayProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return MaterialApp(
      home: Scaffold(
        body: home.when(
          data: (home) => FeedbackSheet(
            gender: 'male',
            initialFeedback: null,
            recommendationSnapshot: home,
            todayProvider: todayProvider,
          ),
          error: (error, _) => Text('$error'),
          loading: () => const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

Future<void> _goToClothingStep(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.slotMorning));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.feedbackClothingTitle), findsOneWidget);
}

Future<void> _goToFeelingStep(WidgetTester tester) async {
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, AppStrings.next),
  );
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.feedbackFeelingTitle), findsOneWidget);
}

Dio _feedbackFlowDio({
  required ValueChanged<Map<String, dynamic>> onSubmit,
  String? homeDate,
}) {
  final today = homeDate ?? formatIsoDate(jstToday());
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        switch (options.path) {
          case '/home':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'date': today,
                  'feeling': 'PERFECT',
                  'comfort_min': 18,
                  'comfort_max': 24,
                  'recommendations': [
                    {
                      'rank': 1,
                      'direction': 'primary',
                      'top': 'SHORT_SLEEVE',
                      'bottom': 'LONG_PANTS',
                      'outer': null,
                    },
                    {
                      'rank': 2,
                      'direction': 'warmer',
                      'top': 'THIN_LONG',
                      'bottom': 'LONG_PANTS',
                      'outer': 'LIGHT_OUTER',
                    },
                    {
                      'rank': 3,
                      'direction': 'lighter',
                      'top': 'SLEEVELESS',
                      'bottom': 'SHORT_PANTS',
                      'outer': null,
                    },
                  ],
                  'recommendation_context': 'pinned-home-context',
                  'applied_time_slots': ['MORNING'],
                  'hours_analyzed': 4,
                  'weather_comparison': {
                    'today': _weatherSummary(),
                    'yesterday': _weatherSummary(),
                    'two_days_ago': _weatherSummary(),
                  },
                },
              ),
            );
          case '/feedback/today':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'exists': false, 'feedback': null},
              ),
            );
          case '/feedback/recent':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'days': [
                    for (var daysAgo = 0; daysAgo < 8; daysAgo++)
                      {
                        'date': formatIsoDate(
                          jstToday().subtract(Duration(days: daysAgo)),
                        ),
                        'feedback': null,
                      },
                  ],
                },
              ),
            );
          case '/feedback':
            final body = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            onSubmit(body);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'id': 'submitted-feedback',
                  'date': body['date'],
                  'feedback_value': body['feedback_value'],
                  'actual_top': body['actual_top'],
                  'actual_bottom': body['actual_bottom'],
                  'actual_outer': body['actual_outer'],
                  'time_slots': body['time_slots'],
                  'applied_recommendation_rank':
                      body['applied_recommendation_rank'],
                  'created_at': '2026-07-31T00:00:00Z',
                  'updated_at': '2026-07-31T00:00:00Z',
                },
              ),
            );
          default:
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Unexpected request: ${options.path}',
              ),
            );
        }
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _weatherSummary() {
  return {
    'temp_high': 24,
    'temp_low': 18,
    'feels_like_high': 24,
    'feels_like_low': 18,
    'humidity_avg': 55,
    'wind_speed_avg': 2.0,
    'precipitation_chance_max': 10,
    'wbgt_max': null,
  };
}
