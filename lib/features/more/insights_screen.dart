import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';

import '../../models/alert.dart';
import '../../models/insight.dart';
import '../../models/insights_summary.dart';
import '../../repositories/insights_repository.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, InsightsRepository? repository})
      : _repository = repository;

  final InsightsRepository? _repository;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late final InsightsRepository _repository =
      widget._repository ?? InsightsRepository();
  InsightsSummary? _summary;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _summary = null;
    });
    try {
      final summary = await _repository.getSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load insights right now.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadInsights,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState();
    }
    if (_error != null) {
      return AppErrorState(
        message: 'We could not load insights right now.',
        onRetry: _loadInsights,
      );
    }

    final summary = _summary!;
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
          final pagePadding = AppSpacing.pagePadding(layout).copyWith(
            top: AppSpacing.x8,
            bottom: AppSpacing.x32,
          );

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business activity, translated into useful signals.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    if (summary.insights.isEmpty)
                      const AppEmptyState(
                        icon: Icons.lightbulb_outline,
                        message:
                            'Insights will appear as more business activity is recorded.',
                      )
                    else
                      _InsightGrid(
                        insights: summary.insights,
                        layout: AppBreakpoints.fromWidth(constraints.maxWidth),
                      ),
                    const SizedBox(height: AppSpacing.x32),
                    Text(
                      'Alerts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    if (summary.alerts.isEmpty)
                      const AppEmptyState(
                        icon: Icons.check_circle_outline,
                        message:
                            "You're all clear. No inventory or margin alerts right now.",
                      )
                    else
                      _AlertList(alerts: summary.alerts),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.insights, required this.layout});

  final List<Insight> insights;
  final AppLayoutSize layout;

  @override
  Widget build(BuildContext context) {
    const spacing = AppSpacing.x12;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = switch (layout) {
          AppLayoutSize.mobile => 1,
          AppLayoutSize.tablet => 2,
          AppLayoutSize.desktop => 3,
        };
        final cardWidth = (availableWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: insights
              .map(
                (insight) => SizedBox(
                  width: cardWidth,
                  child: _InsightCard(insight: insight),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = _insightColor(context, insight.severity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SeverityBadge(severity: insight.severity),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _insightIcon(insight.type),
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x12),
            Text(
              insight.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              insight.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                    height: 1.45,
                  ),
            ),
            if (insight.value != null || insight.comparisonValue != null) ...[
              const SizedBox(height: AppSpacing.x12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (insight.value != null)
                      _MetricSummary(
                        label: _metricLabel(insight),
                        value: _formatMetricValue(insight),
                      ),
                    if (insight.comparisonValue != null)
                      _MetricSummary(
                        label: 'Previous',
                        value: _formatComparisonValue(insight),
                        muted: true,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        muted ? AppTheme.secondaryText : AppTheme.secondaryText,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: muted ? AppTheme.navy : AppTheme.navy,
                ),
          ),
        ],
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: alerts
          .map((alert) => _AlertCard(alert: alert))
          .toList(growable: false),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final color = _alertColor(context, alert.severity);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_alertIcon(alert.type), color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    alert.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            if (alert.value != null) ...[
              const SizedBox(width: AppSpacing.x12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8,
                  vertical: AppSpacing.x4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  _formatAlertValue(alert),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final InsightSeverity severity;

  @override
  Widget build(BuildContext context) {
    final label = switch (severity) {
      InsightSeverity.info => 'Informational',
      InsightSeverity.positive => 'Positive',
      InsightSeverity.warning => 'Warning',
    };
    final color = _insightColor(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x8,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

IconData _insightIcon(InsightType type) {
  switch (type) {
    case InsightType.revenue:
      return Icons.trending_up;
    case InsightType.topProduct:
      return Icons.star_outline;
    case InsightType.topCategory:
      return Icons.category_outlined;
    case InsightType.profitMargin:
      return Icons.percent;
    case InsightType.customer:
      return Icons.people_outline;
    case InsightType.salesMilestone:
      return Icons.flag_outlined;
  }
}

IconData _alertIcon(AlertType type) {
  switch (type) {
    case AlertType.outOfStock:
      return Icons.remove_shopping_cart_outlined;
    case AlertType.lowStock:
      return Icons.inventory_2_outlined;
    case AlertType.lowProfitMargin:
      return Icons.warning_amber_outlined;
  }
}

Color _insightColor(BuildContext context, InsightSeverity severity) {
  switch (severity) {
    case InsightSeverity.info:
      return Theme.of(context).colorScheme.primary;
    case InsightSeverity.positive:
      return AppTheme.success;
    case InsightSeverity.warning:
      return Theme.of(context).colorScheme.error;
  }
}

Color _alertColor(BuildContext context, AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.critical:
      return Theme.of(context).colorScheme.error;
    case AlertSeverity.warning:
      return AppTheme.warning;
  }
}

String _metricLabel(Insight insight) {
  switch (insight.type) {
    case InsightType.revenue:
      return 'Revenue';
    case InsightType.topProduct:
      return 'Units sold';
    case InsightType.topCategory:
      return 'Category revenue';
    case InsightType.profitMargin:
      return 'Profit margin';
    case InsightType.customer:
      return 'Average spend';
    case InsightType.salesMilestone:
      return insight.value != null && insight.value! >= 10000
          ? 'Revenue'
          : 'Bills';
  }
}

String _formatMetricValue(Insight insight) {
  switch (insight.type) {
    case InsightType.revenue:
      return _currencyFormat(insight.value!);
    case InsightType.topProduct:
      return '${insight.value!.round()} units';
    case InsightType.topCategory:
      return _currencyFormat(insight.value!);
    case InsightType.profitMargin:
      return '${insight.value!.toStringAsFixed(1)}%';
    case InsightType.customer:
      return _currencyFormat(insight.value!);
    case InsightType.salesMilestone:
      return insight.value != null && insight.value! >= 10000
          ? _currencyFormat(insight.value!)
          : '${insight.value!.round()} bills';
  }
}

String _formatComparisonValue(Insight insight) {
  final value = insight.comparisonValue ?? 0;
  switch (insight.type) {
    case InsightType.revenue:
      return _currencyFormat(value);
    case InsightType.topProduct:
      return '${value.round()} units';
    case InsightType.topCategory:
      return _currencyFormat(value);
    case InsightType.profitMargin:
      return '${value.toStringAsFixed(1)}%';
    case InsightType.customer:
      return _currencyFormat(value);
    case InsightType.salesMilestone:
      return insight.value != null && insight.value! >= 10000
          ? _currencyFormat(value)
          : '${value.round()} bills';
  }
}

String _formatAlertValue(Alert alert) {
  if (alert.value == null) return '';
  switch (alert.type) {
    case AlertType.outOfStock:
    case AlertType.lowStock:
      return '${alert.value!.round()} units';
    case AlertType.lowProfitMargin:
      return '${alert.value!.toStringAsFixed(1)}%';
  }
}

String _currencyFormat(double value) {
  final rounded = value.round();
  final formatted = rounded.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match match) => '${match[1]},',
      );
  return '₹$formatted';
}
