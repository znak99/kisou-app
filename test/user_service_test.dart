import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/services/user_service.dart';

void main() {
  test('account deletion sends the durable UUID and recovery guard', () async {
    late RequestOptions captured;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 204),
          );
        },
      ),
    );

    await UserService(
      dio,
    ).deleteMe(idempotencyKey: '11111111-1111-4111-8111-111111111111');

    expect(captured.method, 'DELETE');
    expect(captured.path, '/users/me');
    expect(
      captured.headers['Idempotency-Key'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(captured.extra['preserveAccountDeletionRecovery'], isTrue);
  });

  test('parses a completed unauthenticated deletion receipt', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'completed',
                'completed_at': '2026-07-31T00:00:00Z',
                'expires_at': '2026-08-01T00:00:00Z',
              },
            ),
          );
        },
      ),
    );

    final status = await UserService(
      dio,
    ).getDeletionStatus(idempotencyKey: '11111111-1111-4111-8111-111111111111');

    expect(status, isNotNull);
    expect(status!.completedAt, DateTime.utc(2026, 7, 31));
  });

  test(
    '404 means no deletion proof, while malformed 200 is an error',
    () async {
      final notFoundDio = Dio();
      notFoundDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 404,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      expect(
        await UserService(notFoundDio).getDeletionStatus(
          idempotencyKey: '11111111-1111-4111-8111-111111111111',
        ),
        isNull,
      );

      final malformedDio = Dio();
      malformedDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'unknown',
                  'completed_at': '2026-07-31T00:00:00Z',
                  'expires_at': '2026-08-01T00:00:00Z',
                },
              ),
            );
          },
        ),
      );
      await expectLater(
        UserService(malformedDio).getDeletionStatus(
          idempotencyKey: '11111111-1111-4111-8111-111111111111',
        ),
        throwsFormatException,
      );
    },
  );
}
