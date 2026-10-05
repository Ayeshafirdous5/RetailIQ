import 'analytics_date_filter.dart';
import 'analytics_summary.dart';
import 'alert.dart';
import 'bill.dart';
import 'insight.dart';
import 'product.dart';

const lowProfitMarginThreshold = 10.0;
const salesMilestoneBillThreshold = 10;
const salesMilestoneRevenueThreshold = 10000.0;

class InsightsSummary {
  const InsightsSummary({
    required this.insights,
    required this.alerts,
  });

  const InsightsSummary.empty()
      : insights = const [],
        alerts = const [];

  final List<Insight> insights;
  final List<Alert> alerts;

  factory InsightsSummary.fromData({
    required Iterable<Bill> bills,
    required Iterable<Product> products,
    AnalyticsDateFilter? dateFilter,
    DateTime? now,
  }) {
    final allBills = bills.toList(growable: false);
    final filter = dateFilter ?? const AnalyticsDateFilter.allTime();
    final currentBills = _filterBills(allBills, filter, now);
    final current = AnalyticsSummary.fromBills(currentBills);
    final previous = _previousSummary(allBills, filter, now);
    final insights = <Insight>[];

    _addRevenueInsight(insights, current, previous);
    _addTopProductInsight(insights, current);
    _addTopCategoryInsight(insights, current);
    _addProfitInsight(insights, current);
    _addCustomerInsight(insights, current);
    _addMilestoneInsight(insights, current);

    return InsightsSummary(
      insights: insights,
      alerts: _buildAlerts(products, current),
    );
  }

  static AnalyticsSummary? _previousSummary(
    List<Bill> bills,
    AnalyticsDateFilter filter,
    DateTime? now,
  ) {
    if (filter.type == AnalyticsDateFilterType.allTime) return null;
    final currentRange = filter.resolve(now);
    final start = currentRange.start!;
    final end = currentRange.end!;
    final duration = end.difference(start);
    final previousRange = AnalyticsDateRange(
      start: start.subtract(duration),
      end: start,
    );
    final previousBills = bills.where(
      (bill) => previousRange.contains(bill.createdAt),
    );
    return AnalyticsSummary.fromBills(previousBills);
  }

  static List<Bill> _filterBills(
    List<Bill> bills,
    AnalyticsDateFilter filter,
    DateTime? now,
  ) {
    final range = filter.resolve(now);
    if (range.isAllTime) return bills;
    return bills
        .where((bill) => range.contains(bill.createdAt))
        .toList(growable: false);
  }

  static void _addRevenueInsight(
    List<Insight> insights,
    AnalyticsSummary current,
    AnalyticsSummary? previous,
  ) {
    if (previous == null || previous.sales.totalBills == 0) return;
    final currentRevenue = current.sales.totalRevenue;
    final previousRevenue = previous.sales.totalRevenue;
    final difference = currentRevenue - previousRevenue;
    if (difference == 0) {
      insights.add(const Insight(
        type: InsightType.revenue,
        title: 'Revenue unchanged',
        message: 'Revenue matched the previous period.',
        severity: InsightSeverity.info,
        value: 0,
      ));
      return;
    }
    final percentage =
        previousRevenue == 0 ? null : (difference / previousRevenue) * 100;
    final increased = difference > 0;
    insights.add(Insight(
      type: InsightType.revenue,
      title: increased ? 'Revenue increased' : 'Revenue decreased',
      message: percentage == null
          ? (increased
              ? 'Revenue increased from zero in the previous period.'
              : 'Revenue decreased compared with the previous period.')
          : 'Revenue ${increased ? 'increased' : 'decreased'} by '
              '${percentage.abs().toStringAsFixed(1)}% compared with the previous period.',
      severity: increased ? InsightSeverity.positive : InsightSeverity.warning,
      value: currentRevenue,
      comparisonValue: previousRevenue,
    ));
  }

  static void _addTopProductInsight(
    List<Insight> insights,
    AnalyticsSummary summary,
  ) {
    if (summary.productPerformance.isEmpty) return;
    final product = summary.productPerformance.reduce(
      (first, second) =>
          first.quantitySold >= second.quantitySold ? first : second,
    );
    insights.add(Insight(
      type: InsightType.topProduct,
      title: 'Top-selling product',
      message: '${product.productName} sold ${product.quantitySold} units.',
      severity: InsightSeverity.positive,
      value: product.quantitySold.toDouble(),
      relatedEntityName: product.productName,
    ));
  }

  static void _addTopCategoryInsight(
    List<Insight> insights,
    AnalyticsSummary summary,
  ) {
    if (summary.categoryPerformance.isEmpty) return;
    final category = summary.categoryPerformance.reduce(
      (first, second) => first.revenue >= second.revenue ? first : second,
    );
    insights.add(Insight(
      type: InsightType.topCategory,
      title: 'Highest-revenue category',
      message: '${category.category} generated ₹${category.revenue.round()}.',
      severity: InsightSeverity.positive,
      value: category.revenue,
      relatedEntityName: category.category,
    ));
  }

  static void _addProfitInsight(
    List<Insight> insights,
    AnalyticsSummary summary,
  ) {
    if (summary.sales.totalBills == 0) return;
    final margin = summary.profit.profitMargin;
    if (margin < lowProfitMarginThreshold) {
      insights.add(Insight(
        type: InsightType.profitMargin,
        title: 'Low profit margin',
        message: 'Overall profit margin is ${margin.toStringAsFixed(1)}%.',
        severity: InsightSeverity.warning,
        value: margin,
      ));
    } else {
      insights.add(Insight(
        type: InsightType.profitMargin,
        title: 'Healthy profit margin',
        message: 'Overall profit margin is ${margin.toStringAsFixed(1)}%.',
        severity: InsightSeverity.positive,
        value: margin,
      ));
    }
  }

  static void _addCustomerInsight(
    List<Insight> insights,
    AnalyticsSummary summary,
  ) {
    if (summary.identifiableCustomerCount == 0) return;
    insights.add(Insight(
      type: InsightType.customer,
      title: 'Customer activity',
      message: '${summary.identifiableCustomerCount} identifiable customers '
          'averaged ₹${summary.averageCustomerSpend.round()} per customer.',
      severity: InsightSeverity.info,
      value: summary.averageCustomerSpend,
    ));
  }

  static void _addMilestoneInsight(
    List<Insight> insights,
    AnalyticsSummary summary,
  ) {
    final hasBillMilestone =
        summary.sales.totalBills >= salesMilestoneBillThreshold;
    final hasRevenueMilestone =
        summary.sales.totalRevenue >= salesMilestoneRevenueThreshold;
    if (!hasBillMilestone && !hasRevenueMilestone) return;
    final message = hasRevenueMilestone
        ? 'Revenue has reached ₹${summary.sales.totalRevenue.round()}.'
        : '${summary.sales.totalBills} bills have been recorded.';
    insights.add(Insight(
      type: InsightType.salesMilestone,
      title: 'Sales milestone reached',
      message: message,
      severity: InsightSeverity.positive,
      value: hasRevenueMilestone
          ? summary.sales.totalRevenue
          : summary.sales.totalBills.toDouble(),
    ));
  }

  static List<Alert> _buildAlerts(
    Iterable<Product> products,
    AnalyticsSummary summary,
  ) {
    final alerts = <Alert>[];
    for (final product in products) {
      if (product.stockQuantity == 0) {
        alerts.add(Alert(
          type: AlertType.outOfStock,
          title: 'Out of stock',
          message: '${product.name} has no remaining stock.',
          severity: AlertSeverity.critical,
          relatedEntityName: product.name,
          value: product.stockQuantity.toDouble(),
        ));
      } else if (product.stockQuantity <= product.reorderLevel) {
        alerts.add(Alert(
          type: AlertType.lowStock,
          title: 'Low stock',
          message: '${product.name} is at ${product.stockQuantity} units.',
          severity: AlertSeverity.warning,
          relatedEntityName: product.name,
          value: product.stockQuantity.toDouble(),
        ));
      }
    }
    for (final product in summary.productPerformance) {
      if (product.profitMargin < lowProfitMarginThreshold) {
        alerts.add(Alert(
          type: AlertType.lowProfitMargin,
          title: 'Low profit margin',
          message:
              '${product.productName} has a ${product.profitMargin.toStringAsFixed(1)}% margin.',
          severity: AlertSeverity.warning,
          relatedEntityName: product.productName,
          value: product.profitMargin,
        ));
      }
    }
    for (final category in summary.categoryPerformance) {
      if (category.profitMargin < lowProfitMarginThreshold) {
        alerts.add(Alert(
          type: AlertType.lowProfitMargin,
          title: 'Low category margin',
          message:
              '${category.category} has a ${category.profitMargin.toStringAsFixed(1)}% margin.',
          severity: AlertSeverity.warning,
          relatedEntityName: category.category,
          value: category.profitMargin,
        ));
      }
    }
    return alerts;
  }
}
