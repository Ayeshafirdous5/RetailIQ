import 'package:firebase_auth/firebase_auth.dart';

import '../models/analytics_date_filter.dart';
import '../models/analytics_summary.dart';
import '../models/bill.dart';
import 'bill_repository.dart';

class AnalyticsRepository {
  AnalyticsRepository({
    BillRepository? billRepository,
    FirebaseAuth? auth,
  })  : _billRepository = billRepository ?? BillRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  final BillRepository _billRepository;
  final FirebaseAuth _auth;

  Future<AnalyticsSummary> getSummary({
    AnalyticsDateFilter? dateFilter,
  }) async {
    if (_auth.currentUser == null) {
      throw AnalyticsUnauthenticatedException();
    }

    try {
      final bills = await _billRepository.getBills();
      final filteredBills = filterBills(
        bills,
        dateFilter ?? const AnalyticsDateFilter.allTime(),
      );
      return AnalyticsSummary.fromBills(filteredBills);
    } on AnalyticsRepositoryException {
      rethrow;
    } on BillUnauthenticatedException {
      throw AnalyticsUnauthenticatedException();
    } on BillRepositoryException catch (error) {
      throw AnalyticsRepositoryException(error.message);
    } catch (_) {
      throw AnalyticsRepositoryException(
        'Unable to load analytics data. Please try again.',
      );
    }
  }

  static List<Bill> filterBills(
    Iterable<Bill> bills,
    AnalyticsDateFilter dateFilter, {
    DateTime? now,
  }) {
    final range = dateFilter.resolve(now);
    if (range.isAllTime) return bills.toList(growable: false);
    return bills
        .where((bill) => range.contains(bill.createdAt))
        .toList(growable: false);
  }
}

class AnalyticsUnauthenticatedException implements Exception {
  AnalyticsUnauthenticatedException([
    this.message = 'You must be signed in to view analytics.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AnalyticsRepositoryException implements Exception {
  AnalyticsRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
