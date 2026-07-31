import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/forecast.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/providers/forecast_provider.dart';
import 'package:kisou_app/services/forecast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'network retries reuse one UUID and success starts a new UUID',
    () async {
      final service = _FakeForecastService([
        _timeout(),
        _timeout(),
        _response('2026-08-02', remaining: 2),
        _response('2026-08-02', remaining: 1),
      ]);
      final keys = [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ];
      final container = _container(service, keys);
      addTearDown(container.dispose);
      final controller = container.read(forecastOutlookProvider.notifier);

      expect((await _lookup(controller)).succeeded, isFalse);
      expect((await _lookup(controller)).succeeded, isFalse);
      expect((await _lookup(controller)).succeeded, isTrue);
      expect((await _lookup(controller)).succeeded, isTrue);

      expect(service.idempotencyKeys, [keys[0], keys[0], keys[0], keys[1]]);
    },
  );

  test('picker reset never revives a failed operation key', () async {
    final service = _FakeForecastService([_timeout(), _timeout()]);
    final keys = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ];
    final container = _container(service, keys);
    addTearDown(container.dispose);
    final controller = container.read(forecastOutlookProvider.notifier);

    await _lookup(controller);
    controller.resetPendingOperation();
    await _lookup(controller);

    expect(service.idempotencyKeys, keys);
  });

  test('sub-microdegree coordinate changes receive different keys', () async {
    final service = _FakeForecastService([_timeout(), _timeout()]);
    final keys = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ];
    final container = _container(service, keys);
    addTearDown(container.dispose);
    final controller = container.read(forecastOutlookProvider.notifier);

    await _lookup(controller, latitude: 35.6812361);
    await _lookup(controller, latitude: 35.6812362);

    expect(service.idempotencyKeys, keys);
  });

  test(
    '409 preserves the previous result and refreshes server quota',
    () async {
      final conflict = DioException(
        requestOptions: RequestOptions(path: '/forecast/outlook'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/forecast/outlook'),
          statusCode: 409,
        ),
        type: DioExceptionType.badResponse,
      );
      final service = _FakeForecastService([
        _response('2026-08-02', remaining: 2),
        conflict,
        _response('2026-08-02', remaining: 1),
      ]);
      final container = _container(service, [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
        '33333333-3333-4333-8333-333333333333',
      ]);
      addTearDown(container.dispose);
      final controller = container.read(forecastOutlookProvider.notifier);

      expect((await _lookup(controller)).succeeded, isTrue);
      final before = container.read(forecastOutlookProvider)!.requireValue;
      expect((await _lookup(controller)).succeeded, isFalse);
      final after = container.read(forecastOutlookProvider)!.requireValue;

      expect(after.outlook.date, before.outlook.date);
      expect(service.quotaCalls, greaterThanOrEqualTo(1));
      expect((await _lookup(controller)).succeeded, isTrue);
      expect(service.idempotencyKeys, [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
        '33333333-3333-4333-8333-333333333333',
      ]);
    },
  );
}

ProviderContainer _container(_FakeForecastService service, List<String> keys) {
  var index = 0;
  return ProviderContainer(
    overrides: [
      forecastServiceProvider.overrideWithValue(service),
      outlookIdempotencyKeyFactoryProvider.overrideWithValue(
        () => keys[index++],
      ),
    ],
  );
}

Future<OutlookLookupOutcome> _lookup(
  ForecastOutlookController controller, {
  double latitude = 35.681236,
}) {
  return controller.lookup(
    date: '2026-08-02',
    cityCode: 'tokyo',
    cityName: '東京',
    latitude: latitude,
    longitude: 139.767125,
  );
}

class _FakeForecastService extends ForecastService {
  _FakeForecastService(this.results) : super(Dio());

  final List<Object> results;
  final List<String> idempotencyKeys = [];
  int quotaCalls = 0;

  @override
  Future<ForecastOutlookResponse> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    final result = results.removeAt(0);
    if (result is ForecastOutlookResponse) {
      return result;
    }
    throw result;
  }

  @override
  Future<OutlookQuota> getOutlookQuota() async {
    quotaCalls++;
    return _quota(0);
  }
}

ForecastOutlookResponse _response(String date, {required int remaining}) {
  return ForecastOutlookResponse(
    outlook: ForecastOutlook(
      date: date,
      mode: 'forecast',
      feeling: 'PERFECT',
      comfortMin: 20,
      comfortMax: 22,
      recommendations: const [],
      weather: null,
      climate: null,
    ),
    quotaConsumed: 'free',
    quota: _quota(remaining),
  );
}

OutlookQuota _quota(int remaining) {
  return OutlookQuota(
    date: '2026-07-31',
    freeLimit: 3,
    freeUsed: 3 - remaining,
    freeRemaining: remaining,
    rewardCredits: 0,
    totalRemaining: remaining,
    resetsAt: DateTime.utc(2026, 7, 31, 15),
    adsAvailable: remaining == 0,
  );
}

DioException _timeout() {
  return DioException(
    requestOptions: RequestOptions(path: '/forecast/outlook'),
    type: DioExceptionType.receiveTimeout,
  );
}
