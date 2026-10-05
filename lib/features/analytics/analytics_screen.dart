import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_states.dart';
import '../../models/analytics_date_filter.dart';
import '../../models/analytics_summary.dart';
import '../../repositories/analytics_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, AnalyticsRepository? repository})
      : _repository = repository;

  final AnalyticsRepository? _repository;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final AnalyticsRepository _repository =
      widget._repository ?? AnalyticsRepository();
  AnalyticsSummary? _summary;
  bool _isLoading = false;
  Object? _error;
  AnalyticsDateFilter _dateFilter = const AnalyticsDateFilter.allTime();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _summary = null;
      _error = null;
    });

    try {
      final summary = await _repository.getSummary(dateFilter: _dateFilter);
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

  Future<void> _selectDateFilter(AnalyticsDateFilterType type) async {
    if (_isLoading) return;
    if (type == AnalyticsDateFilterType.customRange) {
      final currentRange =
          _dateFilter.type == type ? _dateFilter.resolve() : null;
      final selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: currentRange == null
            ? null
            : DateTimeRange(
                start: currentRange.start!,
                end: currentRange.end!.subtract(const Duration(days: 1)),
              ),
      );
      if (!mounted || selectedRange == null) return;
      _dateFilter = AnalyticsDateFilter.custom(
        startDate: selectedRange.start,
        endDate: selectedRange.end,
      );
    } else {
      _dateFilter = _filterForType(type);
    }
    setState(() => _summary = null);
    await _loadAnalytics();
  }

  AnalyticsDateFilter _filterForType(AnalyticsDateFilterType type) {
    switch (type) {
      case AnalyticsDateFilterType.allTime:
        return const AnalyticsDateFilter.allTime();
      case AnalyticsDateFilterType.today:
        return const AnalyticsDateFilter.today();
      case AnalyticsDateFilterType.yesterday:
        return const AnalyticsDateFilter.yesterday();
      case AnalyticsDateFilterType.thisWeek:
        return const AnalyticsDateFilter.thisWeek();
      case AnalyticsDateFilterType.thisMonth:
        return const AnalyticsDateFilter.thisMonth();
      case AnalyticsDateFilterType.customRange:
        return _dateFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analytics',
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
        message: 'We could not load analytics right now.',
        onRetry: _loadAnalytics,
      );
    }

    final summary = _summary!;
    final layoutSize =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
    final isMobile = layoutSize == AppLayoutSize.mobile;
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
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
                    'Analytics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    'Understand your sales and business performance.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: isMobile ? AppSpacing.x16 : AppSpacing.x20),
                  _DateFilterControl(
                    filter: _dateFilter,
                    isLoading: _isLoading,
                    onChanged: _selectDateFilter,
                  ),
                  if (summary.sales.totalBills == 0 &&
                      _dateFilter.type != AnalyticsDateFilterType.allTime) ...[
                    const SizedBox(height: AppSpacing.x12),
                    const _FilteredEmptyState(),
                  ],
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Sales overview'),
                  const SizedBox(height: AppSpacing.x12),
                  _SalesOverview(summary: summary, width: constraints.maxWidth),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Profit overview'),
                  const SizedBox(height: AppSpacing.x12),
                  _ProfitOverview(
                      summary: summary, width: constraints.maxWidth),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Profit analysis'),
                  const SizedBox(height: AppSpacing.x12),
                  _ProfitAnalysis(
                    summary: summary,
                    width: constraints.maxWidth,
                  ),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Sales trend'),
                  const SizedBox(height: AppSpacing.x12),
                  _SalesTrend(data: summary.salesByDate),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Product performance'),
                  const SizedBox(height: AppSpacing.x12),
                  _ProductPerformance(
                    products: summary.productPerformance,
                    width: constraints.maxWidth,
                  ),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Category performance'),
                  const SizedBox(height: AppSpacing.x12),
                  _CategoryPerformance(
                    categories: summary.categoryPerformance,
                    width: constraints.maxWidth,
                  ),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Payment methods'),
                  const SizedBox(height: AppSpacing.x12),
                  _PaymentMethods(methods: summary.paymentMethods),
                  SizedBox(height: isMobile ? AppSpacing.x20 : AppSpacing.x24),
                  const _SectionHeading(title: 'Customer analytics'),
                  const SizedBox(height: AppSpacing.x12),
                  _CustomerAnalytics(
                    summary: summary,
                    width: constraints.maxWidth,
                  ),
                  const SizedBox(height: AppSpacing.x20),
                  if (summary.sales.totalBills == 0) ...[
                    const SizedBox(height: AppSpacing.x20),
                    const _EmptyState(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _DateFilterControl extends StatelessWidget {
  const _DateFilterControl({
    required this.filter,
    required this.isLoading,
    required this.onChanged,
  });

  final AnalyticsDateFilter filter;
  final bool isLoading;
  final ValueChanged<AnalyticsDateFilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.fromWidth(
          MediaQuery.sizeOf(context).width,
        ) ==
        AppLayoutSize.desktop;
    final rangePicker = DropdownButtonFormField<AnalyticsDateFilterType>(
      value: filter.type,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Date range'),
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) onChanged(value);
            },
      items: AnalyticsDateFilterType.values
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(_dateFilterLabel(type)),
            ),
          )
          .toList(growable: false),
    );
    final customRangeLabel = filter.type == AnalyticsDateFilterType.customRange
        ? Text(
            _selectedPeriodLabel(filter),
            style: Theme.of(context).textTheme.bodySmall,
          )
        : null;
    final resetButton = filter.type != AnalyticsDateFilterType.allTime
        ? TextButton.icon(
            onPressed: isLoading
                ? null
                : () => onChanged(AnalyticsDateFilterType.allTime),
            icon: const Icon(Icons.clear),
            label: const Text('Reset range'),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: isDesktop
            ? Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      'Filter analytics',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(child: rangePicker),
                  if (customRangeLabel != null) ...[
                    const SizedBox(width: AppSpacing.x12),
                    customRangeLabel,
                  ],
                  if (resetButton != null) resetButton,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  rangePicker,
                  if (customRangeLabel != null) ...[
                    const SizedBox(height: AppSpacing.x8),
                    customRangeLabel,
                  ],
                  if (resetButton != null)
                    Align(alignment: Alignment.centerRight, child: resetButton),
                ],
              ),
      ),
    );
  }
}

class _SalesOverview extends StatelessWidget {
  const _SalesOverview({required this.summary, required this.width});

  final AnalyticsSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Revenue',
        value: _formatCurrency(summary.sales.totalRevenue),
        icon: Icons.payments_outlined,
      ),
      _MetricCard(
        label: 'Bills',
        value: _formatNumber(summary.sales.totalBills),
        icon: Icons.receipt_long_outlined,
      ),
      _MetricCard(
        label: 'Items Sold',
        value: _formatNumber(summary.sales.totalItemsSold),
        icon: Icons.shopping_bag_outlined,
      ),
      _MetricCard(
        label: 'Average Order Value',
        value: _formatCurrency(summary.sales.averageOrderValue),
        icon: Icons.shopping_cart_checkout_outlined,
      ),
    ];
    return _MetricGrid(width: width, children: cards);
  }
}

class _ProfitOverview extends StatelessWidget {
  const _ProfitOverview({required this.summary, required this.width});

  final AnalyticsSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _MetricGrid(
      width: width,
      children: [
        _MetricCard(
          label: 'Total Profit',
          value: _formatCurrency(summary.profit.totalProfit),
          icon: Icons.trending_up,
        ),
        _MetricCard(
          label: 'Profit Margin',
          value: '${summary.profit.profitMargin.toStringAsFixed(1)}%',
          icon: Icons.percent,
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.fromWidth(width);
    final columns = switch (layout) {
      AppLayoutSize.mobile || AppLayoutSize.tablet => 2,
      AppLayoutSize.desktop => 4,
    };
    final cardHeight = switch (layout) {
      AppLayoutSize.mobile => 104.0,
      AppLayoutSize.tablet => 110.0,
      AppLayoutSize.desktop => 112.0,
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
          children: children,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.secondary, size: 18),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitAnalysis extends StatelessWidget {
  const _ProfitAnalysis({required this.summary, required this.width});

  final AnalyticsSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final profit = summary.profit;
    return _MetricGrid(
      width: width,
      children: [
        _MetricCard(
          label: 'Revenue',
          value: _formatCurrency(profit.revenue),
          icon: Icons.payments_outlined,
        ),
        _MetricCard(
          label: 'Cost',
          value: _formatCurrency(profit.totalCost),
          icon: Icons.inventory_outlined,
        ),
        _MetricCard(
          label: 'Profit',
          value: _formatCurrency(profit.totalProfit),
          icon: Icons.trending_up,
        ),
        _MetricCard(
          label: 'Profit Margin',
          value: '${profit.profitMargin.toStringAsFixed(1)}%',
          icon: Icons.percent,
        ),
      ],
    );
  }
}

class _SalesTrend extends StatelessWidget {
  const _SalesTrend({required this.data});

  final List<SalesByDateSummary> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: data.length < 2
            ? SizedBox(
                height: 170,
                child: Center(
                  child: Text(
                    data.isEmpty
                        ? 'Sales trend will appear after sales are recorded.'
                        : 'More sales data is needed to show a trend.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(
                      constraints.maxWidth,
                      data.length * 76.0 + 70,
                    ),
                    height: 220,
                    child: CustomPaint(
                      painter: _SalesTrendPainter(
                        data: data,
                        lineColor: Theme.of(context).colorScheme.primary,
                        gridColor: Theme.of(context).colorScheme.outlineVariant,
                        textStyle: Theme.of(context).textTheme.bodySmall!,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SalesTrendPainter extends CustomPainter {
  _SalesTrendPainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.textStyle,
  });

  final List<SalesByDateSummary> data;
  final Color lineColor;
  final Color gridColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 58.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 36.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
    final maxRevenue = data.map((entry) => entry.revenue).reduce(math.max);
    final yMax = maxRevenue <= 0 ? 1.0 : maxRevenue;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = lineColor;

    for (var index = 0; index <= 3; index++) {
      final y = chart.bottom - (chart.height * index / 3);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        _formatCurrency(yMax * index / 3),
        Offset(0, y - 8),
        textStyle,
        maxWidth: left - 8,
      );
    }

    final points = <Offset>[];
    for (var index = 0; index < data.length; index++) {
      final x = data.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (data.length - 1);
      final y = chart.bottom - chart.height * data[index].revenue / yMax;
      points.add(Offset(x, y));
      canvas.drawCircle(points.last, 5, pointPaint);
      _drawText(
        canvas,
        _formatDate(data[index].date),
        Offset(x - 28, chart.bottom + 10),
        textStyle,
        maxWidth: 56,
      );
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SalesTrendPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

class _ProductPerformance extends StatelessWidget {
  const _ProductPerformance({required this.products, required this.width});

  final List<ProductPerformanceSummary> products;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _SectionEmpty(
        message: 'Product performance will appear after sales are recorded.',
      );
    }
    final rankedProducts = products.toList(growable: false)
      ..sort((first, second) => second.profit.compareTo(first.profit));
    if (width >= 700) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Cost')),
              DataColumn(label: Text('Profit')),
              DataColumn(label: Text('Margin')),
            ],
            rows: rankedProducts.map((product) {
              return DataRow(cells: [
                DataCell(Text(product.productName)),
                DataCell(Text(product.sku.isEmpty ? '—' : product.sku)),
                DataCell(Text(_formatNumber(product.quantitySold))),
                DataCell(Text(_formatCurrency(product.revenue))),
                DataCell(Text(_formatCurrency(product.totalCost))),
                DataCell(Text(_formatCurrency(product.profit))),
                DataCell(Text(_formatMargin(product.profitMargin))),
              ]);
            }).toList(growable: false),
          ),
        ),
      );
    }
    return Column(
      children: rankedProducts
          .map((product) => _ProductCard(product: product))
          .toList(growable: false),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductPerformanceSummary product;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.productName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (product.sku.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'SKU: ${product.sku}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _DataLabel(
                  label: 'Qty',
                  value: _formatNumber(product.quantitySold),
                ),
                _DataLabel(
                  label: 'Revenue',
                  value: _formatCurrency(product.revenue),
                ),
                _DataLabel(
                  label: 'Cost',
                  value: _formatCurrency(product.totalCost),
                ),
                _DataLabel(
                  label: 'Profit',
                  value: _formatCurrency(product.profit),
                ),
                _DataLabel(
                  label: 'Margin',
                  value: _formatMargin(product.profitMargin),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({required this.methods});

  final List<PaymentMethodSummary> methods;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return const _SectionEmpty(
        message: 'Payment method data will appear after sales are recorded.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(220, constraints.maxWidth).toDouble();
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: methods
              .map(
                (method) => SizedBox(
                  width: cardWidth,
                  child: Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(method.paymentMethod),
                      subtitle:
                          Text('${_formatNumber(method.billCount)} bills'),
                      trailing: Text(
                        _formatCurrency(method.revenue),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CategoryPerformance extends StatelessWidget {
  const _CategoryPerformance({required this.categories, required this.width});

  final List<CategoryPerformanceSummary> categories;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _SectionEmpty(
        message:
            'Category analysis will appear for new sales recorded with category tracking.',
      );
    }
    final rankedCategories = categories.toList(growable: false)
      ..sort((first, second) => second.profit.compareTo(first.profit));
    if (width >= 700) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Cost')),
              DataColumn(label: Text('Profit')),
              DataColumn(label: Text('Margin')),
            ],
            rows: rankedCategories.map((category) {
              return DataRow(cells: [
                DataCell(Text(category.category)),
                DataCell(Text(_formatNumber(category.quantitySold))),
                DataCell(Text(_formatCurrency(category.revenue))),
                DataCell(Text(_formatCurrency(category.totalCost))),
                DataCell(Text(_formatCurrency(category.profit))),
                DataCell(Text(_formatMargin(category.profitMargin))),
              ]);
            }).toList(growable: false),
          ),
        ),
      );
    }
    return Column(
      children: rankedCategories
          .map((category) => _CategoryCard(category: category))
          .toList(growable: false),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final CategoryPerformanceSummary category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _DataLabel(label: 'Category', value: category.category),
            _DataLabel(
              label: 'Qty',
              value: _formatNumber(category.quantitySold),
            ),
            _DataLabel(
              label: 'Revenue',
              value: _formatCurrency(category.revenue),
            ),
            _DataLabel(
              label: 'Cost',
              value: _formatCurrency(category.totalCost),
            ),
            _DataLabel(
              label: 'Profit',
              value: _formatCurrency(category.profit),
            ),
            _DataLabel(
              label: 'Margin',
              value: _formatMargin(category.profitMargin),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerAnalytics extends StatelessWidget {
  const _CustomerAnalytics({required this.summary, required this.width});

  final AnalyticsSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    final customers = summary.customers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CustomerMetrics(summary: summary, width: width),
        const SizedBox(height: 14),
        if (customers.isEmpty)
          const _SectionEmpty(
            message:
                'Customer analytics will appear when sales are recorded for named customers.',
          )
        else if (width >= 700)
          _CustomerTable(customers: customers)
        else
          _CustomerCards(customers: customers),
        if (summary.walkIn != null) ...[
          const SizedBox(height: 14),
          _WalkInCard(summary: summary.walkIn!),
        ],
      ],
    );
  }
}

class _CustomerMetrics extends StatelessWidget {
  const _CustomerMetrics({required this.summary, required this.width});

  final AnalyticsSummary summary;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _MetricGrid(
      width: width,
      children: [
        _MetricCard(
          label: 'Customers',
          value: _formatNumber(summary.identifiableCustomerCount),
          icon: Icons.people_outline,
        ),
        _MetricCard(
          label: 'Repeat Customers',
          value: _formatNumber(summary.repeatCustomerCount),
          icon: Icons.repeat,
        ),
        _MetricCard(
          label: 'Customer Revenue',
          value: _formatCurrency(summary.identifiableCustomerRevenue),
          icon: Icons.person_outline,
        ),
        _MetricCard(
          label: 'Average Customer Spend',
          value: _formatCurrency(summary.averageCustomerSpend),
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({required this.customers});

  final List<CustomerPerformanceSummary> customers;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Bills')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Total Spent')),
            DataColumn(label: Text('AOV')),
            DataColumn(label: Text('Last Purchase')),
          ],
          rows: customers.map((customer) {
            return DataRow(cells: [
              DataCell(Text(customer.customerName)),
              DataCell(Text(_formatNumber(customer.billCount))),
              DataCell(Text(_formatNumber(customer.itemsPurchased))),
              DataCell(Text(_formatCurrency(customer.totalSpent))),
              DataCell(Text(_formatCurrency(customer.averageOrderValue))),
              DataCell(Text(_formatDate(customer.lastPurchaseDate))),
            ]);
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _CustomerCards extends StatelessWidget {
  const _CustomerCards({required this.customers});

  final List<CustomerPerformanceSummary> customers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: customers
          .map(
            (customer) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _DataLabel(
                      label: 'Customer',
                      value: customer.customerName,
                    ),
                    _DataLabel(
                      label: 'Bills',
                      value: _formatNumber(customer.billCount),
                    ),
                    _DataLabel(
                      label: 'Items',
                      value: _formatNumber(customer.itemsPurchased),
                    ),
                    _DataLabel(
                      label: 'Total Spent',
                      value: _formatCurrency(customer.totalSpent),
                    ),
                    _DataLabel(
                      label: 'AOV',
                      value: _formatCurrency(customer.averageOrderValue),
                    ),
                    _DataLabel(
                      label: 'Last Purchase',
                      value: _formatDate(customer.lastPurchaseDate),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _WalkInCard extends StatelessWidget {
  const _WalkInCard({required this.summary});

  final WalkInSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: const Text('Walk-in Customer'),
        subtitle: Text(
          '${_formatNumber(summary.billCount)} bills · '
          '${_formatNumber(summary.itemsPurchased)} items',
        ),
        trailing: Text(
          _formatCurrency(summary.totalSpent),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DataLabel extends StatelessWidget {
  const _DataLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.insights_outlined,
      message: message,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.bar_chart_outlined,
      message: 'Analytics will appear here after you record your first sale.',
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.event_busy_outlined,
      message: 'No sales found for the selected period.',
    );
  }
}

String _formatCurrency(double value) => '₹${_formatNumber(value.round())}';

String _formatMargin(double value) => '${value.toStringAsFixed(1)}%';

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _formatDate(DateTime date) => '${date.day}/${date.month}';

String _dateFilterLabel(AnalyticsDateFilterType type) {
  switch (type) {
    case AnalyticsDateFilterType.allTime:
      return 'All Time';
    case AnalyticsDateFilterType.today:
      return 'Today';
    case AnalyticsDateFilterType.yesterday:
      return 'Yesterday';
    case AnalyticsDateFilterType.thisWeek:
      return 'This Week';
    case AnalyticsDateFilterType.thisMonth:
      return 'This Month';
    case AnalyticsDateFilterType.customRange:
      return 'Custom Range';
  }
}

String _selectedPeriodLabel(AnalyticsDateFilter filter) {
  if (filter.type == AnalyticsDateFilterType.allTime) return 'All Time';
  if (filter.type == AnalyticsDateFilterType.customRange) {
    final range = filter.resolve();
    return '${_formatPeriodDate(range.start!)} – '
        '${_formatPeriodDate(range.end!.subtract(const Duration(days: 1)))}';
  }
  return _dateFilterLabel(filter.type);
}

String _formatPeriodDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
