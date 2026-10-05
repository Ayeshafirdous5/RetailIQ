import 'package:flutter_test/flutter_test.dart';
import 'package:retail_iq/models/bill.dart';
import 'package:retail_iq/services/bill_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a walk-in Cash invoice with bill discount and rupee values',
      () async {
    final bill = _bill(
      customerName: 'Walk-in Customer',
      paymentMethod: 'Cash',
      discount: 10,
      items: [_item(name: 'Tea', quantity: 2, sellingPrice: 30)],
    );

    expect(bill.total, 50);
    await _expectPdfGenerated(bill);
  });

  test('generates an invoice for a named UPI customer', () async {
    await _expectPdfGenerated(
      _bill(
        customerId: 'customer-1',
        customerName: 'Ayesha Khan',
        paymentMethod: 'UPI',
        items: [_item(name: 'Notebook', quantity: 1, sellingPrice: 45)],
      ),
    );
  });

  for (final paymentMethod in ['Card', 'Other']) {
    test('supports $paymentMethod payment', () async {
      await _expectPdfGenerated(
        _bill(
          customerName: 'Walk-in Customer',
          paymentMethod: paymentMethod,
          items: [_item(name: 'Stapler', quantity: 1, sellingPrice: 80)],
        ),
      );
    });
  }

  test('uses multiple saved item snapshots, quantities, and category',
      () async {
    final firstItem = _item(
      name: 'Archived product name',
      category: 'Historical category',
      quantity: 3,
      sellingPrice: 25,
      purchasePrice: 12,
      discount: 5,
    );
    final secondItem = _item(
      name: 'Second product',
      category: 'Seasonal',
      quantity: 2,
      sellingPrice: 14.5,
      purchasePrice: 7.25,
    );
    final bill = _bill(
      paymentMethod: 'Cash',
      items: [firstItem, secondItem],
    );

    expect(firstItem.sellingPrice, 25);
    expect(firstItem.purchasePrice, 12);
    expect(firstItem.lineTotal, 70);
    expect(bill.subtotal, 99);
    await _expectPdfGenerated(bill);
  });

  test('supports long product names and SKUs', () async {
    await _expectPdfGenerated(
      _bill(
        paymentMethod: 'UPI',
        items: [
          _item(
            name: 'Premium retail product with a long descriptive name ' * 8,
            sku: 'SKU-LONG-CODE-' * 12,
            quantity: 2,
            sellingPrice: 199.99,
          ),
        ],
      ),
    );
  });

  test('serializes an invoice with enough items to span multiple pages',
      () async {
    final items = List.generate(
      90,
      (index) => _item(
        name: 'Product ${index + 1} with saved description',
        sku: 'SKU-${index + 1}',
        quantity: index % 4 + 1,
        sellingPrice: 10 + index.toDouble(),
        purchasePrice: 5 + index.toDouble(),
      ),
    );

    await _expectPdfGenerated(_bill(items: items, paymentMethod: 'Card'));
  });
}

Future<void> _expectPdfGenerated(Bill bill) async {
  final bytes = await BillPdfService.generate(bill);
  expect(bytes, isNotEmpty);
}

Bill _bill({
  String? customerId,
  String customerName = 'Walk-in Customer',
  String paymentMethod = 'Other',
  double discount = 0,
  List<BillItem> items = const [],
}) {
  return Bill(
    id: 'saved-bill-id',
    billNumber: 'RIQ-2025-0001',
    customerId: customerId,
    customerName: customerName,
    items: items,
    discount: discount,
    paymentMethod: paymentMethod,
    createdAt: DateTime.utc(2025, 3, 8, 10, 30),
  );
}

BillItem _item({
  required String name,
  String sku = 'SKU-001',
  String? category,
  int quantity = 1,
  double sellingPrice = 10,
  double purchasePrice = 4,
  double discount = 0,
}) {
  return BillItem(
    productId: 'product-id',
    productName: name,
    sku: sku,
    category: category,
    quantity: quantity,
    sellingPrice: sellingPrice,
    purchasePrice: purchasePrice,
    discount: discount,
  );
}
