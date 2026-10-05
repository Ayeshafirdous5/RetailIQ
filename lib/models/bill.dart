import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  const BillItem({
    required this.productId,
    required this.productName,
    required this.sku,
    this.category,
    required this.quantity,
    required this.sellingPrice,
    required this.purchasePrice,
    required this.discount,
  });

  final String productId;
  final String productName;
  final String sku;
  final String? category;
  final int quantity;
  final double sellingPrice;
  final double purchasePrice;
  final double discount;

  double get lineTotal => math.max(
        0,
        (math.max(0, quantity) * math.max(0, sellingPrice)) -
            math.max(0, discount),
      );

  factory BillItem.fromMap(Map<String, dynamic> data) {
    return BillItem(
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      category: data['category'] as String?,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'category': category,
      'quantity': quantity,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'discount': discount,
    };
  }

  BillItem copyWith({
    String? productId,
    String? productName,
    String? sku,
    String? category,
    int? quantity,
    double? sellingPrice,
    double? purchasePrice,
    double? discount,
  }) {
    return BillItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      discount: discount ?? this.discount,
    );
  }
}

class Bill {
  const Bill({
    required this.id,
    required this.billNumber,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.discount,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String billNumber;
  final String? customerId;
  final String customerName;
  final List<BillItem> items;
  final double discount;
  final String paymentMethod;
  final DateTime createdAt;

  double get subtotal =>
      items.fold(0, (runningTotal, item) => runningTotal + item.lineTotal);

  double get total => math.max(0, subtotal - math.max(0, discount));

  factory Bill.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Bill document ${snapshot.id} has no data.');
    }
    return Bill.fromMap(data, id: snapshot.id);
  }

  factory Bill.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return Bill(
      id: id,
      billNumber: data['billNumber'] as String? ?? '',
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String? ?? 'Walk-in Customer',
      items: rawItems
          .map((item) => BillItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: data['paymentMethod'] as String? ?? 'Other',
      createdAt: _dateTimeFromFirestore(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'billNumber': billNumber,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Bill copyWith({
    String? id,
    String? billNumber,
    String? customerId,
    String? customerName,
    List<BillItem>? items,
    double? discount,
    String? paymentMethod,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw StateError('Bill timestamp is missing or invalid.');
  }
}
