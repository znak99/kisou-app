const _weekdayJp = ['月', '火', '水', '木', '金', '土', '日'];

/// `7/17（金）` — compact Japanese date used across the 予報 surfaces.
String formatJpDate(DateTime date) {
  return '${date.month}/${date.day}（${_weekdayJp[date.weekday - 1]}）';
}
