import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/services/widget_recommendation_service.dart';

void main() {
  test('uses only the authenticated no-store widget GET contract', () async {
    final adapter = _WidgetAdapter(statusCode: 200, body: _validBody);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;

    final recommendation = await WidgetRecommendationService(dio).getToday();
    final request = adapter.request!;

    expect(request.method, 'GET');
    expect(request.path, '/widget/today');
    expect(request.queryParameters, isEmpty);
    expect(request.data, isNull);
    expect(request.headers['Cache-Control'], 'no-cache, no-store');
    expect(request.headers['Pragma'], 'no-cache');
    expect(request.headers, isNot(contains('If-None-Match')));
    expect(recommendation.feeling, 'PERFECT');
  });

  test('accepts only a regular 200 response with a body', () async {
    for (final response in [
      (statusCode: 201, body: _validBody),
      (statusCode: 204, body: ''),
      (statusCode: 200, body: ''),
    ]) {
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'https://api.example.test',
                validateStatus: (_) => true,
              ),
            )
            ..httpClientAdapter = _WidgetAdapter(
              statusCode: response.statusCode,
              body: response.body,
            );

      await expectLater(
        WidgetRecommendationService(dio).getToday(),
        throwsA(anyOf(isA<FormatException>(), isA<DioException>())),
        reason: '${response.statusCode}/${response.body.isEmpty}',
      );
    }
  });

  test('fails closed when the server adds private context', () async {
    final body = jsonDecode(_validBody) as Map<String, dynamic>;
    body['region'] = 'tokyo';
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _WidgetAdapter(
        statusCode: 200,
        body: jsonEncode(body),
      );

    await expectLater(
      WidgetRecommendationService(dio).getToday(),
      throwsFormatException,
    );
  });
}

const _validBody = '''
{
  "schema_version": 1,
  "date": "2026-07-31",
  "valid_until": "2026-07-31T15:00:00Z",
  "feeling": "PERFECT",
  "recommendation": {
    "top": "SHORT_SLEEVE",
    "bottom": "LONG_PANTS",
    "outer": null
  }
}
''';

class _WidgetAdapter implements HttpClientAdapter {
  _WidgetAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
