import 'dart:convert';
import 'dart:typed_data';

import '../models/analytics_summary.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../models/supplier.dart';

class CsvExportService {
  const CsvExportService();

  static const salesHeaders = [
    'Bill ID',
    'Bill Number',
    'Sale Timestamp (UTC ISO 8601)',
    'Customer ID',
    'Customer Name',
    'Customer Type',
    'Payment Method',
    'Product ID',
    'Product Name',
    'SKU',
    'Category Snapshot',
    'Quantity',
    'Unit Selling Price Snapshot',
    'Unit Purchase Price Snapshot',
    'Gross Line Amount',
    'Item Discount',
    'Line Amount After Item Discount',
    'Allocated Bill Discount',
    'Net Line Revenue',
    'Line Cost Snapshot',
    'Bill Discount Total',
    'Bill Total',
  ];

  static const inventoryHeaders = [
    'Product ID',
    'Product Name',
    'SKU',
    'Category',
    'Supplier ID',
    'Supplier Name',
    'Supplier Phone',
    'Supplier Email',
    'Supplier Address',
    'Purchase Price',
    'Selling Price',
    'Current Stock',
    'Reorder Level',
    'Stock Status',
    'Inventory Value',
  ];

  static const customerHeaders = [
    'Customer ID',
    'Customer Name',
    'Customer Type',
    'Order Count',
    'Items Purchased',
    'Total Spent',
    'Average Order Value',
    'First Purchase',
    'Last Purchase',
    'Repeat Customer',
  ];

  Uint8List generateSalesCsv(Iterable<Bill> bills) {
    final sortedBills = bills.toList().asMap().entries.toList()
      ..sort((first, second) {
        final dateOrder =
            second.value.createdAt.compareTo(first.value.createdAt);
        return dateOrder == 0 ? first.key.compareTo(second.key) : dateOrder;
      });
    final rows = <List<Object?>>[salesHeaders];

    for (final entry in sortedBills) {
      final bill = entry.value;
      final allocatedDiscounts = _allocatedBillDiscountCents(bill);
      for (var itemIndex = 0; itemIndex < bill.items.length; itemIndex++) {
        final item = bill.items[itemIndex];
        final lineCents = _toCents(item.lineTotal);
        final allocatedCents = allocatedDiscounts[itemIndex];
        rows.add([
          bill.id,
          bill.billNumber,
          _utcIso8601(bill.createdAt),
          _nullableText(bill.customerId),
          bill.customerName,
          _customerType(bill),
          bill.paymentMethod,
          item.productId,
          item.productName,
          item.sku,
          _nullableText(item.category),
          item.quantity,
          _money(item.sellingPrice),
          _money(item.purchasePrice),
          _money(item.quantity * item.sellingPrice),
          _money(item.discount),
          _moneyCents(lineCents),
          _moneyCents(allocatedCents),
          _moneyCents(lineCents - allocatedCents),
          _money(item.quantity * item.purchasePrice),
          if (itemIndex == 0) _money(bill.discount) else null,
          if (itemIndex == 0) _money(bill.total) else null,
        ]);
      }
    }

    return encodeRows(rows);
  }

  Uint8List generateInventoryCsv(
    Iterable<Product> products, {
    required Iterable<Supplier> suppliers,
  }) {
    final suppliersById = {
      for (final supplier in suppliers) supplier.id: supplier
    };
    final sortedProducts = products.toList()
      ..sort((first, second) {
        final nameOrder =
            first.name.toLowerCase().compareTo(second.name.toLowerCase());
        if (nameOrder != 0) return nameOrder;
        final skuOrder =
            first.sku.toLowerCase().compareTo(second.sku.toLowerCase());
        return skuOrder == 0 ? first.id.compareTo(second.id) : skuOrder;
      });
    final rows = <List<Object?>>[inventoryHeaders];

    for (final product in sortedProducts) {
      final supplier = suppliersById[product.supplierId];
      rows.add([
        product.id,
        product.name,
        product.sku,
        product.category,
        product.supplierId,
        supplier?.name,
        supplier?.phone,
        supplier?.email,
        supplier?.address,
        _money(product.purchasePrice),
        _money(product.sellingPrice),
        product.stockQuantity,
        product.reorderLevel,
        _stockStatus(product),
        _money(product.stockQuantity * product.purchasePrice),
      ]);
    }

    return encodeRows(rows);
  }

  Uint8List generateCustomersCsv(Iterable<Bill> bills) {
    final billList = bills.toList(growable: false);
    final summary = AnalyticsSummary.fromBills(billList);
    final customers = summary.customers.toList()
      ..sort((first, second) {
        final spendOrder = second.totalSpent.compareTo(first.totalSpent);
        if (spendOrder != 0) return spendOrder;
        final nameOrder = first.customerName
            .toLowerCase()
            .compareTo(second.customerName.toLowerCase());
        if (nameOrder != 0) return nameOrder;
        return (first.customerId ?? '').compareTo(second.customerId ?? '');
      });
    final rows = <List<Object?>>[customerHeaders];

    for (final customer in customers) {
      rows.add([
        _nullableText(customer.customerId),
        customer.customerName,
        'Named',
        customer.billCount,
        customer.itemsPurchased,
        _money(customer.totalSpent),
        _money(customer.averageOrderValue),
        _utcIso8601(customer.firstPurchaseDate),
        _utcIso8601(customer.lastPurchaseDate),
        customer.isRepeatCustomer,
      ]);
    }

    final walkIn = summary.walkIn;
    if (walkIn != null) {
      final walkInBills = billList.where(_isWalkInBill).toList(growable: false);
      final dates = walkInBills.map((bill) => bill.createdAt).toList()
        ..sort((first, second) => first.compareTo(second));
      rows.add([
        null,
        'Walk-in Customer',
        'Walk-in',
        walkIn.billCount,
        walkIn.itemsPurchased,
        _money(walkIn.totalSpent),
        _money(walkIn.totalSpent / walkIn.billCount),
        _utcIso8601(dates.first),
        _utcIso8601(dates.last),
        walkIn.billCount > 1,
      ]);
    }

    return encodeRows(rows);
  }

  Uint8List encodeRows(Iterable<List<Object?>> rows) {
    final csv = rows.map(_encodeRow).join('\r\n');
    return Uint8List.fromList(utf8.encode('\uFEFF$csv'));
  }

  String _encodeRow(List<Object?> row) => row.map(_encodeField).join(',');

  String _encodeField(Object? value) {
    if (value == null) return '';

    final isText = value is String;
    var field = value.toString();
    if (isText) {
      if (RegExp(r'^[\s\uFEFF]*[=+\-@]').hasMatch(field)) {
        // Excel treats a leading apostrophe as text while displaying the original value.
        field = "'$field";
      }
      field = field
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\n', '\r\n');
    }
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\r') ||
        field.contains('\n')) {
      field = '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  List<int> _allocatedBillDiscountCents(Bill bill) {
    if (bill.items.isEmpty) return const [];

    final lineCents =
        bill.items.map((item) => _toCents(item.lineTotal)).toList();
    final subtotalCents = lineCents.fold<int>(0, (sum, value) => sum + value);
    final targetTotalCents = _toCents(bill.total);
    final allocationCents = subtotalCents - targetTotalCents;
    if (allocationCents == 0 || subtotalCents == 0) {
      return List<int>.filled(bill.items.length, 0, growable: false);
    }

    final magnitude = allocationCents.abs();
    final allocations = <int>[];
    final remainders = <(int index, int remainder)>[];
    var allocated = 0;
    for (var index = 0; index < lineCents.length; index++) {
      final numerator = magnitude * lineCents[index];
      final share = numerator ~/ subtotalCents;
      allocations.add(share);
      allocated += share;
      remainders.add((index, numerator % subtotalCents));
    }

    remainders.sort((first, second) {
      final remainderOrder = second.$2.compareTo(first.$2);
      return remainderOrder == 0
          ? first.$1.compareTo(second.$1)
          : remainderOrder;
    });
    final remainingCents = magnitude - allocated;
    for (var index = 0; index < remainingCents; index++) {
      allocations[remainders[index].$1]++;
    }

    return allocationCents < 0
        ? allocations.map((value) => -value).toList(growable: false)
        : allocations;
  }

  static String _customerType(Bill bill) =>
      _isWalkInBill(bill) ? 'Walk-in' : 'Named';

  static bool _isWalkInBill(Bill bill) {
    final customerId = bill.customerId?.trim();
    if (customerId != null && customerId.isNotEmpty) return false;
    final name = bill.customerName.trim();
    return name.isEmpty || name.toLowerCase() == 'walk-in customer';
  }

  static String _stockStatus(Product product) {
    if (product.stockQuantity == 0) return 'Out of Stock';
    if (product.stockQuantity <= product.reorderLevel) return 'Low Stock';
    return 'In Stock';
  }

  static String _utcIso8601(DateTime value) => value.toUtc().toIso8601String();

  static String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int _toCents(double value) =>
      value.isFinite ? (value * 100).round() : 0;

  static _CsvMoney _money(double value) => _moneyCents(_toCents(value));

  static _CsvMoney _moneyCents(int cents) => _CsvMoney(cents);
}

class _CsvMoney {
  const _CsvMoney(this.cents);

  final int cents;

  @override
  String toString() {
    final absoluteCents = cents.abs();
    final whole = absoluteCents ~/ 100;
    final fraction = (absoluteCents % 100).toString().padLeft(2, '0');
    return '${cents < 0 ? '-' : ''}$whole.$fraction';
  }
}
