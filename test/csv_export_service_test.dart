import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_iq/models/bill.dart';
import 'package:retail_iq/models/product.dart';
import 'package:retail_iq/models/supplier.dart';
import 'package:retail_iq/services/csv_export_service.dart';

void main() {
  const service = CsvExportService();

  test('encodes BOM, CRLF, escaped text, Unicode and formula-safe text', () {
    final bytes = service.encodeRows([
      ['Comma', 'Quote', 'Newline', 'Unicode', 'Empty', 'Formula', 'Number'],
      [
        'a,b',
        'say "hello"',
        'line one\nline two',
        'தமிழ் ₹',
        null,
        '=1+1',
        -3.25
      ],
      ['+cmd', '-formula', '@SUM(A1:A2)', '', 'plain', null, 0],
    ]);
    final decoded = utf8.decode(bytes);
    final rows = _parseCsv(bytes);

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(decoded, contains('"a,b"'));
    expect(decoded, contains('"say ""hello"""'));
    expect(decoded, contains('"line one\r\nline two"'));
    expect(decoded, contains('தமிழ் ₹'));
    expect(decoded, isNot(contains(RegExp(r'(?<!\r)\n'))));
    expect(rows[1], [
      'a,b',
      'say "hello"',
      'line one\r\nline two',
      'தமிழ் ₹',
      '',
      "'=1+1",
      '-3.25',
    ]);
    expect(rows[2].sublist(0, 4), ["'+cmd", "'-formula", "'@SUM(A1:A2)", '']);
    expect(rows[2][6], '0');
  });

  test('emits headers for empty sales, inventory and customer exports', () {
    final sales = _parseCsv(service.generateSalesCsv(const []));
    final inventory = _parseCsv(
      service.generateInventoryCsv(const [], suppliers: const []),
    );
    final customers = _parseCsv(service.generateCustomersCsv(const []));

    expect(sales, [CsvExportService.salesHeaders]);
    expect(inventory, [CsvExportService.inventoryHeaders]);
    expect(customers, [CsvExportService.customerHeaders]);
  });

  test('sales headers and one saved walk-in line use snapshot values', () {
    final bill = _bill(
      id: 'bill-1',
      billNumber: 'B-1',
      createdAt: DateTime.parse('2025-03-08T10:30:00+05:30'),
      customerName: 'Walk-in Customer',
      paymentMethod: 'Cash',
      items: [
        _item(
          productId: 'deleted-product',
          name: 'Historical product',
          sku: 'OLD-SKU',
          category: 'Old category',
          quantity: 2,
          sellingPrice: 12.5,
          purchasePrice: 7.25,
          discount: 2,
        ),
      ],
      discount: 3,
    );
    final rows = _parseCsv(service.generateSalesCsv([bill]));
    final row = _record(rows[0], rows[1]);

    expect(rows[0], CsvExportService.salesHeaders);
    expect(rows, hasLength(2));
    expect(row['Bill ID'], 'bill-1');
    expect(row['Sale Timestamp (UTC ISO 8601)'], '2025-03-08T05:00:00.000Z');
    expect(row['Customer Type'], 'Walk-in');
    expect(row['Payment Method'], 'Cash');
    expect(row['Product ID'], 'deleted-product');
    expect(row['Product Name'], 'Historical product');
    expect(row['Category Snapshot'], 'Old category');
    expect(row['Unit Selling Price Snapshot'], '12.50');
    expect(row['Unit Purchase Price Snapshot'], '7.25');
    expect(row['Gross Line Amount'], '25.00');
    expect(row['Item Discount'], '2.00');
    expect(row['Line Amount After Item Discount'], '23.00');
    expect(row['Allocated Bill Discount'], '3.00');
    expect(row['Net Line Revenue'], '20.00');
    expect(row['Line Cost Snapshot'], '14.50');
    expect(row['Bill Discount Total'], '3.00');
    expect(row['Bill Total'], '20.00');
  });

  test('sales preserve duplicate product rows and do not repeat bill totals',
      () {
    final bill = _bill(
      id: 'bill-2',
      billNumber: 'B-2',
      items: [
        _item(productId: 'same', name: 'Same', quantity: 1, sellingPrice: 10),
        _item(productId: 'same', name: 'Same', quantity: 2, sellingPrice: 5),
      ],
      discount: 2,
      paymentMethod: 'UPI',
    );
    final rows = _parseCsv(service.generateSalesCsv([bill]));
    final first = _record(rows[0], rows[1]);
    final second = _record(rows[0], rows[2]);

    expect(rows, hasLength(3));
    expect(first['Product ID'], second['Product ID']);
    expect(first['Bill Discount Total'], '2.00');
    expect(second['Bill Discount Total'], '');
    expect(first['Bill Total'], '18.00');
    expect(second['Bill Total'], '');
    expect(_moneySum([first, second], 'Net Line Revenue'), '18.00');
  });

  test('allocates bill discount proportionally after item discounts', () {
    final bill = _bill(
      id: 'bill-discounts',
      items: [
        _item(
          productId: 'a',
          name: 'A',
          quantity: 2,
          sellingPrice: 50,
          discount: 10,
        ),
        _item(
          productId: 'b',
          name: 'B',
          quantity: 1,
          sellingPrice: 40,
        ),
      ],
      discount: 13,
      paymentMethod: 'Card',
    );
    final rows = _parseCsv(service.generateSalesCsv([bill]));
    final first = _record(rows[0], rows[1]);
    final second = _record(rows[0], rows[2]);

    expect(first['Gross Line Amount'], '100.00');
    expect(first['Item Discount'], '10.00');
    expect(first['Line Amount After Item Discount'], '90.00');
    expect(second['Line Amount After Item Discount'], '40.00');
    expect(first['Allocated Bill Discount'], '9.00');
    expect(second['Allocated Bill Discount'], '4.00');
    expect(first['Net Line Revenue'], '81.00');
    expect(second['Net Line Revenue'], '36.00');
    expect(_moneySum([first, second], 'Allocated Bill Discount'), '13.00');
    expect(_moneySum([first, second], 'Net Line Revenue'), '117.00');
    expect(bill.total, 117);
  });

  test('cent remainder is allocated deterministically and reconciles total',
      () {
    final bill = _bill(
      id: 'bill-rounding',
      items: [
        _item(productId: 'a', name: 'A', sellingPrice: 0.01),
        _item(productId: 'b', name: 'B', sellingPrice: 0.02),
        _item(productId: 'c', name: 'C', sellingPrice: 0.03),
      ],
      discount: 0.01,
    );
    final rows = _parseCsv(service.generateSalesCsv([bill]));
    final lineRows = rows.skip(1).map((row) => _record(rows[0], row)).toList();
    final repeatedRows = _parseCsv(service.generateSalesCsv([bill]));

    expect(
      lineRows.map((row) => row['Allocated Bill Discount']),
      ['0.00', '0.00', '0.01'],
    );
    expect(_moneySum(lineRows, 'Net Line Revenue'), '0.05');
    expect(
        _moneySum(lineRows, 'Net Line Revenue'),
        _moneySum(
            repeatedRows
                .skip(1)
                .map((row) => _record(repeatedRows[0], row))
                .toList(),
            'Net Line Revenue'));
  });

  test('sorts bills newest first and keeps item order within each bill', () {
    final older = _bill(
      id: 'older',
      createdAt: DateTime.utc(2025, 1, 1),
      items: [
        _item(productId: 'old-a', name: 'Old A'),
        _item(productId: 'old-b', name: 'Old B'),
      ],
    );
    final newer = _bill(
      id: 'newer',
      createdAt: DateTime.utc(2025, 2, 1),
      items: [_item(productId: 'new-a', name: 'New A')],
    );
    final rows = _parseCsv(service.generateSalesCsv([older, newer]));

    expect(rows.skip(1).map((row) => row[0]), ['newer', 'older', 'older']);
    expect(rows.skip(1).map((row) => row[7]), ['new-a', 'old-a', 'old-b']);
  });

  test('supports every saved payment method', () {
    for (final method in ['Cash', 'UPI', 'Card', 'Other']) {
      final rows = _parseCsv(
        service.generateSalesCsv([
          _bill(
            id: method,
            paymentMethod: method,
            items: [_item(productId: method, name: method)],
          ),
        ]),
      );
      expect(_record(rows[0], rows[1])['Payment Method'], method);
    }
  });

  test('inventory exports supplier data, statuses, values and sorted products',
      () {
    final products = [
      _product(id: 'zero', name: 'Zero stock', stock: 0, reorderLevel: 2),
      _product(id: 'low', name: 'Low stock', stock: 2, reorderLevel: 2),
      _product(id: 'in', name: 'In stock', stock: 3, reorderLevel: 2),
      _product(
        id: 'missing-supplier',
        name: 'Missing supplier',
        supplierId: 'deleted-supplier',
        stock: 4,
      ),
    ];
    final supplier = Supplier(
      id: 'supplier-1',
      name: 'Supply, "Co"',
      phone: '555-0100',
      email: 'sales@example.com',
      address: '1 Main St, Suite 2',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
    final sorted = [...products]..sort((a, b) => a.name.compareTo(b.name));
    final rows = _parseCsv(
      service.generateInventoryCsv(products, suppliers: [supplier]),
    );
    final records = rows.skip(1).map((row) => _record(rows[0], row)).toList();
    final byId = {for (final record in records) record['Product ID']: record};

    expect(rows[0], CsvExportService.inventoryHeaders);
    expect(rows.skip(1).map((row) => row[1]), sorted.map((p) => p.name));
    expect(byId['zero']!['Stock Status'], 'Out of Stock');
    expect(byId['low']!['Stock Status'], 'Low Stock');
    expect(byId['in']!['Stock Status'], 'In Stock');
    expect(byId['in']!['Inventory Value'], '15.00');
    expect(byId['in']!['Supplier Name'], 'Supply, "Co"');
    expect(byId['in']!['Supplier Address'], '1 Main St, Suite 2');
    expect(byId['missing-supplier']!['Supplier ID'], 'deleted-supplier');
    expect(byId['missing-supplier']!['Supplier Name'], '');
    expect(byId['missing-supplier']!['Supplier Phone'], '');
  });

  test('aggregates named customers by ID and legacy name, with a walk-in row',
      () {
    final bills = [
      _bill(
        id: 'c1-first',
        createdAt: DateTime.utc(2025, 1, 2),
        customerId: 'customer-1',
        customerName: 'Same Name',
        items: [
          _item(
              productId: 'p',
              name: 'P',
              quantity: 2,
              sellingPrice: 50,
              discount: 10)
        ],
        discount: 10,
      ),
      _bill(
        id: 'c1-second',
        createdAt: DateTime.utc(2025, 2, 3),
        customerId: 'customer-1',
        customerName: 'Same Name',
        items: [_item(productId: 'p', name: 'P', sellingPrice: 100)],
      ),
      _bill(
        id: 'c2',
        customerId: 'customer-2',
        customerName: 'Same Name',
        items: [_item(productId: 'p', name: 'P', sellingPrice: 5)],
      ),
      _bill(
        id: 'legacy-a',
        customerName: 'Legacy Name',
        items: [_item(productId: 'p', name: 'P', sellingPrice: 10)],
      ),
      _bill(
        id: 'legacy-b',
        customerName: 'LEGACY NAME',
        items: [
          _item(productId: 'p', name: 'P', quantity: 2, sellingPrice: 10)
        ],
      ),
      _bill(
        id: 'walkin-a',
        createdAt: DateTime.utc(2025, 3, 1),
        items: [
          _item(productId: 'p', name: 'P', quantity: 2, sellingPrice: 10)
        ],
      ),
      _bill(
        id: 'walkin-b',
        createdAt: DateTime.utc(2025, 3, 9),
        items: [_item(productId: 'p', name: 'P', sellingPrice: 20)],
      ),
    ];
    final rows = _parseCsv(service.generateCustomersCsv(bills));
    final records = rows.skip(1).map((row) => _record(rows[0], row)).toList();
    final namedCustomers =
        records.where((row) => row['Customer Type'] == 'Named').toList();
    final byId = {
      for (final row in namedCustomers) row['Customer ID']: row,
    };
    final firstCustomer = byId['customer-1']!;
    final secondCustomer = byId['customer-2']!;
    final legacy = namedCustomers.singleWhere(
      (row) => row['Customer Name'] == 'Legacy Name',
    );
    final walkIn =
        records.singleWhere((row) => row['Customer Type'] == 'Walk-in');

    expect(rows[0], CsvExportService.customerHeaders);
    expect(records, hasLength(4));
    expect(firstCustomer['Order Count'], '2');
    expect(firstCustomer['Items Purchased'], '3');
    expect(firstCustomer['Total Spent'], '180.00');
    expect(firstCustomer['Average Order Value'], '90.00');
    expect(firstCustomer['First Purchase'], '2025-01-02T00:00:00.000Z');
    expect(firstCustomer['Last Purchase'], '2025-02-03T00:00:00.000Z');
    expect(firstCustomer['Repeat Customer'], 'true');
    expect(secondCustomer['Customer Name'], 'Same Name');
    expect(secondCustomer['Order Count'], '1');
    expect(legacy['Customer Name'], 'Legacy Name');
    expect(legacy['Order Count'], '2');
    expect(walkIn['Customer Name'], 'Walk-in Customer');
    expect(walkIn['Order Count'], '2');
    expect(walkIn['Items Purchased'], '3');
    expect(walkIn['Total Spent'], '40.00');
    expect(walkIn['Average Order Value'], '20.00');
    expect(walkIn['First Purchase'], '2025-03-01T00:00:00.000Z');
    expect(walkIn['Last Purchase'], '2025-03-09T00:00:00.000Z');
    expect(walkIn['Repeat Customer'], 'true');
  });
}

Map<String, String> _record(List<String> headers, List<String> values) => {
      for (var index = 0; index < headers.length; index++)
        headers[index]: values[index],
    };

String _moneySum(List<Map<String, String>> rows, String column) {
  final cents = rows.fold<int>(
    0,
    (sum, row) {
      final parts = row[column]!.split('.');
      return sum + int.parse(parts[0]) * 100 + int.parse(parts[1]);
    },
  );
  return '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

List<List<String>> _parseCsv(Uint8List bytes) {
  var input = utf8.decode(bytes);
  if (input.startsWith('\uFEFF')) input = input.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  for (var index = 0; index < input.length; index++) {
    final character = input[index];
    if (quoted) {
      if (character == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = false;
        }
      } else {
        field.write(character);
      }
    } else if (character == '"' && field.isEmpty) {
      quoted = true;
    } else if (character == ',') {
      row.add(field.toString());
      field.clear();
    } else if (character == '\r' &&
        index + 1 < input.length &&
        input[index + 1] == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
      index++;
    } else {
      field.write(character);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

Bill _bill({
  required String id,
  String? billNumber,
  DateTime? createdAt,
  String? customerId,
  String customerName = 'Walk-in Customer',
  String paymentMethod = 'Cash',
  double discount = 0,
  List<BillItem> items = const [],
}) {
  return Bill(
    id: id,
    billNumber: billNumber ?? id,
    customerId: customerId,
    customerName: customerName,
    items: items,
    discount: discount,
    paymentMethod: paymentMethod,
    createdAt: createdAt ?? DateTime.utc(2025, 1, 1),
  );
}

BillItem _item({
  required String productId,
  required String name,
  String sku = 'SKU-1',
  String? category = 'General',
  int quantity = 1,
  double sellingPrice = 10,
  double purchasePrice = 4,
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

Product _product({
  required String id,
  required String name,
  String sku = 'SKU',
  String category = 'Category',
  String supplierId = 'supplier-1',
  int stock = 4,
  int reorderLevel = 2,
  double purchasePrice = 5,
  double sellingPrice = 9,
}) {
  return Product(
    id: id,
    name: name,
    sku: sku,
    category: category,
    supplierId: supplierId,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    stockQuantity: stock,
    reorderLevel: reorderLevel,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}
