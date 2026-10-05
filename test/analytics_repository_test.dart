import 'package:flutter_test/flutter_test.dart';
import 'package:retail_iq/models/analytics_date_filter.dart';
import 'package:retail_iq/models/analytics_summary.dart';
import 'package:retail_iq/models/bill.dart';
import 'package:retail_iq/repositories/analytics_repository.dart';

void main() {
  final firstDate = DateTime(2026, 9, 20, 23, 45);

  Bill makeBill({
    required String id,
    required DateTime createdAt,
    required String paymentMethod,
    required List<BillItem> items,
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
    required String name,
    required String sku,
    String? category,
    required int quantity,
    required double sellingPrice,
    required double purchasePrice,
    double discount = 0,
  }) {
    return BillItem(
      productId: productId,
      productName: name,
      sku: sku,
      category: category,
      quantity: quantity,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      discount: discount,
    );
  }

  test('calculates one bill revenue, items, and historical profit', () {
    final bill = makeBill(
      id: 'bill-1',
      createdAt: firstDate,
      paymentMethod: 'Cash',
      items: [
        item(
          productId: 'mouse',
          name: 'Mouse',
          sku: 'M-001',
          quantity: 2,
          sellingPrice: 500,
          purchasePrice: 300,
          discount: 50,
        ),
      ],
      discount: 100,
    );

    final summary = AnalyticsSummary.fromBills([bill]);

    expect(summary.sales.totalRevenue, 850);
    expect(summary.sales.totalBills, 1);
    expect(summary.sales.totalItemsSold, 2);
    expect(summary.sales.averageOrderValue, 850);
    expect(summary.profit.totalCost, 600);
    expect(summary.profit.totalProfit, 250);
  });

  test('serializes category and reads old items without category', () {
    final categorized = item(
      productId: 'mouse',
      name: 'Mouse',
      sku: 'M-001',
      category: 'Accessories',
      quantity: 1,
      sellingPrice: 849,
      purchasePrice: 500,
    );

    expect(categorized.toMap()['category'], 'Accessories');
    expect(BillItem.fromMap(categorized.toMap()).category, 'Accessories');
    expect(
      BillItem.fromMap({
        'productId': 'old',
        'productName': 'Old product',
        'sku': 'OLD-001',
        'quantity': 1,
        'sellingPrice': 100,
        'purchasePrice': 60,
        'discount': 0,
      }).category,
      isNull,
    );
  });

  test('preserves selected category through quantity and discount edits', () {
    final selected = item(
      productId: 'mouse',
      name: 'Mouse',
      sku: 'M-001',
      category: 'Accessories',
      quantity: 1,
      sellingPrice: 849,
      purchasePrice: 500,
    );

    final edited = selected.copyWith(quantity: 3, discount: 25);

    expect(edited.category, 'Accessories');
  });

  test('aggregates multiple bills and sales by date', () {
    final bills = [
      makeBill(
        id: 'bill-1',
        createdAt: DateTime(2026, 9, 20, 8),
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 1000,
            purchasePrice: 600,
          ),
        ],
      ),
      makeBill(
        id: 'bill-2',
        createdAt: DateTime(2026, 9, 20, 18),
        paymentMethod: 'UPI',
        items: [
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            quantity: 2,
            sellingPrice: 250,
            purchasePrice: 150,
          ),
        ],
      ),
    ];

    final summary = AnalyticsSummary.fromBills(bills);

    expect(summary.sales.totalRevenue, 1500);
    expect(summary.sales.totalBills, 2);
    expect(summary.sales.totalItemsSold, 3);
    expect(summary.sales.averageOrderValue, 750);
    expect(summary.salesByDate, hasLength(1));
    expect(summary.salesByDate.single.revenue, 1500);
    expect(summary.salesByDate.single.billCount, 2);
    expect(summary.salesByDate.single.itemsSold, 3);
  });

  test('aggregates multiple products using historical item snapshots', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstDate,
        paymentMethod: 'Card',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse snapshot',
            sku: 'M-001',
            category: 'Accessories',
            quantity: 2,
            sellingPrice: 500,
            purchasePrice: 300,
            discount: 20,
          ),
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            category: 'Keyboards',
            quantity: 1,
            sellingPrice: 800,
            purchasePrice: 400,
          ),
        ],
      ),
      makeBill(
        id: 'bill-2',
        createdAt: firstDate,
        paymentMethod: 'Card',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse snapshot',
            sku: 'M-001',
            category: 'Accessories',
            quantity: 1,
            sellingPrice: 450,
            purchasePrice: 275,
          ),
        ],
      ),
    ]);

    final mouse = summary.productPerformance
        .firstWhere((product) => product.productId == 'mouse');
    final keyboard = summary.productPerformance
        .firstWhere((product) => product.productId == 'keyboard');

    expect(mouse.quantitySold, 3);
    expect(mouse.revenue, 1430);
    expect(mouse.totalCost, 875);
    expect(mouse.profit, 555);
    expect(mouse.profitMargin, closeTo(38.8112, 0.0001));
    expect(keyboard.quantitySold, 1);
    expect(keyboard.revenue, 800);
    expect(keyboard.totalCost, 400);
    expect(keyboard.profit, 400);
    expect(keyboard.profitMargin, 50);
    expect(summary.categoryPerformance.map((category) => category.category), [
      'Accessories',
      'Keyboards',
    ]);
  });

  test('aggregates category totals independently and orders by revenue', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            category: 'Accessories',
            quantity: 4,
            sellingPrice: 799,
            purchasePrice: 500,
          ),
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            category: 'Keyboards',
            quantity: 2,
            sellingPrice: 600,
            purchasePrice: 350,
          ),
        ],
      ),
    ]);

    final accessories = summary.categoryPerformance
        .firstWhere((category) => category.category == 'Accessories');
    final keyboards = summary.categoryPerformance
        .firstWhere((category) => category.category == 'Keyboards');

    expect(accessories.quantitySold, 4);
    expect(accessories.revenue, 3196);
    expect(accessories.totalCost, 2000);
    expect(accessories.profit, 1196);
    expect(accessories.profitMargin, closeTo(37.4218, 0.0001));
    expect(keyboards.quantitySold, 2);
    expect(keyboards.revenue, 1200);
    expect(keyboards.totalCost, 700);
    expect(keyboards.profit, 500);
    expect(keyboards.profitMargin, closeTo(41.6667, 0.0001));
    expect(summary.categoryPerformance.first.category, 'Accessories');
  });

  test('excludes legacy categories without excluding other analytics', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'old-bill',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'old-mouse',
            name: 'Old mouse',
            sku: 'OLD-001',
            quantity: 2,
            sellingPrice: 500,
            purchasePrice: 300,
          ),
        ],
      ),
    ]);

    expect(summary.categoryPerformance, isEmpty);
    expect(summary.sales.totalRevenue, 1000);
    expect(summary.productPerformance.single.quantitySold, 2);
    expect(summary.productPerformance.single.totalCost, 600);
    expect(summary.profit.totalProfit, 400);
  });

  test('keeps historical category when a current product category changes', () {
    final historicalItem = item(
      productId: 'mouse',
      name: 'Mouse',
      sku: 'M-001',
      category: 'Accessories',
      quantity: 1,
      sellingPrice: 849,
      purchasePrice: 500,
    );

    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [historicalItem],
      ),
    ]);

    expect(summary.categoryPerformance.single.category, 'Accessories');
  });

  test('category discount allocation matches bill revenue and profit', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'discounted-bill',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        discount: 100,
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            category: 'Accessories',
            quantity: 2,
            sellingPrice: 500,
            purchasePrice: 300,
            discount: 50,
          ),
        ],
      ),
    ]);

    final category = summary.categoryPerformance.single;
    expect(category.revenue, summary.sales.totalRevenue);
    expect(category.profit, summary.profit.totalProfit);
  });

  test('aggregates only payment methods present in saved bills', () {
    final methods = ['Cash', 'UPI', 'Card', 'Other'];
    final summary = AnalyticsSummary.fromBills([
      for (var index = 0; index < methods.length; index++)
        makeBill(
          id: 'bill-$index',
          createdAt: firstDate,
          paymentMethod: methods[index],
          items: [
            item(
              productId: 'product-$index',
              name: 'Product $index',
              sku: 'SKU-$index',
              quantity: 1,
              sellingPrice: 100 + index * 50,
              purchasePrice: 50,
            ),
          ],
        ),
    ]);

    expect(
        summary.paymentMethods.map((method) => method.paymentMethod), methods);
    expect(
        summary.paymentMethods.map((method) => method.billCount), [1, 1, 1, 1]);
    expect(summary.paymentMethods.map((method) => method.revenue),
        [100, 150, 200, 250]);
  });

  test('returns zero-safe summaries for no bills', () {
    final summary = AnalyticsSummary.fromBills(const []);

    expect(summary.sales.totalRevenue, 0);
    expect(summary.sales.totalBills, 0);
    expect(summary.sales.totalItemsSold, 0);
    expect(summary.sales.averageOrderValue, 0);
    expect(summary.profit.totalProfit, 0);
    expect(summary.profit.profitMargin, 0);
    expect(summary.salesByDate, isEmpty);
    expect(summary.productPerformance, isEmpty);
    expect(summary.paymentMethods, isEmpty);
  });

  test('uses historical pricing instead of current product pricing', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse at sale',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 900,
            purchasePrice: 500,
          ),
        ],
      ),
    ]);

    // A later product price of 1,200 / 700 must not alter this saved sale.
    final mouse = summary.productPerformance.single;
    expect(mouse.revenue, 900);
    expect(mouse.totalCost, 500);
    expect(mouse.profit, 400);
  });

  test('aggregates one named customer and uses the bill total', () {
    final purchaseDate = DateTime(2026, 9, 18, 10);
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-alice',
        createdAt: purchaseDate,
        paymentMethod: 'UPI',
        customerId: 'customer-alice',
        customerName: 'Alice',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 2,
            sellingPrice: 849,
            purchasePrice: 500,
          ),
        ],
      ),
    ]);

    expect(summary.identifiableCustomerCount, 1);
    expect(summary.identifiableCustomerRevenue, 1698);
    final customer = summary.customers.single;
    expect(customer.customerId, 'customer-alice');
    expect(customer.customerName, 'Alice');
    expect(customer.billCount, 1);
    expect(customer.itemsPurchased, 2);
    expect(customer.totalSpent, 1698);
    expect(customer.averageOrderValue, 1698);
    expect(customer.lastPurchaseDate, purchaseDate);
    expect(customer.isRepeatCustomer, isFalse);
  });

  test('groups repeat bills and calculates repeat customer metrics', () {
    final firstPurchase = DateTime(2026, 9, 10);
    final latestPurchase = DateTime(2026, 9, 22);
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstPurchase,
        paymentMethod: 'Cash',
        customerId: 'customer-alice',
        customerName: 'Alice',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 500,
            purchasePrice: 300,
          ),
        ],
      ),
      makeBill(
        id: 'bill-2',
        createdAt: latestPurchase,
        paymentMethod: 'Cash',
        customerId: 'customer-alice',
        customerName: 'Alice',
        items: [
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            quantity: 2,
            sellingPrice: 600,
            purchasePrice: 350,
          ),
        ],
      ),
    ]);

    final customer = summary.customers.single;
    expect(summary.identifiableCustomerCount, 1);
    expect(summary.repeatCustomerCount, 1);
    expect(customer.billCount, 2);
    expect(customer.itemsPurchased, 3);
    expect(customer.totalSpent, 1700);
    expect(customer.averageOrderValue, 850);
    expect(customer.firstPurchaseDate, firstPurchase);
    expect(customer.lastPurchaseDate, latestPurchase);
    expect(customer.isRepeatCustomer, isTrue);
  });

  test('keeps two named customers separate and sorts by total spent', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-alice',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        customerId: 'alice-id',
        customerName: 'Alice',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 500,
            purchasePrice: 300,
          ),
        ],
      ),
      makeBill(
        id: 'bill-bob',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        customerId: 'bob-id',
        customerName: 'Bob',
        items: [
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            quantity: 2,
            sellingPrice: 600,
            purchasePrice: 350,
          ),
        ],
      ),
    ]);

    expect(summary.customers.map((customer) => customer.customerName),
        ['Bob', 'Alice']);
    expect(summary.customers.map((customer) => customer.customerId),
        ['bob-id', 'alice-id']);
  });

  test('keeps walk-in sales separate from named customers', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'walk-in-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 1000,
            purchasePrice: 600,
          ),
        ],
      ),
      makeBill(
        id: 'named-1',
        createdAt: firstDate,
        paymentMethod: 'UPI',
        customerId: 'alice-id',
        customerName: 'Alice',
        items: [
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            quantity: 1,
            sellingPrice: 600,
            purchasePrice: 350,
          ),
        ],
      ),
    ]);

    expect(summary.identifiableCustomerCount, 1);
    expect(summary.identifiableCustomerRevenue, 600);
    expect(summary.walkIn?.billCount, 1);
    expect(summary.walkIn?.totalSpent, 1000);
    expect(summary.customers.single.customerName, 'Alice');
  });

  test('uses customer name only for bills without a reliable ID', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'legacy-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        customerName: 'Legacy Customer',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 500,
            purchasePrice: 300,
          ),
        ],
      ),
    ]);

    expect(summary.customers.single.customerId, isNull);
    expect(summary.customers.single.customerName, 'Legacy Customer');
  });

  test('empty bills produce zero-safe customer analytics', () {
    final summary = AnalyticsSummary.fromBills(const []);

    expect(summary.identifiableCustomerCount, 0);
    expect(summary.identifiableCustomerRevenue, 0);
    expect(summary.averageCustomerSpend, 0);
    expect(summary.repeatCustomerCount, 0);
    expect(summary.customers, isEmpty);
    expect(summary.walkIn, isNull);
  });

  test('all time returns every bill', () {
    final bills = [
      makeBill(
        id: 'old',
        createdAt: DateTime(2026, 8, 31),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'current',
        createdAt: DateTime(2026, 9, 22),
        paymentMethod: 'Cash',
        items: const [],
      ),
    ];

    expect(
      AnalyticsRepository.filterBills(
        bills,
        const AnalyticsDateFilter.allTime(),
        now: DateTime(2026, 9, 22),
      ),
      hasLength(2),
    );
  });

  test('today and yesterday use local calendar boundaries', () {
    final now = DateTime(2026, 9, 22, 12);
    final bills = [
      makeBill(
        id: 'today-start',
        createdAt: DateTime(2026, 9, 22),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'today-late',
        createdAt: DateTime(2026, 9, 22, 23, 59, 59, 999),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'tomorrow-start',
        createdAt: DateTime(2026, 9, 23),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'yesterday-late',
        createdAt: DateTime(2026, 9, 21, 23, 59),
        paymentMethod: 'Cash',
        items: const [],
      ),
    ];

    final today = AnalyticsRepository.filterBills(
      bills,
      const AnalyticsDateFilter.today(),
      now: now,
    );
    final yesterday = AnalyticsRepository.filterBills(
      bills,
      const AnalyticsDateFilter.yesterday(),
      now: now,
    );

    expect(today.map((bill) => bill.id), ['today-start', 'today-late']);
    expect(yesterday.map((bill) => bill.id), ['yesterday-late']);
  });

  test('this week uses Monday through Sunday', () {
    final now = DateTime(2026, 9, 23, 12);
    final bills = [
      for (final entry in <String, DateTime>{
        'monday': DateTime(2026, 9, 21),
        'sunday': DateTime(2026, 9, 27),
        'previous-sunday': DateTime(2026, 9, 20),
        'next-monday': DateTime(2026, 9, 28),
      }.entries)
        makeBill(
          id: entry.key,
          createdAt: entry.value,
          paymentMethod: 'Cash',
          items: const [],
        ),
    ];

    final filtered = AnalyticsRepository.filterBills(
      bills,
      const AnalyticsDateFilter.thisWeek(),
      now: now,
    );

    expect(filtered.map((bill) => bill.id), ['monday', 'sunday']);
  });

  test('this month uses the current calendar month', () {
    final now = DateTime(2026, 9, 15);
    final bills = [
      makeBill(
        id: 'month-start',
        createdAt: DateTime(2026, 9, 1),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'month-end',
        createdAt: DateTime(2026, 9, 30, 23, 59),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'next-month',
        createdAt: DateTime(2026, 10, 1),
        paymentMethod: 'Cash',
        items: const [],
      ),
    ];

    final filtered = AnalyticsRepository.filterBills(
      bills,
      const AnalyticsDateFilter.thisMonth(),
      now: now,
    );

    expect(filtered.map((bill) => bill.id), ['month-start', 'month-end']);
  });

  test('custom range includes both selected calendar dates', () {
    final range = AnalyticsDateFilter.custom(
      startDate: DateTime(2026, 9, 10, 18),
      endDate: DateTime(2026, 9, 20, 4),
    );
    final bills = [
      makeBill(
        id: 'start-day',
        createdAt: DateTime(2026, 9, 10, 0, 1),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'end-day',
        createdAt: DateTime(2026, 9, 20, 23, 59),
        paymentMethod: 'Cash',
        items: const [],
      ),
      makeBill(
        id: 'outside',
        createdAt: DateTime(2026, 9, 21),
        paymentMethod: 'Cash',
        items: const [],
      ),
    ];

    final filtered = AnalyticsRepository.filterBills(bills, range);

    expect(filtered.map((bill) => bill.id), ['start-day', 'end-day']);
  });

  test('invalid custom range is rejected', () {
    expect(
      () => AnalyticsDateFilter.custom(
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 9, 20),
      ),
      throwsArgumentError,
    );
  });

  test('filtered bills drive trend, profit, customer, and walk-in analytics',
      () {
    final now = DateTime(2026, 9, 22);
    final bills = [
      makeBill(
        id: 'inside-named',
        createdAt: DateTime(2026, 9, 22, 10),
        paymentMethod: 'UPI',
        customerId: 'alice-id',
        customerName: 'Alice',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 1,
            sellingPrice: 900,
            purchasePrice: 500,
          ),
        ],
      ),
      makeBill(
        id: 'inside-walk-in',
        createdAt: DateTime(2026, 9, 22, 11),
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'keyboard',
            name: 'Keyboard',
            sku: 'K-001',
            quantity: 1,
            sellingPrice: 600,
            purchasePrice: 300,
          ),
        ],
      ),
      makeBill(
        id: 'outside',
        createdAt: DateTime(2026, 9, 21),
        paymentMethod: 'Card',
        customerId: 'bob-id',
        customerName: 'Bob',
        items: [
          item(
            productId: 'other',
            name: 'Other',
            sku: 'O-001',
            quantity: 5,
            sellingPrice: 1000,
            purchasePrice: 100,
          ),
        ],
      ),
    ];

    final filteredBills = AnalyticsRepository.filterBills(
      bills,
      const AnalyticsDateFilter.today(),
      now: now,
    );
    final summary = AnalyticsSummary.fromBills(filteredBills);

    expect(summary.sales.totalRevenue, 1500);
    expect(summary.profit.totalProfit, 700);
    expect(summary.productPerformance.map((product) => product.productId),
        ['mouse', 'keyboard']);
    expect(summary.paymentMethods.map((method) => method.paymentMethod),
        ['UPI', 'Cash']);
    expect(summary.customers.single.customerName, 'Alice');
    expect(summary.walkIn?.totalSpent, 600);
    expect(summary.salesByDate, hasLength(1));
    expect(summary.salesByDate.single.date, DateTime(2026, 9, 22));
  });

  test('calculates product revenue, cost, profit, and margin', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'bill-1',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            quantity: 2,
            sellingPrice: 849,
            purchasePrice: 500,
          ),
        ],
      ),
    ]);

    final product = summary.productPerformance.single;
    expect(product.revenue, 1698);
    expect(product.totalCost, 1000);
    expect(product.profit, 698);
    expect(product.profitMargin, closeTo(41.1072, 0.0001));
    expect(summary.profit.revenue, 1698);
    expect(summary.profit.totalCost, 1000);
    expect(summary.profit.totalProfit, 698);
  });

  test('bill discount allocation does not double-count discounts', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'discounted-bill',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        discount: 100,
        items: [
          item(
            productId: 'mouse',
            name: 'Mouse',
            sku: 'M-001',
            category: 'Accessories',
            quantity: 2,
            sellingPrice: 849,
            purchasePrice: 500,
            discount: 50,
          ),
        ],
      ),
    ]);

    final product = summary.productPerformance.single;
    expect(summary.sales.totalRevenue, 1548);
    expect(product.revenue, summary.sales.totalRevenue);
    expect(product.totalCost, 1000);
    expect(product.profit, 548);
    expect(summary.profit.totalProfit, product.profit);
  });

  test('zero revenue produces a zero margin without infinity or NaN', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'zero-bill',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'free',
            name: 'Free item',
            sku: 'FREE-001',
            quantity: 0,
            sellingPrice: 0,
            purchasePrice: 0,
          ),
        ],
      ),
    ]);

    expect(summary.profit.totalProfit, 0);
    expect(summary.profit.profitMargin, 0);
    expect(summary.productPerformance.single.profitMargin, 0);
  });

  test('negative historical profit is preserved', () {
    final summary = AnalyticsSummary.fromBills([
      makeBill(
        id: 'loss-bill',
        createdAt: firstDate,
        paymentMethod: 'Cash',
        items: [
          item(
            productId: 'loss-product',
            name: 'Loss product',
            sku: 'LOSS-001',
            quantity: 1,
            sellingPrice: 100,
            purchasePrice: 200,
          ),
        ],
      ),
    ]);

    final product = summary.productPerformance.single;
    expect(product.profit, -100);
    expect(product.profitMargin, -100);
    expect(summary.profit.totalProfit, -100);
  });
}
