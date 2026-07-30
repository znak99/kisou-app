import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/analysis.dart';
import '../../providers/analysis_provider.dart';
import '../../utils/api_error.dart';
import '../../utils/jp_date.dart';
import '../../widgets/error_state.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.analysisTitle)),
      body: SafeArea(
        top: false,
        child: state.when(
          data: (analysis) => _AnalysisContent(analysis: analysis),
          loading: () => const _AnalysisSkeleton(),
          error: (error, _) => ErrorState(
            message: apiErrorMessage(error),
            actionLabel: AppStrings.retry,
            onAction: () => ref.read(analysisProvider.notifier).retry(),
          ),
        ),
      ),
    );
  }
}

class _AnalysisContent extends ConsumerWidget {
  const _AnalysisContent({required this.analysis});

  final AnalysisResponse analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (analysis.totalFeedbacks == 0) {
      return RefreshIndicator(
        onRefresh: () => ref.read(analysisProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(KisouTheme.pagePad),
          children: const [SizedBox(height: 96), _EmptyAnalysis()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(analysisProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          KisouTheme.pagePad,
          KisouTheme.gapS,
          KisouTheme.pagePad,
          32,
        ),
        children: [
          _TendencyCard(analysis: analysis),
          const SizedBox(height: KisouTheme.gapM),
          _DistributionCard(analysis: analysis),
          if (analysis.totalFeedbacks <= 4) ...[
            const SizedBox(height: KisouTheme.gapM),
            _AveragePredictionNotice(total: analysis.totalFeedbacks),
          ] else if (analysis.history.isNotEmpty) ...[
            const SizedBox(height: KisouTheme.gapL),
            Text(
              AppStrings.analysisDetailedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: KisouTheme.gapS),
            _HistoryCard(history: analysis.history),
          ],
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
    final (label, description, icon) = switch (analysis.tendency) {
      'cold_sensitive' => (
        AppStrings.tendencyColdSensitive,
        AppStrings.tendencyColdSensitiveDesc,
        Icons.ac_unit_rounded,
      ),
      'heat_sensitive' => (
        AppStrings.tendencyHeatSensitive,
        AppStrings.tendencyHeatSensitiveDesc,
        Icons.local_fire_department_rounded,
      ),
      _ => (
        AppStrings.tendencyNeutral,
        AppStrings.tendencyNeutralDesc,
        Icons.balance_rounded,
      ),
    };
    return ClayCard(
      child: Semantics(
        container: true,
        label: '${AppStrings.analysisTendencyTitle}、$label。$description',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.analysisTendencyTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: KisouTheme.gapM),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.kisou.surfaceAlt,
                      borderRadius: BorderRadius.circular(KisouTheme.rSm),
                    ),
                    child: Icon(icon, color: context.kisou.accent),
                  ),
                  const SizedBox(width: KisouTheme.gapM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: KisouTheme.gapXs),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.analysis});

  final AnalysisResponse analysis;

  @override
  Widget build(BuildContext context) {
    final total = analysis.totalFeedbacks;
    final counts = analysis.feedbackCounts;
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.analysisDistributionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                AppStrings.analysisCount(total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapL),
          _DistributionBar(
            label: AppStrings.feedbackCountCold,
            count: counts.cold,
            total: total,
            color: context.kisou.cool,
          ),
          const SizedBox(height: KisouTheme.gapM),
          _DistributionBar(
            label: AppStrings.feedbackCountPerfect,
            count: counts.perfect,
            total: total,
            color: context.kisou.success,
          ),
          const SizedBox(height: KisouTheme.gapM),
          _DistributionBar(
            label: AppStrings.feedbackCountHot,
            count: counts.hot,
            total: total,
            color: context.kisou.warm,
          ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    final percent = (ratio * 100).round();
    return Semantics(
      label: AppStrings.analysisCountSpoken(label, count, percent),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(AppStrings.analysisCountAndPercent(count, percent)),
              ],
            ),
            const SizedBox(height: KisouTheme.gapXs),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: color,
                backgroundColor: context.kisou.surfaceAlt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AveragePredictionNotice extends StatelessWidget {
  const _AveragePredictionNotice({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final remaining = 5 - total;
    return ClayCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.kisou.accent),
          const SizedBox(width: KisouTheme.gapM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.analysisAverageNotice,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KisouTheme.gapXs),
                Text(
                  AppStrings.analysisDetailedRemaining(remaining),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<AnalysisHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final recent = history.reversed.take(10).toList(growable: false);
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < recent.length; index++) ...[
            _HistoryRow(item: recent[index]),
            if (index != recent.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final AnalysisHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final feedback = switch (item.feedbackValue) {
      'cold' => AppStrings.feedbackCountCold,
      'hot' => AppStrings.feedbackCountHot,
      _ => AppStrings.feedbackCountPerfect,
    };
    final temperatures = item.tempHigh == null && item.tempLow == null
        ? AppStrings.analysisNoTemperature
        : AppStrings.analysisTemperatureSummary(
            _temperature(item.tempHigh),
            _temperature(item.tempLow),
          );
    final stacked =
        usesLargeText(context) || MediaQuery.sizeOf(context).width < 400;
    final date = Text(
      formatJpDate(item.date),
      style: Theme.of(context).textTheme.bodySmall,
    );
    final feeling = Text(
      feedback,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final weather = Text(
      temperatures,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: Theme.of(context).textTheme.bodySmall,
    );
    return Semantics(
      label:
          '${formatJpDateSpoken(item.date)}、$feedback、$temperatures'
          '${item.humidity == null ? '' : AppStrings.analysisHumiditySpoken(item.humidity!)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(KisouTheme.gapL),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    date,
                    const SizedBox(height: KisouTheme.gapXs),
                    feeling,
                    const SizedBox(height: KisouTheme.gapXs),
                    weather,
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 84, child: date),
                    Expanded(child: feeling),
                    weather,
                  ],
                ),
        ),
      ),
    );
  }

  String _temperature(double? value) {
    return value == null ? '—' : '${value.round()}℃';
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.insights_rounded,
          size: 56,
          color: context.kisou.accent.withValues(alpha: 0.75),
        ),
        const SizedBox(height: KisouTheme.gapL),
        Text(
          AppStrings.analysisEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: KisouTheme.gapS),
        Text(
          AppStrings.analysisEmptyBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AnalysisSkeleton extends StatelessWidget {
  const _AnalysisSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      children: const [
        _SkeletonCard(height: 150),
        SizedBox(height: KisouTheme.gapM),
        _SkeletonCard(height: 220),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.kisou.surfaceAlt,
          borderRadius: BorderRadius.circular(KisouTheme.rMd),
        ),
      ),
    );
  }
}
