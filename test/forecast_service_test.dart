import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/services/forecast_service.dart';

void main() {
  test('future forecast sends exact coordinates in POST JSON only', () async {
    late RequestOptions captured;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
            ),
          );
        },
      ),
    );
    final service = ForecastService(dio);

    await expectLater(
      service.getOutlook(
        date: '2026-08-01',
        latitude: 35.681236,
        longitude: 139.767125,
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      ),
      throwsA(isA<DioException>()),
    );

    expect(captured.method, 'POST');
    expect(captured.path, '/forecast/outlook');
    expect(captured.queryParameters, isEmpty);
    expect(captured.uri.query, isEmpty);
    expect(
      captured.headers['Idempotency-Key'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(captured.data, {
      'date': '2026-08-01',
      'latitude': 35.681236,
      'longitude': 139.767125,
    });
  });
}
