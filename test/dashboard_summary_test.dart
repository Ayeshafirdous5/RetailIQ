import 'package:flutter_test/flutter_test.dart';
import 'package:retail_iq/models/bill.dart';
import 'package:retail_iq/models/dashboard_summary.dart';
import 'package:retail_iq/models/product.dart';
import 'package:retail_iq/models/purchase.dart';

void main() {
  final timestamp = DateTime(2026, 9, 22);

  Bill bill({required double discount}) {
    return Bill(
      id: '',
      billNumber: 'BILL-1',
      customerId: null,
      customerName: 'Walk-in Customer',
      items: const [
        BillItem(
          productId: 'mouse',
          productName: 'Mouse',
          sku: 'M-001',
          quantity: 1,
          sellingPrice: 849,
          purchasePrice: 500,
          discount: 0,
        ),
      ],
      discount: discount,
      paymentMethod: 'Cash',
      createdAt: timestamp,
    );
  }

  Product product({required int stock, required int reorderLevel}) {
    return Product(
      id: 'product-$stock-$reorderLevel',
      name: 'Product',
      sku: 'SKU',
      category: 'General',
      supplierId: 'supplier',
      purchasePrice: 500,
      sellingPrice: 849,
      stockQuantity: stock,
      reorderLevel: reorderLevel,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Purchase purchase(double amount) {
    return Purchase(
      id: '',
      purchaseNumber: 'PUR-1',
      supplierId: 'supplier',
      supplierName: 'Supplier',
      items: [
        PurchaseItem(
          productId: 'mouse',
          productName: 'Mouse',
          sku: 'M-001',
          quantity: 1,
          purchasePrice: amount,
        ),
      ],
      createdAt: timestamp,
    );
  }

  test('calculates revenue, items, discounted profit, and purchases', () {
    final summary = DashboardSummary.fromData(
      bills: [bill(discount: 100), bill(discount: 0)],
      purchases: [purchase(500), purchase(250)],
      products: const [],
    );

    expect(summary.totalRevenue, 1598);
    expect(summary.totalBills, 2);
    expect(summary.totalItemsSold, 2);
    expect(summary.totalProfit, 598);
    expect(summary.totalPurchases, 750);
  });

  test('calculates inventory value and stock status counts', () {
    final summary = DashboardSummary.fromData(
      bills: const [],
      purchases: const [],
      products: [
        product(stock: 0, reorderLevel: 5),
        product(stock: 3, reorderLevel: 5),
        product(stock: 10, reorderLevel: 5),
      ],
    );

    expect(summary.totalInventoryValue, 6500);
    expect(summary.lowStockProducts, 1);
    expect(summary.outOfStockProducts, 1);
  });

  test('returns zero KPIs for empty data', () {
    final summary = DashboardSummary.fromData(
      bills: const [],
      purchases: const [],
      products: const [],
    );

    expect(summary.totalRevenue, 0);
    expect(summary.totalBills, 0);
    expect(summary.totalItemsSold, 0);
    expect(summary.totalProfit, 0);
    expect(summary.totalPurchases, 0);
    expect(summary.totalInventoryValue, 0);
    expect(summary.lowStockProducts, 0);
    expect(summary.outOfStockProducts, 0);
  });
}