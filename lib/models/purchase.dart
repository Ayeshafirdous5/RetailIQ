import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItem {
  factory PurchaseItem({
    required String productId,
    required String productName,
    required String sku,
    required int quantity,
    required double purchasePrice,
  }) {
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'cannot be negative');
    }
    if (purchasePrice < 0) {
      throw ArgumentError.value(
        purchasePrice,
        'purchasePrice',
        'cannot be negative',
      );
    }
    return PurchaseItem._(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: quantity,
      purchasePrice: purchasePrice,
    );
  }

  const PurchaseItem._({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.purchasePrice,
  });

  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final double purchasePrice;

  double get lineTotal => quantity * purchasePrice;

  factory PurchaseItem.fromMap(Map<String, dynamic> data) {
    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
    final purchasePrice = (data['purchasePrice'] as num?)?.toDouble() ?? 0;
    if (quantity < 0 || purchasePrice < 0) {
      throw const FormatException(
        'Purchase item quantity and price cannot be negative.',
      );
    }
    return PurchaseItem(
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      quantity: quantity,
      purchasePrice: purchasePrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'lineTotal': lineTotal,
    };
  }

  PurchaseItem copyWith({
    String? productId,
    String? productName,
    String? sku,
    int? quantity,
    double? purchasePrice,
  }) {
    return PurchaseItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}

class Purchase {
  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    required List<PurchaseItem> items,
    required this.createdAt,
  }) : items = List.unmodifiable(items);

  final String id;
  final String purchaseNumber;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final DateTime createdAt;

  double get subtotal =>
      items.fold(0, (runningTotal, item) => runningTotal + item.lineTotal);

  double get totalAmount => subtotal;

  factory Purchase.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Purchase document ${snapshot.id} has no data.');
    }
    return Purchase.fromMap(data, id: snapshot.id);
  }

  factory Purchase.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return Purchase(
      id: id,
      purchaseNumber: data['purchaseNumber'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? '',
      items: rawItems
          .map((item) => PurchaseItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      createdAt: _dateTimeFromFirestore(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseNumber': purchaseNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'subtotal': subtotal,
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Purchase copyWith({
    String? id,
    String? purchaseNumber,
    String? supplierId,
    String? supplierName,
    List<PurchaseItem>? items,
    DateTime? createdAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw StateError('Purchase timestamp is missing or invalid.');
  }
}