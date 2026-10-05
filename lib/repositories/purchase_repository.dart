import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/purchase.dart';

class PurchaseRepository {
  PurchaseRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> addPurchase(Purchase purchase) async {
    final purchaseReference = _purchasesCollection.doc();
    try {
      await purchaseReference.set({
        ...purchase.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return purchaseReference.id;
    } on FirebaseException catch (error) {
      throw PurchaseRepositoryException(
        'Unable to add purchase: ${error.message ?? error.code}.',
      );
    }
  }

  Future<String> completePurchase(Purchase purchase) async {
    final purchases = _purchasesCollection;
    _validatePurchase(purchase);
    final purchaseReference = purchases.doc();
    final quantitiesByProductId = <String, int>{};
    for (final item in purchase.items) {
      quantitiesByProductId.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    PurchaseBusinessException? businessError;
    try {
      await _firestore.runTransaction((transaction) async {
        try {
          final productReferences = quantitiesByProductId.keys
              .map((productId) => _productsCollection.doc(productId))
              .toList(growable: false);
          final productSnapshots =
              <String, DocumentSnapshot<Map<String, dynamic>>>{};
          for (final reference in productReferences) {
            final snapshot = await transaction.get(reference);
            productSnapshots[reference.id] = snapshot;
          }

          final stockUpdates = <DocumentReference<Map<String, dynamic>>, int>{};
          for (final entry in quantitiesByProductId.entries) {
            final snapshot = productSnapshots[entry.key];
            if (snapshot == null || !snapshot.exists) {
              throw PurchaseProductNotFoundException();
            }
            final data = snapshot.data();
            final rawStock = data?['stockQuantity'];
            if (rawStock is! num ||
                !rawStock.isFinite ||
                rawStock != rawStock.toInt() ||
                rawStock < 0) {
              throw InvalidProductStockException(entry.key);
            }
            final currentStock = rawStock.toInt();
            stockUpdates[_productsCollection.doc(entry.key)] =
                currentStock + entry.value;
          }

          transaction.set(purchaseReference, {
            ...purchase.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          for (final entry in stockUpdates.entries) {
            transaction.update(entry.key, {
              'stockQuantity': entry.value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } on PurchaseBusinessException catch (error) {
          businessError = error;
        }
      });
      if (businessError != null) throw businessError!;
      return purchaseReference.id;
    } on PurchaseBusinessException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PurchaseRepositoryException(
        'Unable to complete purchase: ${error.message ?? error.code}.',
      );
    }
  }

  Future<List<Purchase>> getPurchases() async {
    try {
      final snapshot = await _purchasesCollection.get();
      return snapshot.docs.map(Purchase.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw PurchaseRepositoryException(
        'Unable to load purchases: ${error.message ?? error.code}.',
      );
    }
  }

  Future<Purchase> getPurchase(String purchaseId) async {
    try {
      final snapshot = await _purchasesCollection.doc(purchaseId).get();
      if (!snapshot.exists) throw PurchaseNotFoundException(purchaseId);
      return Purchase.fromFirestore(snapshot);
    } on PurchaseNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PurchaseRepositoryException(
        'Unable to load purchase: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    try {
      final purchaseReference = _purchasesCollection.doc(purchaseId);
      final snapshot = await purchaseReference.get();
      if (!snapshot.exists) throw PurchaseNotFoundException(purchaseId);
      await purchaseReference.delete();
    } on PurchaseNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PurchaseRepositoryException(
        'Unable to delete purchase: ${error.message ?? error.code}.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _purchasesCollection {
    final user = _auth.currentUser;
    if (user == null) throw PurchaseUnauthenticatedException();
    return _firestore.collection('users').doc(user.uid).collection('purchases');
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    final user = _auth.currentUser;
    if (user == null) throw PurchaseUnauthenticatedException();
    return _firestore.collection('users').doc(user.uid).collection('products');
  }

  void _validatePurchase(Purchase purchase) {
    if (purchase.items.isEmpty) {
      throw PurchaseValidationException('The purchase is empty.');
    }
    if (purchase.supplierId.trim().isEmpty ||
        purchase.supplierName.trim().isEmpty) {
      throw PurchaseValidationException('Supplier information is required.');
    }
    if (purchase.purchaseNumber.trim().isEmpty ||
        !purchase.totalAmount.isFinite ||
        purchase.totalAmount < 0) {
      throw PurchaseValidationException('Purchase details are invalid.');
    }
    for (final item in purchase.items) {
      if (item.productId.trim().isEmpty || item.quantity < 1) {
        throw PurchaseValidationException(
          'Each product must have a positive quantity.',
        );
      }
      if (!item.purchasePrice.isFinite ||
          item.purchasePrice < 0 ||
          !item.lineTotal.isFinite ||
          item.lineTotal < 0) {
        throw PurchaseValidationException(
          'Purchase prices and totals are invalid.',
        );
      }
    }
  }
}

class PurchaseUnauthenticatedException implements Exception {
  PurchaseUnauthenticatedException([
    this.message = 'You must be signed in to manage purchases.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class PurchaseNotFoundException implements Exception {
  PurchaseNotFoundException(this.purchaseId);

  final String purchaseId;

  @override
  String toString() => 'Purchase "$purchaseId" was not found.';
}

class PurchaseRepositoryException implements Exception {
  PurchaseRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PurchaseValidationException implements Exception {
  PurchaseValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PurchaseBusinessException implements Exception {
  String get message;

  @override
  String toString() => message;
}

class PurchaseProductNotFoundException extends PurchaseBusinessException {
  @override
  String get message =>
      'Product no longer exists. Please review the purchase and try again.';
}

class InvalidProductStockException extends PurchaseBusinessException {
  InvalidProductStockException(this.productId);

  final String productId;

  @override
  String get message =>
      'Product stock is invalid. Please review the product and try again.';
}
