import '../constants/clothing_tags.dart';
import '../utils/jp_date.dart';

const widgetRecommendationSchemaVersion = 1;

const _widgetFeelingCodes = <String>{
  'VERY_HOT',
  'HOT',
  'WARM',
  'PERFECT',
  'COOL',
  'COLD',
  'VERY_COLD',
};

/// The privacy-minimized response used to populate the native home-screen
/// widgets. It intentionally contains no account, nickname, location, weather,
/// authentication, or signed recommendation-context data.
class WidgetRecommendation {
  const WidgetRecommendation({
    required this.date,
    required this.validUntil,
    required this.feeling,
    required this.top,
    required this.bottom,
    required this.outer,
  });

  factory WidgetRecommendation.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'schema_version',
      'date',
      'valid_until',
      'feeling',
      'recommendation',
    });
    final schemaVersion = json['schema_version'];
    if (schemaVersion is! int ||
        schemaVersion != widgetRecommendationSchemaVersion) {
      throw const FormatException('Unsupported widget schema.');
    }

    final date = _parseCanonicalDate(json['date']);
    final validUntil = _parseValidUntil(
      json['valid_until'],
      recommendationDate: date,
    );
    final feeling = json['feeling'];
    if (feeling is! String || !_widgetFeelingCodes.contains(feeling)) {
      throw const FormatException('Invalid widget feeling.');
    }
    final rawRecommendation = json['recommendation'];
    if (rawRecommendation is! Map<String, dynamic>) {
      throw const FormatException('Invalid widget recommendation.');
    }
    _requireExactKeys(rawRecommendation, const {'top', 'bottom', 'outer'});

    final rawTop = rawRecommendation['top'];
    final rawBottom = rawRecommendation['bottom'];
    final rawOuter = rawRecommendation['outer'];
    if (rawTop is! String || rawBottom is! String) {
      throw const FormatException('Invalid widget clothing code.');
    }
    final top = ClothingTop.fromCode(rawTop);
    final bottom = ClothingBottom.fromCode(rawBottom);
    final outer = switch (rawOuter) {
      null => null,
      String value => ClothingOuter.fromCode(value),
      _ => null,
    };
    if (top == null || bottom == null || (rawOuter != null && outer == null)) {
      throw const FormatException('Unknown widget clothing code.');
    }

    return WidgetRecommendation(
      date: date,
      validUntil: validUntil,
      feeling: feeling,
      top: top,
      bottom: bottom,
      outer: outer,
    );
  }

  final DateTime date;
  final DateTime validUntil;
  final String feeling;
  final ClothingTop top;
  final ClothingBottom bottom;
  final ClothingOuter? outer;

  Map<String, dynamic> toReadyEnvelopeJson() {
    return {
      'schema_version': widgetRecommendationSchemaVersion,
      'state': 'ready',
      'date': formatIsoDate(date),
      'valid_until': _formatCanonicalUtc(validUntil),
      'feeling': feeling,
      'recommendation': {
        'top': top.apiCode,
        'bottom': bottom.apiCode,
        'outer': outer?.apiCode,
      },
    };
  }
}

void _requireExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException('Unexpected widget response fields.');
  }
}

DateTime _parseCanonicalDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid widget date.');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || formatIsoDate(parsed) != value) {
    throw const FormatException('Invalid widget date.');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _parseValidUntil(
  Object? value, {
  required DateTime recommendationDate,
}) {
  if (value is! String ||
      value.trim() != value ||
      !value.endsWith('Z') ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\dZ$',
      ).hasMatch(value)) {
    throw const FormatException('Invalid widget expiry.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || _formatCanonicalUtc(parsed) != value) {
    throw const FormatException('Invalid widget expiry.');
  }
  // The response is valid only through the next Asia/Tokyo midnight. This
  // relationship prevents a malformed or overlong server expiry from keeping
  // an old personalized recommendation on the home screen.
  final expected = DateTime.utc(
    recommendationDate.year,
    recommendationDate.month,
    recommendationDate.day + 1,
  ).subtract(const Duration(hours: 9));
  if (parsed != expected) {
    throw const FormatException('Widget expiry does not match its JST date.');
  }
  return parsed;
}

String _formatCanonicalUtc(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  final second = utc.second.toString().padLeft(2, '0');
  return '$year-$month-${day}T$hour:$minute:${second}Z';
}
