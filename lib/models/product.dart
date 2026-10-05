import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.supplierId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.reorderLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String supplierId;
  final double purchasePrice;
  final double sellingPrice;
  final int stockQuantity;
  final int reorderLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Product document ${snapshot.id} has no data.');
    }

    return Product(
      id: snapshot.id,
      name: data['name'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      category: data['category'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
      createdAt: _dateTimeFromFirestore(data['createdAt']),
      updatedAt: _dateTimeFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sku': sku,
      'category': category,
      'supplierId': supplierId,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity,
      'reorderLevel': reorderLevel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    throw StateError('Product timestamp is missing or invalid.');
  }
}