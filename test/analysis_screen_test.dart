import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/analysis.dart';
import 'package:kisou_app/providers/analysis_provider.dart';
import 'package:kisou_app/screens/analysis/analysis_screen.dart';
import 'package:kisou_app/services/analysis_service.dart';

void main() {
  test('analysis response parses counts and history defensively', () {
    final response = AnalysisResponse.fromJson(_analysisJson(total: 5));

    expect(response.totalFeedbacks, 5);
    expect(response.feedbackCounts.cold, 2);
    expect(response.feedbackCounts.perfect, 2);
    expect(response.feedbackCounts.hot, 1);
    expect(response.history, hasLength(5));
    expect(response.history.first.tempHigh, 29);
  });

  testWidgets('0 records show the approved empty guidance', (tester) async {
    await _pumpAnalysis(tester, _analysisJson(total: 0));

    expect(find.text(AppStrings.analysisEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.analysisEmptyBody), findsOneWidget);
    expect(find.text(AppStrings.analysisAverageNotice), findsNothing);
    expect(find.text(AppStrings.openMeteoDataAttribution), findsNothing);
  });

  testWidgets('4 records explain average prediction and remaining count', (
    tester,
  ) async {
    await _pumpAnalysis(tester, _analysisJson(total: 4));

    expect(find.text(AppStrings.tendencyNeutral), findsOneWidget);
    expect(find.text(AppStrings.analysisAverageNotice), findsOneWidget);
    expect(find.text('くわしい分析まであと1回です'), findsOneWidget);
    expect(find.text(AppStrings.analysisDetailedTitle), findsNothing);
    expect(find.text(AppStrings.openMeteoDataAttribution), findsNothing);
  });

  testWidgets('5 records unlock detailed personal history', (tester) async {
    await _pumpAnalysis(tester, _analysisJson(total: 5));

    expect(find.text(AppStrings.analysisAverageNotice), findsNothing);
    expect(find.text(AppStrings.analysisDetailedTitle), findsOneWidget);
    expect(find.text('7/5（日）'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AppStrings.openMeteoDataAttribution),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
  });

  testWidgets('analysis supports the approved portrait phone matrix', (
    tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ];
    const scales = [1.0, 1.3, 2.0];
    final cases = [
      for (final size in sizes)
        for (final scale in scales) (size, scale),
    ];
    for (final (size, scale) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await _pumpAnalysis(tester, _analysisJson(total: 5));
      await tester.scrollUntilVisible(
        find.text(AppStrings.openMeteoDataAttribution),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width}×${size.height} / ${scale}x',
      );
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  });

  testWidgets('analysis stable state meets Flutter accessibility guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpAnalysis(tester, _analysisJson(total: 5));
    await tester.scrollUntilVisible(
      find.text(AppStrings.openMeteoDataAttribution),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}

Future<void> _pumpAnalysis(
  WidgetTester tester,
  Map<String, dynamic> response,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analysisServiceProvider.overrideWithValue(
          _FakeAnalysisService(AnalysisResponse.fromJson(response)),
        ),
      ],
      child: MaterialApp(
        theme: KisouTheme.light(),
        home: const AnalysisScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _analysisJson({required int total}) {
  final values = ['cold', 'perfect', 'hot', 'cold', 'perfect'];
  final history = [
    for (var index = 0; index < total; index++)
      {
        'date': '2026-07-${(index + 1).toString().padLeft(2, '0')}',
        'feedback_value': values[index % values.length],
        'temp_high': 29 + index,
        'temp_low': 21 + index,
        'humidity': 60,
        'offset_at_time': 0.0,
      },
  ];
  return {
    'offset_value': 0.0,
    'tendency': 'neutral',
    'total_feedbacks': total,
    'feedback_counts': {
      'cold': history.where((e) => e['feedback_value'] == 'cold').length,
      'perfect': history.where((e) => e['feedback_value'] == 'perfect').length,
      'hot': history.where((e) => e['feedback_value'] == 'hot').length,
    },
    'history': history,
  };
}

class _FakeAnalysisService extends AnalysisService {
  _FakeAnalysisService(this.response) : super(Dio());

  final AnalysisResponse response;

  @override
  Future<AnalysisResponse> getAnalysis() async => response;
}
