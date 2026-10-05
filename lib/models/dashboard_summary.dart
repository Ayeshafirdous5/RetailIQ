import 'bill.dart';
import 'product.dart';
import 'purchase.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.totalRevenue,
    required this.totalBills,
    required this.totalItemsSold,
    required this.totalProfit,
    required this.totalPurchases,
    required this.totalInventoryValue,
    required this.lowStockProducts,
    required this.outOfStockProducts,
  });

  const DashboardSummary.empty()
      : totalRevenue = 0,
        totalBills = 0,
        totalItemsSold = 0,
        totalProfit = 0,
        totalPurchases = 0,
        totalInventoryValue = 0,
        lowStockProducts = 0,
        outOfStockProducts = 0;

  final double totalRevenue;
  final int totalBills;
  final int totalItemsSold;
  final double totalProfit;
  final double totalPurchases;
  final double totalInventoryValue;
  final int lowStockProducts;
  final int outOfStockProducts;

  factory DashboardSummary.fromData({
    required List<Bill> bills,
    required List<Purchase> purchases,
    required List<Product> products,
  }) {
    var revenue = 0.0;
    var itemsSold = 0;
    var profit = 0.0;
    for (final bill in bills) {
      revenue += bill.total;
      itemsSold += bill.items.fold<int>(
        0,
        (total, item) => total + item.quantity,
      );
      final itemCost = bill.items.fold<double>(
        0,
        (total, item) => total + (item.purchasePrice * item.quantity),
      );
      profit += bill.total - itemCost;
    }

    var purchaseTotal = 0.0;
    for (final purchase in purchases) {
      purchaseTotal += purchase.totalAmount;
    }

    var inventoryValue = 0.0;
    var lowStock = 0;
    var outOfStock = 0;
    for (final product in products) {
      inventoryValue += product.stockQuantity * product.purchasePrice;
      if (product.stockQuantity == 0) {
        outOfStock++;
      } else if (product.stockQuantity <= product.reorderLevel) {
        lowStock++;
      }
    }

    return DashboardSummary(
      totalRevenue: revenue,
      totalBills: bills.length,
      totalItemsSold: itemsSold,
      totalProfit: profit,
      totalPurchases: purchaseTotal,
      totalInventoryValue: inventoryValue,
      lowStockProducts: lowStock,
      outOfStockProducts: outOfStock,
    );
  }
}