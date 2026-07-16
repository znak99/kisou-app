const _weekdayJp = ['月', '火', '水', '木', '金', '土', '日'];

/// `7/17（金）` — compact Japanese date used across the 予報 surfaces.
String formatJpDate(DateTime date) {
  return '${date.month}/${date.day}（${_weekdayJp[date.weekday - 1]}）';
}

/// Today's date in JST regardless of the device timezone — the server keys
/// all daily data (feedback, recommendations) on JST days.
DateTime jstToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 9));
  return DateTime(now.year, now.month, now.day);
}

/// `2026-07-17` — the wire format for dates.
String formatIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}
