import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';

import '../../models/alert.dart';
import '../../models/dashboard_summary.dart';
import '../../models/insight.dart';
import '../../models/insights_summary.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/insights_repository.dart';
import '../more/insights_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    DashboardRepository? repository,
    InsightsRepository? insightsRepository,
  })  : _repository = repository,
        _insightsRepository = insightsRepository;

  final DashboardRepository? _repository;
  final InsightsRepository? _insightsRepository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository =
      widget._repository ?? DashboardRepository();
  late final InsightsRepository _insightsRepository =
      widget._insightsRepository ?? InsightsRepository();
  DashboardSummary? _summary;
  Object? _error;
  bool _isLoading = true;
  InsightsSummary? _insightsSummary;
  Object? _insightsError;
  bool _isInsightsLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _loadDashboardSummary() async {
    if (_isLoading && _summary != null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _repository.getSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInsights() async {
    if (_isInsightsLoading) return;
    setState(() {
      _isInsightsLoading = true;
      _insightsError = null;
    });

    try {
      final summary = await _insightsRepository.getSummary();
      if (!mounted) return;
      setState(() {
        _insightsSummary = summary;
        _isInsightsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _insightsError = error;
        _isInsightsLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if ((_isLoading && _summary != null) || _isInsightsLoading) return;
    await Future.wait<void>([
      _loadDashboardSummary(),
      _loadInsights(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: _isLoading || _isInsightsLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _summary == null) {
      return const AppLoadingState();
    }
    if (_error != null && _summary == null) {
      return AppErrorState(
        message: 'We could not load your dashboard right now.',
        onRetry: _refresh,
      );
    }

    final summary = _summary!;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final layoutSize = AppBreakpoints.fromWidth(viewportWidth);
    final isMobile = layoutSize == AppLayoutSize.mobile;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding(layoutSize),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    'Current business performance at a glance.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.secondaryText),
                  ),
                  SizedBox(height: isMobile ? AppSpacing.x16 : AppSpacing.x20),
                  _KpiGrid(summary: summary, width: viewportWidth),
                  SizedBox(height: isMobile ? AppSpacing.x12 : AppSpacing.x20),
                  Text(
                    'Inventory status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  _InventoryStatus(summary: summary),
                  SizedBox(height: isMobile ? AppSpacing.x12 : AppSpacing.x20),
                  _DashboardInsights(
                    summary: _insightsSummary,
                    isLoading: _isInsightsLoading,
                    error: _insightsError,
                    onRetry: _loadInsights,
                    width: viewportWidth,
                  ),
                  if (_isEmpty(summary)) ...[
                    const SizedBox(height: AppSpacing.x20),
                    _EmptyState(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$greeting 👋';
  }

  bool _isEmpty(DashboardSummary summary) =>
      summary.totalRevenue == 0 &&
      summary.totalBills == 0 &&
      summary.totalItemsSold == 0 &&
      summary.totalProfit == 0 &&
      summary.totalPurchases == 0 &&
      summary.totalInventoryValue == 0 &&
      summary.lowStockProducts == 0 &&
      summary.outOfStockProducts == 0;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.width});

  final DashboardSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = switch (AppBreakpoints.fromWidth(width)) {
      AppLayoutSize.mobile => 1,
      AppLayoutSize.tablet => 2,
      AppLayoutSize.desktop => 3,
    };
    final cards = [
      _KpiCard(
          label: 'Revenue',
          value: _formatCurrency(summary.totalRevenue),
          icon: Icons.payments_outlined,
          compact: columns == 1,
          emphasized: true),
      _KpiCard(
          label: 'Bills',
          value: _formatCount(summary.totalBills),
          icon: Icons.receipt_long_outlined,
          compact: columns == 1),
      _KpiCard(
          label: 'Items Sold',
          value: _formatCount(summary.totalItemsSold),
          icon: Icons.shopping_bag_outlined,
          compact: columns == 1),
      _KpiCard(
          label: 'Profit',
          value: _formatCurrency(summary.totalProfit),
          icon: Icons.trending_up,
          compact: columns == 1,
          emphasized: true),
      _KpiCard(
          label: 'Purchases',
          value: _formatCurrency(summary.totalPurchases),
          icon: Icons.local_shipping_outlined,
          compact: columns == 1),
      _KpiCard(
          label: 'Inventory Value',
          value: _formatCurrency(summary.totalInventoryValue),
          icon: Icons.inventory_2_outlined,
          compact: columns == 1),
    ];
    final cardHeight = switch (AppBreakpoints.fromWidth(width)) {
      AppLayoutSize.mobile => 88.0,
      AppLayoutSize.tablet => 122.0,
      AppLayoutSize.desktop => 132.0,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - AppSpacing.x12 * (columns - 1)) / columns;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.x12,
          mainAxisSpacing: AppSpacing.x12,
          childAspectRatio: cardWidth / cardHeight,
          children: cards,
        );
      },
    );
  }
}

class _DashboardInsights extends StatelessWidget {
  const _DashboardInsights({
    required this.summary,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.width,
  });

  final InsightsSummary? summary;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (isLoading && summary == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null && summary == null) {
      return _InsightsErrorState(onRetry: onRetry);
    }

    final insightsSummary = summary!;
    final alerts = _buildAlerts(context, insightsSummary);
    final insights = _buildInsights(context, insightsSummary);
    if (AppBreakpoints.fromWidth(width) == AppLayoutSize.desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: alerts),
          const SizedBox(width: AppSpacing.x20),
          Expanded(child: insights),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        alerts,
        SizedBox(
          height: AppBreakpoints.fromWidth(width) == AppLayoutSize.mobile
              ? AppSpacing.x12
              : AppSpacing.x20,
        ),
        insights,
      ],
    );
  }

  Widget _buildAlerts(BuildContext context, InsightsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeading(
          title: 'Alerts',
          showViewAll: summary.alerts.length > 3,
        ),
        const SizedBox(height: AppSpacing.x8),
        if (summary.alerts.isEmpty)
          const _DashboardNotice(
            icon: Icons.check_circle_outline,
            message:
                "You're all clear. No inventory or margin alerts right now.",
            color: AppTheme.success,
          )
        else
          _DashboardAlertList(
            alerts: summary.alerts.take(3).toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildInsights(BuildContext context, InsightsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeading(
          title: 'Business insights',
          showViewAll: summary.insights.length > 3,
        ),
        const SizedBox(height: AppSpacing.x8),
        if (summary.insights.isEmpty)
          const _DashboardNotice(
            icon: Icons.lightbulb_outline,
            message:
                'Insights will appear as more business activity is recorded.',
            color: AppTheme.teal,
          )
        else
          _DashboardInsightList(
            insights: summary.insights.take(3).toList(growable: false),
          ),
      ],
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  const _DashboardSectionHeading({
    required this.title,
    required this.showViewAll,
  });

  final String title;
  final bool showViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (showViewAll)
          TextButton(
            onPressed: () => _openInsights(context),
            child: const Text('View All Insights'),
          ),
      ],
    );
  }
}

class _DashboardAlertList extends StatelessWidget {
  const _DashboardAlertList({required this.alerts});

  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: alerts
          .map((alert) => _DashboardAlertCard(alert: alert))
          .toList(growable: false),
    );
  }
}

class _DashboardAlertCard extends StatelessWidget {
  const _DashboardAlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: isMobile ? AppSpacing.x8 : AppSpacing.x12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _alertIcon(alert.type),
              color: _alertColor(context, alert.severity),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    alert.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardInsightList extends StatelessWidget {
  const _DashboardInsightList({required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights
          .map((insight) => _DashboardInsightCard(insight: insight))
          .toList(growable: false),
    );
  }
}

class _DashboardInsightCard extends StatelessWidget {
  const _DashboardInsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile;
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? AppSpacing.x8 : 10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: isMobile ? AppSpacing.x8 : AppSpacing.x12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _insightIcon(insight.type),
              color: _insightColor(context, insight.severity),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(insight.message),
                  if (insight.value != null ||
                      insight.comparisonValue != null) ...[
                    const SizedBox(height: AppSpacing.x8),
                    Wrap(
                      spacing: AppSpacing.x12,
                      runSpacing: AppSpacing.x4,
                      children: [
                        if (insight.value != null)
                          Text(
                            'Value: ${_formatInsightValue(insight.value!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (insight.comparisonValue != null)
                          Text(
                            'Previous: ${_formatInsightValue(insight.comparisonValue!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsErrorState extends StatelessWidget {
  const _InsightsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: AppSpacing.x12),
            const Expanded(
                child:
                    Text('We could not load insights and alerts right now.')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.compact,
      this.emphasized = false});

  final String label;
  final String value;
  final IconData icon;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.x12 : AppSpacing.x16,
          vertical: compact ? AppSpacing.x8 : AppSpacing.x12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: emphasized ? colors.secondary : AppTheme.secondaryText,
              size: compact ? 22 : 24,
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(value,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: compact
                                    ? (emphasized ? 24 : 23)
                                    : (emphasized ? 27 : 25),
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryStatus extends StatelessWidget {
  const _InventoryStatus({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lowStock = _StatusItem(
          label: 'Low Stock',
          value: summary.lowStockProducts,
          icon: Icons.warning_amber_outlined,
          color: AppTheme.warning,
        );
        final outOfStock = _StatusItem(
          label: 'Out of Stock',
          value: summary.outOfStockProducts,
          icon: Icons.remove_shopping_cart_outlined,
          color: AppTheme.error,
        );
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              lowStock,
              const SizedBox(height: AppSpacing.x8),
              outOfStock,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: lowStock),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: outOfStock),
          ],
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: AppSpacing.x8,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Text(
              _formatCount(value),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Start by creating a bill or adding products to see your business data here.',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.navy,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCurrency(double value) => '₹${_formatNumber(value.round())}';

String _formatCount(int value) => _formatNumber(value);

void _openInsights(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const InsightsScreen()),
  );
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

String _formatInsightValue(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
