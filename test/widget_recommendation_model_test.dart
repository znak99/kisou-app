import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/clothing_tags.dart';
import 'package:kisou_app/models/widget_recommendation.dart';

void main() {
  test(
    'parses the exact rank-1 widget contract and emits a ready envelope',
    () {
      final recommendation = WidgetRecommendation.fromJson(_validResponse());

      expect(recommendation.date, DateTime(2026, 7, 31));
      expect(recommendation.validUntil, DateTime.utc(2026, 7, 31, 15));
      expect(recommendation.feeling, 'PERFECT');
      expect(recommendation.top, ClothingTop.shortSleeve);
      expect(recommendation.bottom, ClothingBottom.longPants);
      expect(recommendation.outer, ClothingOuter.lightOuter);
      expect(recommendation.toReadyEnvelopeJson(), {
        'schema_version': 1,
        'state': 'ready',
        'date': '2026-07-31',
        'valid_until': '2026-07-31T15:00:00Z',
        'feeling': 'PERFECT',
        'recommendation': {
          'top': 'SHORT_SLEEVE',
          'bottom': 'LONG_PANTS',
          'outer': 'LIGHT_OUTER',
        },
      });
    },
  );

  test('accepts an explicit null outer and preserves it in the envelope', () {
    final json = _validResponse();
    (json['recommendation']! as Map<String, dynamic>)['outer'] = null;

    final recommendation = WidgetRecommendation.fromJson(json);

    expect(recommendation.outer, isNull);
    expect(recommendation.toReadyEnvelopeJson()['recommendation'], {
      'top': 'SHORT_SLEEVE',
      'bottom': 'LONG_PANTS',
      'outer': null,
    });
  });

  test('rejects missing, additional, and wrongly typed contract fields', () {
    final missing = _validResponse()..remove('feeling');
    final additional = _validResponse()..['rank'] = 1;
    final nestedAdditional = _validResponse();
    (nestedAdditional['recommendation']! as Map<String, dynamic>)['weather'] =
        'sunny';
    final floatingSchema = _validResponse()..['schema_version'] = 1.0;
    final booleanSchema = _validResponse()..['schema_version'] = true;

    for (final json in [
      missing,
      additional,
      nestedAdditional,
      floatingSchema,
      booleanSchema,
    ]) {
      expect(() => WidgetRecommendation.fromJson(json), throwsFormatException);
    }
  });

  test('rejects unknown feeling and clothing codes', () {
    final unknownFeeling = _validResponse()..['feeling'] = 'SCORCHING';
    final unknownTop = _validResponse();
    (unknownTop['recommendation']! as Map<String, dynamic>)['top'] = 'SHIRT';
    final unknownBottom = _validResponse();
    (unknownBottom['recommendation']! as Map<String, dynamic>)['bottom'] =
        'JEANS';
    final unknownOuter = _validResponse();
    (unknownOuter['recommendation']! as Map<String, dynamic>)['outer'] =
        'PONCHO';

    for (final json in [
      unknownFeeling,
      unknownTop,
      unknownBottom,
      unknownOuter,
    ]) {
      expect(() => WidgetRecommendation.fromJson(json), throwsFormatException);
    }
  });

  test('rejects non-canonical or mismatched JST validity boundaries', () {
    final invalidValues = [
      '2026-07-31T15:00:00.000Z',
      '2026-08-01T00:00:00+09:00',
      ' 2026-07-31T15:00:00Z',
      '2026-07-31T15:00:00Z ',
      '2026-07-31T14:59:60Z',
      '2026-07-31T14:60:00Z',
      '2026-07-31T24:00:00Z',
      '2026-07-31T16:00:00Z',
      '2026-08-01T15:00:00Z',
    ];

    for (final value in invalidValues) {
      final json = _validResponse()..['valid_until'] = value;
      expect(
        () => WidgetRecommendation.fromJson(json),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test('rejects non-canonical and impossible recommendation dates', () {
    for (final value in [
      '2026-7-31',
      '2026-07-31T00:00:00Z',
      '2026-02-30',
      ' 2026-07-31',
    ]) {
      final json = _validResponse()..['date'] = value;
      expect(
        () => WidgetRecommendation.fromJson(json),
        throwsFormatException,
        reason: value,
      );
    }
  });
}

Map<String, dynamic> _validResponse() {
  return {
    'schema_version': 1,
    'date': '2026-07-31',
    'valid_until': '2026-07-31T15:00:00Z',
    'feeling': 'PERFECT',
    'recommendation': <String, dynamic>{
      'top': 'SHORT_SLEEVE',
      'bottom': 'LONG_PANTS',
      'outer': 'LIGHT_OUTER',
    },
  };
}
