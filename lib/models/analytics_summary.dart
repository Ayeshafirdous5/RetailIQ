import 'dart:math' as math;

import 'bill.dart';

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.sales,
    required this.salesByDate,
    required this.productPerformance,
    required this.categoryPerformance,
    required this.profit,
    required this.paymentMethods,
    required this.customers,
    required this.walkIn,
  });

  const AnalyticsSummary.empty()
      : sales = const SalesSummary.zero(),
        salesByDate = const [],
        productPerformance = const [],
        categoryPerformance = const [],
        profit = const ProfitSummary.zero(),
        paymentMethods = const [],
        customers = const [],
        walkIn = null;

  final SalesSummary sales;
  final List<SalesByDateSummary> salesByDate;
  final List<ProductPerformanceSummary> productPerformance;
  final List<CategoryPerformanceSummary> categoryPerformance;
  final ProfitSummary profit;
  final List<PaymentMethodSummary> paymentMethods;
  final List<CustomerPerformanceSummary> customers;
  final WalkInSummary? walkIn;

  int get identifiableCustomerCount => customers.length;

  double get identifiableCustomerRevenue =>
      customers.fold(0, (total, customer) => total + customer.totalSpent);

  double get averageCustomerSpend =>
      customers.isEmpty ? 0 : identifiableCustomerRevenue / customers.length;

  int get repeatCustomerCount =>
      customers.where((customer) => customer.isRepeatCustomer).length;

  factory AnalyticsSummary.fromBills(Iterable<Bill> bills) {
    final billList = bills.toList(growable: false);
    if (billList.isEmpty) return const AnalyticsSummary.empty();

    var totalRevenue = 0.0;
    var totalItemsSold = 0;
    var totalCost = 0.0;
    final salesByDate = <String, _SalesByDateAccumulator>{};
    final products = <String, _ProductAccumulator>{};
    final categories = <String, _CategoryAccumulator>{};
    final paymentMethods = <String, _PaymentMethodAccumulator>{};
    final customers = <String, _CustomerAccumulator>{};
    _WalkInAccumulator? walkIn;

    for (final bill in billList) {
      final billRevenue = bill.total;
      totalRevenue += billRevenue;

      final customerKey = _customerKey(bill);
      if (customerKey == null) {
        walkIn ??= _WalkInAccumulator();
        walkIn.billCount++;
        walkIn.totalSpent += billRevenue;
        walkIn.itemsPurchased += _itemsInBill(bill);
      } else {
        final customer = customers.putIfAbsent(
          customerKey,
          () => _CustomerAccumulator(
            customerId: _validCustomerId(bill.customerId),
            customerName: _customerDisplayName(bill),
          ),
        );
        customer.billCount++;
        customer.itemsPurchased += _itemsInBill(bill);
        customer.totalSpent += billRevenue;
        customer.firstPurchaseDate = customer.firstPurchaseDate == null ||
                bill.createdAt.isBefore(customer.firstPurchaseDate!)
            ? bill.createdAt
            : customer.firstPurchaseDate;
        customer.lastPurchaseDate = customer.lastPurchaseDate == null ||
                bill.createdAt.isAfter(customer.lastPurchaseDate!)
            ? bill.createdAt
            : customer.lastPurchaseDate;
      }

      final itemSubtotal = bill.items.fold<double>(
        0,
        (total, item) => total + item.lineTotal,
      );
      final effectiveBillDiscount = math
          .min(
            math.max(0, bill.discount),
            itemSubtotal,
          )
          .toDouble();
      var billCost = 0.0;

      for (final item in bill.items) {
        final quantity = math.max(0, item.quantity);
        final itemCost = math.max(0, item.purchasePrice) * quantity;
        billCost += itemCost;
        totalItemsSold += quantity;

        final itemRevenue = _revenueAfterBillDiscount(
          item,
          itemSubtotal,
          effectiveBillDiscount,
        );
        final product = products.putIfAbsent(
          item.productId,
          () => _ProductAccumulator(
            productId: item.productId,
            productName: item.productName,
            sku: item.sku,
          ),
        );
        product.quantitySold += quantity;
        product.revenue += itemRevenue;
        product.totalCost += itemCost;
        product.profit += itemRevenue - itemCost;

        final category = item.category?.trim();
        if (category != null && category.isNotEmpty) {
          final categorySummary = categories.putIfAbsent(
            category,
            () => _CategoryAccumulator(category),
          );
          categorySummary.quantitySold += quantity;
          categorySummary.revenue += itemRevenue;
          categorySummary.totalCost += itemCost;
          categorySummary.profit += itemRevenue - itemCost;
        }
      }

      totalCost += billCost;
      final date = _dateOnly(bill.createdAt);
      final dateKey = _dateKey(date);
      final dateSummary = salesByDate.putIfAbsent(
        dateKey,
        () => _SalesByDateAccumulator(date),
      );
      dateSummary.revenue += billRevenue;
      dateSummary.billCount++;
      dateSummary.itemsSold += bill.items.fold<int>(
        0,
        (total, item) => total + math.max(0, item.quantity),
      );

      final payment = paymentMethods.putIfAbsent(
        bill.paymentMethod,
        () => _PaymentMethodAccumulator(bill.paymentMethod),
      );
      payment.billCount++;
      payment.revenue += billRevenue;
    }

    final totalProfit = totalRevenue - totalCost;
    return AnalyticsSummary(
      sales: SalesSummary(
        totalRevenue: totalRevenue,
        totalBills: billList.length,
        totalItemsSold: totalItemsSold,
        averageOrderValue: totalRevenue / billList.length,
      ),
      salesByDate: salesByDate.values
          .map((summary) => summary.toModel())
          .toList(growable: false)
        ..sort((first, second) => first.date.compareTo(second.date)),
      productPerformance: products.values
          .map((product) => product.toModel())
          .toList(growable: false),
      categoryPerformance: categories.values
          .map((category) => category.toModel())
          .toList(growable: false)
        ..sort((first, second) => second.profit.compareTo(first.profit)),
      profit: ProfitSummary(
        totalRevenue: totalRevenue,
        totalCost: totalCost,
        totalProfit: totalProfit,
        profitMargin:
            totalRevenue == 0 ? 0 : (totalProfit / totalRevenue) * 100,
      ),
      paymentMethods: paymentMethods.values
          .map((payment) => payment.toModel())
          .toList(growable: false),
      customers: customers.values
          .map((customer) => customer.toModel())
          .toList(growable: false)
        ..sort(
            (first, second) => second.totalSpent.compareTo(first.totalSpent)),
      walkIn: walkIn?.toModel(),
    );
  }

  static String? _customerKey(Bill bill) {
    final customerId = _validCustomerId(bill.customerId);
    if (customerId != null) return 'id:$customerId';
    final name = bill.customerName.trim();
    if (_isWalkInName(name) || name.isEmpty) return null;
    return 'name:${name.toLowerCase()}';
  }

  static String? _validCustomerId(String? customerId) {
    final value = customerId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _customerDisplayName(Bill bill) {
    final name = bill.customerName.trim();
    return name.isEmpty ? 'Unnamed customer' : name;
  }

  static bool _isWalkInName(String name) =>
      name.toLowerCase() == 'walk-in customer';

  static int _itemsInBill(Bill bill) => bill.items.fold<int>(
        0,
        (total, item) => total + math.max(0, item.quantity),
      );

  static double _revenueAfterBillDiscount(
    BillItem item,
    double itemSubtotal,
    double billDiscount,
  ) {
    if (itemSubtotal == 0) return 0;
    final allocatedDiscount = billDiscount * item.lineTotal / itemSubtotal;
    return math.max(0, item.lineTotal - allocatedDiscount);
  }

  static DateTime _dateOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

class SalesSummary {
  const SalesSummary({
    required this.totalRevenue,
    required this.totalBills,
    required this.totalItemsSold,
    required this.averageOrderValue,
  });

  const SalesSummary.zero()
      : totalRevenue = 0,
        totalBills = 0,
        totalItemsSold = 0,
        averageOrderValue = 0;

  final double totalRevenue;
  final int totalBills;
  final int totalItemsSold;
  final double averageOrderValue;
}

class SalesByDateSummary {
  const SalesByDateSummary({
    required this.date,
    required this.revenue,
    required this.billCount,
    required this.itemsSold,
  });

  final DateTime date;
  final double revenue;
  final int billCount;
  final int itemsSold;
}

class ProductPerformanceSummary {
  const ProductPerformanceSummary({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantitySold,
    required this.revenue,
    required this.totalCost,
    required this.profit,
    required this.profitMargin,
  });

  final String productId;
  final String productName;
  final String sku;
  final int quantitySold;
  final double revenue;
  final double totalCost;
  final double profit;
  final double profitMargin;
}

class CategoryPerformanceSummary {
  const CategoryPerformanceSummary({
    required this.category,
    required this.quantitySold,
    required this.revenue,
    required this.totalCost,
    required this.profit,
    required this.profitMargin,
  });

  final String category;
  final int quantitySold;
  final double revenue;
  final double totalCost;
  final double profit;
  final double profitMargin;
}

class ProfitSummary {
  const ProfitSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
  });

  const ProfitSummary.zero()
      : totalRevenue = 0,
        totalCost = 0,
        totalProfit = 0,
        profitMargin = 0;

  final double totalRevenue;
  final double totalCost;
  final double totalProfit;

  /// Percentage from 0 to 100, or zero when there is no revenue.
  final double profitMargin;

  double get revenue => totalRevenue;
}

class PaymentMethodSummary {
  const PaymentMethodSummary({
    required this.paymentMethod,
    required this.billCount,
    required this.revenue,
  });

  final String paymentMethod;
  final int billCount;
  final double revenue;
}

class CustomerPerformanceSummary {
  const CustomerPerformanceSummary({
    required this.customerId,
    required this.customerName,
    required this.billCount,
    required this.itemsPurchased,
    required this.totalSpent,
    required this.averageOrderValue,
    required this.lastPurchaseDate,
    required this.firstPurchaseDate,
  });

  final String? customerId;
  final String customerName;
  final int billCount;
  final int itemsPurchased;
  final double totalSpent;
  final double averageOrderValue;
  final DateTime lastPurchaseDate;
  final DateTime firstPurchaseDate;

  bool get isRepeatCustomer => billCount > 1;
}

class WalkInSummary {
  const WalkInSummary({
    required this.billCount,
    required this.itemsPurchased,
    required this.totalSpent,
  });

  final int billCount;
  final int itemsPurchased;
  final double totalSpent;
}

class _SalesByDateAccumulator {
  _SalesByDateAccumulator(this.date);

  final DateTime date;
  double revenue = 0;
  int billCount = 0;
  int itemsSold = 0;

  SalesByDateSummary toModel() => SalesByDateSummary(
        date: date,
        revenue: revenue,
        billCount: billCount,
        itemsSold: itemsSold,
      );
}

class _ProductAccumulator {
  _ProductAccumulator({
    required this.productId,
    required this.productName,
    required this.sku,
  });

  final String productId;
  final String productName;
  final String sku;
  int quantitySold = 0;
  double revenue = 0;
  double totalCost = 0;
  double profit = 0;

  ProductPerformanceSummary toModel() => ProductPerformanceSummary(
        productId: productId,
        productName: productName,
        sku: sku,
        quantitySold: quantitySold,
        revenue: revenue,
        totalCost: totalCost,
        profit: profit,
        profitMargin: _profitMargin(revenue, profit),
      );
}

class _PaymentMethodAccumulator {
  _PaymentMethodAccumulator(this.paymentMethod);

  final String paymentMethod;
  int billCount = 0;
  double revenue = 0;

  PaymentMethodSummary toModel() => PaymentMethodSummary(
        paymentMethod: paymentMethod,
        billCount: billCount,
        revenue: revenue,
      );
}

class _CategoryAccumulator {
  _CategoryAccumulator(this.category);

  final String category;
  int quantitySold = 0;
  double revenue = 0;
  double totalCost = 0;
  double profit = 0;

  CategoryPerformanceSummary toModel() => CategoryPerformanceSummary(
        category: category,
        quantitySold: quantitySold,
        revenue: revenue,
        totalCost: totalCost,
        profit: profit,
        profitMargin: _profitMargin(revenue, profit),
      );
}

class _CustomerAccumulator {
  _CustomerAccumulator({
    required this.customerId,
    required this.customerName,
  });

  final String? customerId;
  final String customerName;
  int billCount = 0;
  int itemsPurchased = 0;
  double totalSpent = 0;
  DateTime? firstPurchaseDate;
  DateTime? lastPurchaseDate;

  CustomerPerformanceSummary toModel() => CustomerPerformanceSummary(
        customerId: customerId,
        customerName: customerName,
        billCount: billCount,
        itemsPurchased: itemsPurchased,
        totalSpent: totalSpent,
        averageOrderValue: billCount == 0 ? 0 : totalSpent / billCount,
        lastPurchaseDate: lastPurchaseDate!,
        firstPurchaseDate: firstPurchaseDate!,
      );
}

class _WalkInAccumulator {
  int billCount = 0;
  int itemsPurchased = 0;
  double totalSpent = 0;

  WalkInSummary toModel() => WalkInSummary(
        billCount: billCount,
        itemsPurchased: itemsPurchased,
        totalSpent: totalSpent,
      );
}

double _profitMargin(double revenue, double profit) =>
    revenue == 0 ? 0 : (profit / revenue) * 100;
