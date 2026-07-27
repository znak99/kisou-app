import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/utils/jp_date.dart';

void main() {
  test('JST date conversion does not depend on the input timezone', () {
    expect(
      jstDateAt(DateTime.parse('2026-07-27T15:00:00Z')),
      DateTime(2026, 7, 28),
    );
    expect(
      jstDateAt(DateTime.parse('2026-07-28T00:00:00+09:00')),
      DateTime(2026, 7, 28),
    );
    expect(
      jstDateAt(DateTime.parse('2026-07-27T10:00:00-05:00')),
      DateTime(2026, 7, 28),
    );
  });

  test('next JST midnight duration is correct in every device timezone', () {
    expect(
      durationUntilNextJstDay(DateTime.parse('2026-07-27T14:59:59Z')),
      const Duration(seconds: 1),
    );
    expect(
      durationUntilNextJstDay(DateTime.parse('2026-07-27T09:59:59-05:00')),
      const Duration(seconds: 1),
    );
    expect(
      durationUntilNextJstDay(DateTime.parse('2026-07-28T00:00:00+09:00')),
      const Duration(days: 1),
    );
  });
}
