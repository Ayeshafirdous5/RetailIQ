import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/supplier.dart';

class SupplierRepository {
  SupplierRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> addSupplier(Supplier supplier) async {
    final supplierReference = _suppliersCollection.doc();
    try {
      await supplierReference.set({
        ...supplier.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return supplierReference.id;
    } on FirebaseException catch (error) {
      throw SupplierRepositoryException(
        'Unable to add supplier: ${error.message ?? error.code}.',
      );
    }
  }

  Future<List<Supplier>> getSuppliers() async {
    try {
      final snapshot = await _suppliersCollection.get();
      return snapshot.docs.map(Supplier.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw SupplierRepositoryException(
        'Unable to load suppliers: ${error.message ?? error.code}.',
      );
    }
  }

  Future<Supplier> getSupplier(String supplierId) async {
    try {
      final snapshot = await _suppliersCollection.doc(supplierId).get();
      if (!snapshot.exists) throw SupplierNotFoundException(supplierId);
      return Supplier.fromFirestore(snapshot);
    } on SupplierNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw SupplierRepositoryException(
        'Unable to load supplier: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    if (supplier.id.isEmpty) {
      throw ArgumentError.value(supplier.id, 'supplier.id', 'cannot be empty');
    }
    try {
      await _suppliersCollection.doc(supplier.id).update({
        ...supplier.toMap()..remove('createdAt'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw SupplierNotFoundException(supplier.id);
      }
      throw SupplierRepositoryException(
        'Unable to update supplier: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    try {
      final supplierReference = _suppliersCollection.doc(supplierId);
      final snapshot = await supplierReference.get();
      if (!snapshot.exists) throw SupplierNotFoundException(supplierId);
      await supplierReference.delete();
    } on SupplierNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw SupplierRepositoryException(
        'Unable to delete supplier: ${error.message ?? error.code}.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _suppliersCollection {
    final user = _auth.currentUser;
    if (user == null) throw SupplierUnauthenticatedException();
    return _firestore.collection('users').doc(user.uid).collection('suppliers');
  }
}

class SupplierUnauthenticatedException implements Exception {
  SupplierUnauthenticatedException([
    this.message = 'You must be signed in to manage suppliers.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class SupplierNotFoundException implements Exception {
  SupplierNotFoundException(this.supplierId);

  final String supplierId;

  @override
  String toString() => 'Supplier "$supplierId" was not found.';
}

class SupplierRepositoryException implements Exception {
  SupplierRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}