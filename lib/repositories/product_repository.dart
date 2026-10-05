import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';

class ProductRepository {
  ProductRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> addProduct(Product product) async {
    final products = _productsCollection;
    final productReference = products.doc();

    try {
      await productReference.set({
        ...product.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return productReference.id;
    } on FirebaseException catch (error) {
      throw ProductRepositoryException(
        'Unable to add product: ${error.message ?? error.code}.',
      );
    }
  }

  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _productsCollection.get();
      return snapshot.docs.map(Product.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw ProductRepositoryException(
        'Unable to load products: ${error.message ?? error.code}.',
      );
    }
  }

  Future<Product> getProduct(String productId) async {
    try {
      final snapshot = await _productsCollection.doc(productId).get();
      if (!snapshot.exists) {
        throw ProductNotFoundException(productId);
      }
      return Product.fromFirestore(snapshot);
    } on ProductNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ProductRepositoryException(
        'Unable to load product: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> updateProduct(Product product) async {
    if (product.id.isEmpty) {
      throw ArgumentError.value(product.id, 'product.id', 'cannot be empty');
    }

    try {
      await _productsCollection.doc(product.id).update({
        ...product.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      }..remove('createdAt'));
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw ProductNotFoundException(product.id);
      }
      throw ProductRepositoryException(
        'Unable to update product: ${error.message ?? error.code}.',
      );
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final productReference = _productsCollection.doc(productId);
      final snapshot = await productReference.get();
      if (!snapshot.exists) {
        throw ProductNotFoundException(productId);
      }
      await productReference.delete();
    } on ProductNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ProductRepositoryException(
        'Unable to delete product: ${error.message ?? error.code}.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    final user = _auth.currentUser;
    if (user == null) {
      throw UnauthenticatedException();
    }
    return _firestore.collection('users').doc(user.uid).collection('products');
  }
}

class UnauthenticatedException implements Exception {
  UnauthenticatedException([
    this.message = 'You must be signed in to manage products.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ProductNotFoundException implements Exception {
  ProductNotFoundException(this.productId);

  final String productId;

  @override
  String toString() => 'Product "$productId" was not found.';
}

class ProductRepositoryException implements Exception {
  ProductRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}