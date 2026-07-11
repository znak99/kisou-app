import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/analysis.dart';
import '../../providers/analysis_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/error_state.dart';

/// Feedback threshold below which the detailed analysis stays locked.
const int _kUnlockThreshold = 5;

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisState = ref.watch(analysisProvider);
    return SafeArea(
      bottom: false,
      child: analysisState.when(
        data: (analysis) => _AnalysisContent(analysis: analysis),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AnalysisError(error: error),
      ),
    );
  }
}

class _AnalysisContent extends ConsumerWidget {
  const _AnalysisContent({required this.analysis});

  final AnalysisResponse analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = analysis.totalFeedbacks >= _kUnlockThreshold;
    return RefreshIndicator(
      onRefresh: () => ref.read(analysisProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          KisouTheme.pagePad,
          KisouTheme.gapS,
          KisouTheme.pagePad,
          KisouTheme.gapXl,
        ),
        children: [
          Text(
            AppStrings.analysisTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: KisouTheme.gapL),
          if (!unlocked) ...[
            _DistributionCard(counts: analysis.feedbackCounts),
            const SizedBox(height: KisouTheme.gapM),
            _LockedHint(totalFeedbacks: analysis.totalFeedbacks),
          ] else ...[
            _TendencyCard(analysis: analysis),
            const SizedBox(height: KisouTheme.gapM),
            _DistributionCard(counts: analysis.feedbackCounts),
            const SizedBox(height: KisouTheme.gapM),
            _TimelineCard(history: analysis.history),
            const SizedBox(height: KisouTheme.gapM),
            _DayListCard(
              title: AppStrings.analysisColdDaysTitle,
              history: analysis.history,
              feedbackValue: 'cold',
              icon: Icons.ac_unit_rounded,
              accent: KisouTheme.cool,
            ),
            const SizedBox(height: KisouTheme.gapM),
            _DayListCard(
              title: AppStrings.analysisHotDaysTitle,
              history: analysis.history,
              feedbackValue: 'hot',
              icon: Icons.local_fire_department_rounded,
              accent: KisouTheme.warm,
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedHint extends StatelessWidget {
  const _LockedHint({required this.totalFeedbacks});

  final int totalFeedbacks;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final remaining = _kUnlockThreshold - totalFeedbacks;
    return ClayCard(
      color: c.surfaceAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: c.softInk),
          const SizedBox(width: KisouTheme.gapM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.analysisLockedMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (remaining > 0) ...[
                  const SizedBox(height: KisouTheme.gapXs),
                  Text(
                    '${AppStrings.analysisRemainingPrefix}'
                    ' $remaining '
                    '${AppStrings.analysisRemainingSuffix}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
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

class _TendencyCard extends StatelessWidget {
  const _TendencyCard({required this.analysis});

  final AnalysisResponse analysis;

  @override
  Widget build(BuildContext context) {
    final (label, desc, color) = switch (analysis.tendency) {
      'cold_sensitive' => (
        AppStrings.tendencyColdSensitive,
        AppStrings.tendencyColdSensitiveDesc,
        KisouTheme.cool,
      ),
      'heat_sensitive' => (
        AppStrings.tendencyHeatSensitive,
        AppStrings.tendencyHeatSensitiveDesc,
        KisouTheme.warm,
      ),
      _ => (
        AppStrings.tendencyNeutral,
        AppStrings.tendencyNeutralDesc,
        context.kisou.accent,
      ),
    };
    // Offset ranges -3..+3; map to a 0..1 gauge position.
    final gaugePosition = ((analysis.offsetValue + 3) / 6).clamp(0.0, 1.0);
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.analysisTendencyTitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: KisouTheme.gapXs),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: KisouTheme.gapXs),
          Text(desc, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: KisouTheme.gapL),
          _OffsetGauge(position: gaugePosition, color: color),
        ],
      ),
    );
  }
}

class _OffsetGauge extends StatelessWidget {
  const _OffsetGauge({required this.position, required this.color});

  final double position;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [KisouTheme.warm, c.hairline, KisouTheme.cool],
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Positioned(
                    left: (width - 16) * position,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                        boxShadow: c.tileShadow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KisouTheme.gapXs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('暑がり', style: Theme.of(context).textTheme.bodySmall),
                Text('寒がり', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.counts});

  final FeedbackCounts counts;

  @override
  Widget build(BuildContext context) {
    final bars = <(String, Color, int)>[
      (AppStrings.feedbackCountCold, KisouTheme.cool, counts.cold),
      (AppStrings.feedbackCountPerfect, const Color(0xFF6FBF73), counts.perfect),
      (AppStrings.feedbackCountHot, KisouTheme.warm, counts.hot),
    ];
    final maxCount = bars.map((b) => b.$3).fold(0, (a, b) => a > b ? a : b);
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.analysisDistributionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KisouTheme.gapL),
          SizedBox(
            height: 132,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxCount + 1).toDouble(),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            bars[index].$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].$3.toDouble(),
                          color: bars[i].$2,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.history});

  final List<AnalysisHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].offsetAtTime),
    ];
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.analysisTimelineTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KisouTheme.gapL),
          SizedBox(
            height: 132,
            child: LineChart(
              LineChartData(
                minY: -3,
                maxY: 3,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1.5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.hairline,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                    isCurved: true,
                    color: KisouTheme.accent,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: KisouTheme.accent.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayListCard extends StatelessWidget {
  const _DayListCard({
    required this.title,
    required this.history,
    required this.feedbackValue,
    required this.icon,
    required this.accent,
  });

  final String title;
  final List<AnalysisHistoryItem> history;
  final String feedbackValue;
  final IconData icon;
  final Color accent;

  String _details(AnalysisHistoryItem item) {
    final high = item.tempHigh != null ? '${item.tempHigh!.round()}°' : '-';
    final low = item.tempLow != null ? '${item.tempLow!.round()}°' : '-';
    final humidity = item.humidity != null ? '${item.humidity}%' : '-';
    return '${AppStrings.analysisTempHigh}$high '
        '${AppStrings.analysisTempLow}$low '
        '${AppStrings.weatherHumidity}$humidity';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final days = history
        .where((item) => item.feedbackValue == feedbackValue)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KisouTheme.gapS),
          if (days.isEmpty)
            Text(
              '—',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.softInk,
              ),
            )
          else
            for (final item in days.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KisouTheme.gapXs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: KisouTheme.gapS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.date,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            _details(item),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: c.softInk),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AnalysisError extends ConsumerWidget {
  const _AnalysisError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        ErrorState(
          message: apiErrorMessage(error),
          actionLabel: AppStrings.retry,
          onAction: () => ref.read(analysisProvider.notifier).retry(),
        ),
      ],
    );
  }
}
