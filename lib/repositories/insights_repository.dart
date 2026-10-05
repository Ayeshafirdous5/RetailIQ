import 'package:firebase_auth/firebase_auth.dart';

import '../models/analytics_date_filter.dart';
import '../models/bill.dart';
import '../models/insights_summary.dart';
import '../models/product.dart';
import 'bill_repository.dart';
import 'product_repository.dart';

class InsightsRepository {
  InsightsRepository({
    BillRepository? billRepository,
    ProductRepository? productRepository,
    FirebaseAuth? auth,
  })  : _billRepository = billRepository ?? BillRepository(),
        _productRepository = productRepository ?? ProductRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  final BillRepository _billRepository;
  final ProductRepository _productRepository;
  final FirebaseAuth _auth;

  Future<InsightsSummary> getSummary({
    AnalyticsDateFilter? dateFilter,
  }) async {
    if (_auth.currentUser == null) {
      throw InsightsUnauthenticatedException();
    }

    try {
      final results = await Future.wait<Object>([
        _billRepository.getBills(),
        _productRepository.getProducts(),
      ]);
      return InsightsSummary.fromData(
        bills: results[0] as List<Bill>,
        products: results[1] as List<Product>,
        dateFilter: dateFilter,
      );
    } on InsightsRepositoryException {
      rethrow;
    } on BillUnauthenticatedException {
      throw InsightsUnauthenticatedException();
    } on UnauthenticatedException {
      throw InsightsUnauthenticatedException();
    } on ProductRepositoryException catch (error) {
      throw InsightsRepositoryException(error.message);
    } on BillRepositoryException catch (error) {
      throw InsightsRepositoryException(error.message);
    } catch (_) {
      throw InsightsRepositoryException(
        'Unable to load insights data. Please try again.',
      );
    }
  }
}

class InsightsUnauthenticatedException implements Exception {
  InsightsUnauthenticatedException([
    this.message = 'You must be signed in to view insights.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class InsightsRepositoryException implements Exception {
  InsightsRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
