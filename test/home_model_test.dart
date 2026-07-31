import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/home.dart';
import 'package:kisou_app/models/recommendation.dart';

void main() {
  test(
    'parses recommendation context, applied slots, hours, and directions',
    () {
      final response = HomeResponse.fromJson({
        'date': '2026-07-31',
        'feeling': 'COOL',
        'comfort_min': 10.5,
        'comfort_max': 16.5,
        'recommendations': [
          {
            'rank': 1,
            'direction': 'primary',
            'top': 'THICK_LONG',
            'bottom': 'LONG_PANTS',
            'outer': 'COAT',
          },
          {
            'rank': 2,
            'direction': 'alternative',
            'top': 'KNIT_SWEAT',
            'bottom': 'LONG_PANTS',
            'outer': 'JACKET',
          },
          {
            'rank': 3,
            'direction': 'lighter',
            'top': 'LONG_SLEEVE',
            'bottom': 'LONG_PANTS',
            'outer': 'CARDIGAN',
          },
        ],
        'recommendation_context': 'signed-context',
        'applied_time_slots': ['MORNING', 'EVENING'],
        'hours_analyzed': 8,
        'weather_comparison': _weatherComparison,
      });

      expect(response.recommendationContext, 'signed-context');
      expect(response.appliedTimeSlots, ['MORNING', 'EVENING']);
      expect(response.hoursAnalyzed, 8);
      expect(response.recommendations.map((item) => item.direction), [
        RecommendationDirection.primary,
        RecommendationDirection.alternative,
        RecommendationDirection.lighter,
      ]);
    },
  );

  test(
    'keeps legacy home fixtures compatible when additive fields are absent',
    () {
      final response = HomeResponse.fromJson({
        'date': '2026-07-31',
        'recommendations': [
          {
            'rank': 1,
            'top': 'SHORT_SLEEVE',
            'bottom': 'LONG_PANTS',
            'outer': null,
          },
          {
            'rank': 2,
            'top': 'THIN_LONG',
            'bottom': 'LONG_PANTS',
            'outer': null,
          },
          {
            'rank': 3,
            'top': 'SLEEVELESS',
            'bottom': 'SHORT_PANTS',
            'outer': null,
          },
        ],
        'weather_comparison': _weatherComparison,
      });

      expect(response.recommendationContext, isNull);
      expect(response.appliedTimeSlots, isNull);
      expect(response.hoursAnalyzed, 0);
      expect(response.feeling, 'PERFECT');
      expect(
        response.recommendations[0].direction,
        RecommendationDirection.primary,
      );
      expect(
        response.recommendations[1].direction,
        RecommendationDirection.warmer,
      );
      expect(
        response.recommendations[2].direction,
        RecommendationDirection.lighter,
      );
    },
  );

  test('ignores malformed additive context metadata', () {
    final response = HomeResponse.fromJson({
      'date': '2026-07-31',
      'recommendations': [
        {
          'rank': 1,
          'top': 'SHORT_SLEEVE',
          'bottom': 'LONG_PANTS',
          'outer': null,
        },
        {'rank': 2, 'top': 'THIN_LONG', 'bottom': 'LONG_PANTS', 'outer': null},
        {
          'rank': 3,
          'top': 'SLEEVELESS',
          'bottom': 'SHORT_PANTS',
          'outer': null,
        },
      ],
      'recommendation_context': 42,
      'applied_time_slots': 'MORNING',
      'hours_analyzed': 1.5,
      'weather_comparison': _weatherComparison,
    });

    expect(response.recommendationContext, isNull);
    expect(response.appliedTimeSlots, isNull);
    expect(response.hoursAnalyzed, 0);
  });

  test('rejects a misleading rank-direction pair', () {
    expect(
      () => RecommendationItem.fromJson({
        'rank': 2,
        'direction': 'primary',
        'top': 'THIN_LONG',
        'bottom': 'LONG_PANTS',
        'outer': null,
      }),
      throwsFormatException,
    );
    expect(
      () => RecommendationItem.fromJson({
        'rank': 999,
        'top': 'THIN_LONG',
        'bottom': 'LONG_PANTS',
        'outer': null,
      }),
      throwsFormatException,
    );
  });
}

const _weatherComparison = {
  'today': _weatherSummary,
  'yesterday': _weatherSummary,
  'two_days_ago': _weatherSummary,
};

const _weatherSummary = {
  'temp_high': 20,
  'temp_low': 10,
  'feels_like_high': 19,
  'feels_like_low': 9,
  'humidity_avg': 50,
  'wind_speed_avg': 2,
  'precipitation_chance_max': 10,
  'wbgt_max': null,
};
