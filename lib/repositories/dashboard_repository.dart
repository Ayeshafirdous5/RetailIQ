import '../models/dashboard_summary.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import 'bill_repository.dart';
import 'product_repository.dart';
import 'purchase_repository.dart';

class DashboardRepository {
  DashboardRepository({
    BillRepository? billRepository,
    ProductRepository? productRepository,
    PurchaseRepository? purchaseRepository,
  })  : _billRepository = billRepository ?? BillRepository(),
        _productRepository = productRepository ?? ProductRepository(),
        _purchaseRepository = purchaseRepository ?? PurchaseRepository();

  final BillRepository _billRepository;
  final ProductRepository _productRepository;
  final PurchaseRepository _purchaseRepository;

  Future<DashboardSummary> getSummary() async {
    try {
      final results = await Future.wait<Object>([
        _billRepository.getBills(),
        _purchaseRepository.getPurchases(),
        _productRepository.getProducts(),
      ]);
      return DashboardSummary.fromData(
        bills: results[0] as List<Bill>,
        purchases: results[1] as List<Purchase>,
        products: results[2] as List<Product>,
      );
    } on DashboardRepositoryException {
      rethrow;
    } catch (error) {
      if (error is BillUnauthenticatedException ||
          error is BillRepositoryException ||
          error is PurchaseUnauthenticatedException ||
          error is PurchaseRepositoryException ||
          error is UnauthenticatedException ||
          error is ProductRepositoryException) {
        throw DashboardRepositoryException(error.toString());
      }
      throw DashboardRepositoryException(
        'Unable to load dashboard data. Please try again.',
      );
    }
  }
}

class DashboardRepositoryException implements Exception {
  DashboardRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}