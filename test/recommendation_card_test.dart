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
}
