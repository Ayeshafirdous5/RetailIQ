import 'package:flutter_test/flutter_test.dart';
import 'package:retail_iq/models/analytics_date_filter.dart';
import 'package:retail_iq/models/alert.dart';
import 'package:retail_iq/models/bill.dart';
import 'package:retail_iq/models/insight.dart';
import 'package:retail_iq/models/insights_summary.dart';
import 'package:retail_iq/models/product.dart';

void main() {
  final baseDate = DateTime(2026, 9, 22, 12);

  Bill bill({
    required String id,
    required DateTime createdAt,
    required List<BillItem> items,
    String paymentMethod = 'Cash',
    String? customerId,
    String customerName = 'Walk-in Customer',
    double discount = 0,
  }) {
    return Bill(
      id: id,
      billNumber: id,
      customerId: customerId,
      customerName: customerName,
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
    );
  }

  BillItem item({
    required String productId,
    required String productName,
    required int quantity,
    required double sellingPrice,
    required double purchasePrice,
    String? category,
    double discount = 0,
  }) {
    return BillItem(
      productId: productId,
      productName: productName,
      sku: productId,
      category: category,
      quantity: quantity,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      discount: discount,
    );
  }

  Product product({
    required String id,
    required int stockQuantity,
    required int reorderLevel,
  }) {
    return Product(
      id: id,
      name: id,
      sku: id,
      category: 'General',
      supplierId: 'supplier',
      purchasePrice: 100,
      sellingPrice: 200,
      stockQuantity: stockQuantity,
      reorderLevel: reorderLevel,
      createdAt: baseDate,
      updatedAt: baseDate,
    );
  }

  test('empty data produces no insights or alerts', () {
    final result = InsightsSummary.fromData(
      bills: const [],
      products: const [],
    );

    expect(result.insights, isEmpty);
    expect(result.alerts, isEmpty);
  });

  test('finds the top-selling product from historical bill items', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'bill-1',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 3,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
            item(
              productId: 'keyboard',
              productName: 'Keyboard',
              quantity: 1,
              sellingPrice: 800,
              purchasePrice: 400,
            ),
          ],
        ),
      ],
      products: const [],
    );

    final insight = result.insights
        .firstWhere((insight) => insight.type == InsightType.topProduct);
    expect(insight.relatedEntityName, 'Mouse');
    expect(insight.value, 3);
  });

  test('finds the highest-revenue historical category', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'bill-1',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              category: 'Accessories',
              quantity: 2,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
            item(
              productId: 'keyboard',
              productName: 'Keyboard',
              category: 'Keyboards',
              quantity: 1,
              sellingPrice: 800,
              purchasePrice: 400,
            ),
          ],
        ),
      ],
      products: const [],
    );

    final insight = result.insights
        .firstWhere((insight) => insight.type == InsightType.topCategory);
    expect(insight.relatedEntityName, 'Accessories');
    expect(insight.value, 1000);
  });

  test('creates low-stock and out-of-stock alerts correctly', () {
    final result = InsightsSummary.fromData(
      bills: const [],
      products: [
        product(id: 'empty', stockQuantity: 0, reorderLevel: 5),
        product(id: 'low', stockQuantity: 2, reorderLevel: 5),
        product(id: 'healthy', stockQuantity: 8, reorderLevel: 5),
      ],
    );

    expect(
      result.alerts.map((alert) => alert.type),
      [AlertType.outOfStock, AlertType.lowStock],
    );
    expect(result.alerts.first.severity, AlertSeverity.critical);
  });

  test('creates a low-profit-margin alert using the named threshold', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'low-margin',
          createdAt: baseDate,
          items: [
            item(
              productId: 'low-margin-product',
              productName: 'Low Margin Product',
              quantity: 1,
              sellingPrice: 100,
              purchasePrice: 95,
            ),
          ],
        ),
      ],
      products: const [],
    );

    final alert = result.alerts
        .firstWhere((alert) => alert.type == AlertType.lowProfitMargin);
    expect(alert.relatedEntityName, 'Low Margin Product');
    expect(alert.value, closeTo(5, 0.001));
  });

  test('does not compare revenue without a previous period', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'today',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
      ],
      products: const [],
      dateFilter: const AnalyticsDateFilter.today(),
      now: baseDate,
    );

    expect(result.insights.where((item) => item.type == InsightType.revenue),
        isEmpty);
  });

  test('compares revenue against the preceding calendar period', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'previous',
          createdAt: DateTime(2026, 9, 21, 10),
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
        bill(
          id: 'current',
          createdAt: DateTime(2026, 9, 22, 10),
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 2,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
      ],
      products: const [],
      dateFilter: const AnalyticsDateFilter.today(),
      now: baseDate,
    );

    final insight = result.insights
        .firstWhere((insight) => insight.type == InsightType.revenue);
    expect(insight.title, 'Revenue increased');
    expect(insight.value, 1000);
    expect(insight.comparisonValue, 500);
  });

  test('named customer insight excludes walk-in-only activity', () {
    final walkInOnly = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'walk-in',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
      ],
      products: const [],
    );
    expect(
        walkInOnly.insights.where((item) => item.type == InsightType.customer),
        isEmpty);

    final named = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'named',
          createdAt: baseDate,
          customerId: 'alice',
          customerName: 'Alice',
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
      ],
      products: const [],
    );
    expect(named.insights.where((item) => item.type == InsightType.customer),
        hasLength(1));
  });

  test('creates a milestone only from actual bill data', () {
    final result = InsightsSummary.fromData(
      bills: [
        for (var index = 0; index < salesMilestoneBillThreshold; index++)
          bill(
            id: 'bill-$index',
            createdAt: baseDate,
            items: [
              item(
                productId: 'mouse',
                productName: 'Mouse',
                quantity: 1,
                sellingPrice: 500,
                purchasePrice: 300,
              ),
            ],
          ),
      ],
      products: const [],
    );

    expect(
      result.insights.where((item) => item.type == InsightType.salesMilestone),
      hasLength(1),
    );
  });

  test('legacy uncategorized items do not create a category insight', () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'legacy',
          createdAt: baseDate,
          items: [
            item(
              productId: 'legacy',
              productName: 'Legacy Product',
              quantity: 1,
              sellingPrice: 500,
              purchasePrice: 300,
            ),
          ],
        ),
      ],
      products: const [],
    );

    expect(
        result.insights.where((item) => item.type == InsightType.topCategory),
        isEmpty);
  });

  test('historical prices drive profit insights rather than current prices',
      () {
    final result = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'historical',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 900,
              purchasePrice: 500,
            ),
          ],
        ),
      ],
      products: [product(id: 'mouse', stockQuantity: 10, reorderLevel: 2)],
    );

    final margin = InsightsSummary.fromData(
      bills: [
        bill(
          id: 'historical',
          createdAt: baseDate,
          items: [
            item(
              productId: 'mouse',
              productName: 'Mouse',
              quantity: 1,
              sellingPrice: 900,
              purchasePrice: 500,
            ),
          ],
        ),
      ],
      products: const [],
    ).insights.firstWhere((item) => item.type == InsightType.profitMargin);

    expect(margin.value, closeTo(44.4444, 0.001));
    expect(
        result.alerts.where((alert) => alert.type == AlertType.lowProfitMargin),
        isEmpty);
  });
}
