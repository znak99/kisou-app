import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/recommendation.dart';
import 'package:kisou_app/widgets/recommendation_card.dart';

void main() {
  testWidgets('shows no-outer explicitly and keeps outer-top-bottom order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecommendationCard(
            recommendation: RecommendationItem(
              rank: 1,
              direction: RecommendationDirection.primary,
              top: 'SHORT_SLEEVE',
              bottom: 'LONG_PANTS',
              outer: null,
            ),
            size: RecommendationCardSize.large,
          ),
        ),
      ),
    );

    final outer = find.text('アウターなし');
    final top = find.text('半袖');
    final bottom = find.text('長ズボン');
    expect(outer, findsOneWidget);
    expect(top, findsOneWidget);
    expect(bottom, findsOneWidget);
    expect(tester.getCenter(outer).dx, lessThan(tester.getCenter(top).dx));
    expect(tester.getCenter(top).dx, lessThan(tester.getCenter(bottom).dx));
  });

  testWidgets(
    'announces an extreme-bound option as an equal-warmth alternative',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: RecommendationCard(
                recommendation: RecommendationItem(
                  rank: 2,
                  direction: RecommendationDirection.alternative,
                  top: 'KNIT_SWEAT',
                  bottom: 'LONG_PANTS',
                  outer: 'PADDING',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('同じ暖かさの別案'), findsOneWidget);
      expect(find.text('少し暖かめ'), findsNothing);
      expect(find.bySemanticsLabel('2番目の候補、同じ暖かさの別案'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );
}
