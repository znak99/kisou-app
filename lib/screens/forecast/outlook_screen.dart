import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/forecast.dart';
import '../../models/location.dart';
import '../../providers/forecast_provider.dart';
import '../../utils/jp_date.dart';
import '../../widgets/recommendation_card.dart';

/// Free lookups per day (JST). The rewarded-ad "+1" is planned but not wired
/// yet, so the intro copy marks it 準備中.
const _freeLookupsPerDay = 3;
const _quotaDateKey = 'outlook_quota_date';
const _quotaUsedKey = 'outlook_quota_used';

/// Full-page "日付で予想する": pick a future date and city, get an outfit
/// estimate (real forecast when near, past-years average when far).
///
/// Reached from the 予報 tab's toolbar. The [_lookup] call is deliberately the
/// single funnel for running an estimate — a future rewarded-ad gate ("watch
/// an ad for one lookup") wraps that one method and nothing else.
class OutlookScreen extends ConsumerStatefulWidget {
  const OutlookScreen({super.key});

  @override
  ConsumerState<OutlookScreen> createState() => _OutlookScreenState();
}

class _OutlookScreenState extends ConsumerState<OutlookScreen> {
  DateTime? _date;
  LocationValue _city = majorCities.first;

  /// Lookups left today. Null while loading from storage.
  int? _remaining;

  /// City shown with the current result (captured when 予想する is pressed, so
  /// changing the picker afterwards doesn't relabel an old result).
  LocationValue? _lookedUpCity;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = formatIsoDate(jstToday());
    final used = prefs.getString(_quotaDateKey) == today
        ? (prefs.getInt(_quotaUsedKey) ?? 0)
        : 0; // 날짜가 바뀌면 리셋.
    if (mounted) {
      setState(() => _remaining = (_freeLookupsPerDay - used).clamp(0, 99));
    }
  }

  Future<void> _consumeQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = formatIsoDate(jstToday());
    final used = prefs.getString(_quotaDateKey) == today
        ? (prefs.getInt(_quotaUsedKey) ?? 0)
        : 0;
    await prefs.setString(_quotaDateKey, today);
    await prefs.setInt(_quotaUsedKey, used + 1);
    if (mounted) {
      setState(() {
        _remaining = (_freeLookupsPerDay - used - 1).clamp(0, 99);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 329)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<LocationValue>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return ListView(
          children: [
            for (final city in majorCities)
              ListTile(
                title: Text(city.regionName),
                trailing: city.regionName == _city.regionName
                    ? const Icon(
                        Icons.check_rounded,
                        color: KisouTheme.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(city),
              ),
          ],
        );
      },
    );
    if (picked != null) {
      setState(() => _city = picked);
    }
  }

  Future<void> _lookup() async {
    final date = _date;
    if (date == null || (_remaining ?? 0) <= 0) {
      return;
    }
    _lookedUpCity = _city;
    final succeeded = await ref
        .read(forecastOutlookProvider.notifier)
        .lookup(
          date: formatIsoDate(date),
          latitude: _city.latitude,
          longitude: _city.longitude,
        );
    // Only a successful estimate consumes the daily count — failures retry
    // for free.
    if (succeeded) {
      await _consumeQuota();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final outlookState = ref.watch(forecastOutlookProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.ink,
        title: Text(
          AppStrings.forecastOutlookTitle,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(KisouTheme.cardPad),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(KisouTheme.rMd),
              border: Border.all(color: c.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // What this does + how many estimates are left today +
                // rewarded-ad note (review 1).
                Text(
                  AppStrings.forecastOutlookIntro,
                  style: textTheme.bodySmall?.copyWith(
                    color: c.softInk,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: KisouTheme.gapS),
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 15,
                      color: KisouTheme.accent,
                    ),
                    const SizedBox(width: KisouTheme.gapXs),
                    Text(
                      switch (_remaining) {
                        null => '',
                        0 => AppStrings.forecastOutlookQuotaEmpty,
                        final n => AppStrings.forecastOutlookQuota(n),
                      },
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 21),
                  child: Text(
                    AppStrings.forecastOutlookAdNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.softInk,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: KisouTheme.gapL),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: AppStrings.forecastOutlookDateLabel,
                        value: _date == null ? null : formatJpDate(_date!),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: KisouTheme.gapS),
                    Expanded(
                      child: _PickerField(
                        label: AppStrings.forecastOutlookPlaceLabel,
                        value: _city.regionName,
                        onTap: _pickCity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KisouTheme.gapM),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _date == null || (_remaining ?? 0) <= 0
                        ? null
                        : _lookup,
                    child: const Text(AppStrings.forecastOutlookSubmit),
                  ),
                ),
                if (outlookState != null) ...[
                  const SizedBox(height: KisouTheme.gapM),
                  Divider(height: 1, color: c.hairline),
                  const SizedBox(height: KisouTheme.gapM),
                  outlookState.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(KisouTheme.gapS),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, _) => Text(
                      AppStrings.forecastOutlookFailed,
                      style: textTheme.bodySmall?.copyWith(color: c.softInk),
                    ),
                    data: (outlook) => _OutlookResult(
                      outlook: outlook,
                      cityName: _lookedUpCity?.regionName ?? _city.regionName,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KisouTheme.rSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KisouTheme.rSm),
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: c.softInk,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value ?? '--',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: value == null ? c.softInk : c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlookResult extends StatelessWidget {
  const _OutlookResult({required this.outlook, required this.cityName});

  final ForecastOutlook outlook;
  final String cityName;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.parse(outlook.date);
    final climate = outlook.climate;
    final weather = outlook.weather;

    // Headline range: climatology shows past-years AVERAGES (平年値-style,
    // per review — extremes would read alarmingly wide); forecast shows the
    // forecast day's low/high.
    String? headline;
    if (outlook.isClimatology && climate != null) {
      headline = AppStrings.forecastClimateRange(
        climate.tempLowAvg.round().toString(),
        climate.tempHighAvg.round().toString(),
      );
    } else if (weather != null &&
        weather.tempLow != null &&
        weather.tempHigh != null) {
      headline = '${weather.tempLow!.round()}°〜${weather.tempHigh!.round()}°';
    }

    final recommendations = [...outlook.recommendations]
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$cityName・${formatJpDate(date)}',
              style: textTheme.bodySmall?.copyWith(
                color: c.softInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (headline != null)
              Text(
                headline,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        // Personalized felt-temperature line: the estimate runs through the
        // same comfort engine as home, offset included (review 15).
        const SizedBox(height: KisouTheme.gapS),
        Text(
          AppStrings.forecastFeelingLine(outlook.feeling),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: KisouTheme.gapM),
          RecommendationCard(
            recommendation: recommendations.first,
            size: RecommendationCardSize.large,
          ),
        ],
        // How the estimate was made — data source template (review 15).
        const SizedBox(height: KisouTheme.gapS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: c.softInk),
            const SizedBox(width: KisouTheme.gapXs),
            Expanded(
              child: Text(
                outlook.isClimatology && climate != null
                    ? AppStrings.forecastExplainClimatology(
                        years: climate.yearsUsed,
                        sampleDays: climate.sampleDays,
                        low: climate.tempLowAvg.round().toString(),
                        high: climate.tempHighAvg.round().toString(),
                      )
                    : AppStrings.forecastExplainForecastMode,
                style: textTheme.bodySmall?.copyWith(
                  color: c.softInk,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
