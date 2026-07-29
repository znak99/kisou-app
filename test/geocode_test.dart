import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/utils/geocode.dart';

void main() {
  test('accepts only a confirmed JP country code', () {
    expect(
      const GeocodedRegion(
        regionName: '東京都 新宿区',
        countryCode: 'JP',
      ).isJapan,
      isTrue,
    );
    expect(
      const GeocodedRegion(
        regionName: 'New York',
        countryCode: 'US',
      ).isJapan,
      isFalse,
    );
    expect(
      const GeocodedRegion(
        regionName: null,
        countryCode: null,
      ).isJapan,
      isFalse,
    );
  });
}
