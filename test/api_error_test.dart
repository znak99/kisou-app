import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/utils/api_error.dart';

void main() {
  test('maps connection errors to offline message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/home'),
      type: DioExceptionType.connectionError,
    );

    expect(classifyApiError(error), ApiErrorKind.offline);
    expect(apiErrorMessage(error), AppStrings.offlineError);
  });

  test('maps timeout errors to server connection message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/home'),
      type: DioExceptionType.connectionTimeout,
    );

    expect(classifyApiError(error), ApiErrorKind.timeout);
    expect(apiErrorMessage(error), AppStrings.timeoutError);
  });

  test('maps missing location response to location message', () {
    final requestOptions = RequestOptions(path: '/home');
    final error = DioException(
      requestOptions: requestOptions,
      response: Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 400,
        data: {'detail': 'location is not configured'},
      ),
    );

    expect(classifyApiError(error), ApiErrorKind.locationMissing);
    expect(apiErrorMessage(error), AppStrings.locationMissing);
  });
}
