import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/user.dart';

void main() {
  test('serializes user update with only non-null snake case fields', () {
    final update = UserUpdate(
      nickname: 'キソウ',
      gender: 'unspecified',
      coldSensitivity: 'high',
      heatSensitivity: 'normal',
      departureTime: '09:00',
      latitude: 35.6812,
      longitude: 139.7671,
      regionName: '東京',
    );

    expect(update.toJson(), {
      'nickname': 'キソウ',
      'gender': 'unspecified',
      'cold_sensitivity': 'high',
      'heat_sensitivity': 'normal',
      'departure_time': '09:00',
      'latitude': 35.6812,
      'longitude': 139.7671,
      'region_name': '東京',
    });
    expect(update.toJson().containsKey('return_time'), isFalse);
  });
}
