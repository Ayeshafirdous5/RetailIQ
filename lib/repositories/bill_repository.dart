import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/bill.dart';
import '../models/product.dart';

class BillRepository {
  BillRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> addBill(Bill bill) async {
    final billReference = _billsCollection.doc();
    try {
      await billReference.set({
        ...bill.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return billReference.id;
    } on FirebaseException catch (error) {
      throw BillRepositoryException(
        'Unable to add bill: ${error.message ?? error.code}.',
      );
    }
  }

  Future<String> completeSale(Bill bill) async {
    final bills = _billsCollection;
    _validateBill(bill);
    final billReference = bills.doc();
    final quantitiesByProductId = <String, int>{};
    for (final item in bill.items) {
      quantitiesByProductId.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    SaleBusinessException? businessError;
    try {
      await _firestore.runTransaction((transaction) async {
        try {
          final productReferences = quantitiesByProductId.keys
              .map((productId) => _productsCollection.doc(productId))
              .toList(growable: false);
          final productSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
          for (var index = 0; index < productReferences.length; index++) {
            final snapshot = await transaction.get(productReferences[index]);
            productSnapshots[productReferences[index].id] = snapshot;
          }

          final stockUpdates = <DocumentReference<Map<String, dynamic>>, int>{};
          for (final entry in quantitiesByProductId.entries) {
            final snapshot = productSnapshots[entry.key];
            if (snapshot == null || !snapshot.exists) {
              final item = bill.items.firstWhere(
                (billItem) => billItem.productId == entry.key,
              );
              throw SaleProductNotFoundException(item.productName);
            }
            final product = Product.fromFirestore(snapshot);
            if (product.stockQuantity < entry.value) {
              throw InsufficientStockException(
                productName: product.name,
                available: product.stockQuantity,
                requested: entry.value,
              );
            }
            stockUpdates[_productsCollection.doc(entry.key)] =
                product.stockQuantity - entry.value;
          }

          final billData = {
            ...bill.toFirestore(),
            'createdAt': FieldValue.serverTimestamp(),
          };
          transaction.set(billReference, billData);
          for (final entry in stockUpdates.entries) {
            transaction.update(entry.key, {
              'stockQuantity': entry.value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } on SaleBusinessException catch (error) {
          businessError = error;
        }
      });
      if (businessError != null) throw businessError!;
      return billReference.id;
    } on SaleProductNotFoundException {
      rethrow;
    } on InsufficientStockException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BillRepositoryException(
        'Unable to complete sale: ${error.message ?? error.code}.',
      );
    }
  }

  Future<List<Bill>> getBills() async {
    try {
      final snapshot = await _billsCollection.get();
      return snapshot.docs.map(Bill.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw BillRepositoryException(
        'Unable to load bills: ${error.message ?? error.code}.',
      );
    }
  }

  Future<Bill> getBill(String billId) async {
    try {
      final snapshot = await _billsCollection.doc(billId).get();
      if (!snapshot.exists) throw BillNotFoundException(billId);
      return Bill.fromFirestore(snapshot);
    } on BillNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BillRepositoryException(
        'Unable to load bill: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> deleteBill(String billId) async {
    try {
      final billReference = _billsCollection.doc(billId);
      final snapshot = await billReference.get();
      if (!snapshot.exists) throw BillNotFoundException(billId);
      await billReference.delete();
    } on BillNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BillRepositoryException(
        'Unable to delete bill: ${error.message ?? error.code}.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _billsCollection {
    final user = _auth.currentUser;
    if (user == null) throw BillUnauthenticatedException();
    return _firestore.collection('users').doc(user.uid).collection('bills');
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    final user = _auth.currentUser;
    if (user == null) throw BillUnauthenticatedException();
    return _firestore.collection('users').doc(user.uid).collection('products');
  }

  void _validateBill(Bill bill) {
    if (bill.items.isEmpty) throw SaleValidationException('The bill is empty.');
    if (bill.customerName.trim().isEmpty) {
      throw SaleValidationException('Customer information is required.');
    }
    if (!const ['Cash', 'UPI', 'Card', 'Other'].contains(bill.paymentMethod)) {
      throw SaleValidationException('Select a valid payment method.');
    }
    if (bill.discount < 0 || bill.total < 0) {
      throw SaleValidationException('Discount and total must not be negative.');
    }
    for (final item in bill.items) {
      if (item.productId.isEmpty || item.quantity < 1) {
        throw SaleValidationException('Each product must have a valid quantity.');
      }
      if (item.sellingPrice < 0 ||
          item.purchasePrice < 0 ||
          item.discount < 0 ||
          item.lineTotal < 0) {
        throw SaleValidationException('Product prices and discounts are invalid.');
      }
    }
  }
}

class BillUnauthenticatedException implements Exception {
  BillUnauthenticatedException([
    this.message = 'You must be signed in to manage bills.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class BillNotFoundException implements Exception {
  BillNotFoundException(this.billId);

  final String billId;

  @override
  String toString() => 'Bill "$billId" was not found.';
}

class BillRepositoryException implements Exception {
  BillRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SaleValidationException implements Exception {
  SaleValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class SaleBusinessException implements Exception {
  String get message;

  @override
  String toString() => message;
}

class SaleProductNotFoundException extends SaleBusinessException {
  SaleProductNotFoundException(this.productName);

  final String productName;

  @override
  String get message => 'Product "$productName" is no longer available.';
}

class InsufficientStockException extends SaleBusinessException {
  InsufficientStockException({
    required this.productName,
    required this.available,
    required this.requested,
  });

  final String productName;
  final int available;
  final int requested;

  @override
  String get message =>
      'Insufficient stock for $productName. Available: $available, '
      'Requested: $requested.';
}