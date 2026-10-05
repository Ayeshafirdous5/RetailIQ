import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import 'create_bill_screen.dart';
import 'bill_details_screen.dart';

import '../../models/bill.dart';
import '../../repositories/bill_repository.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({this.billRepository, super.key});

  final BillRepository? billRepository;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late final BillRepository _billRepository;
  List<Bill> _bills = const [];
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _billRepository = widget.billRepository ?? BillRepository();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final bills = await _billRepository.getBills();
      bills
          .sort((first, second) => second.createdAt.compareTo(first.createdAt));
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _openNewBill() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateBillScreen(billRepository: _billRepository),
      ),
    );
    if (mounted) await _loadBills();
  }

  String _friendlyError(Object error) {
    if (error is BillUnauthenticatedException ||
        error is BillRepositoryException) {
      return error.toString();
    }
    return 'Unable to load billing history. Please try again.';
  }

  String _formatPrice(double value) => '₹${value.toStringAsFixed(2)}';

  String _formatDateTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date, $time';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          if (isMobile)
            IconButton.filledTonal(
              onPressed: _isLoading ? null : _openNewBill,
              icon: const Icon(Icons.add),
              tooltip: 'New bill',
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x12),
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _openNewBill,
                icon: const Icon(Icons.add),
                label: const Text('New bill'),
              ),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState();
    }
    if (_loadError != null) {
      return AppErrorState(
        message: _friendlyError(_loadError!),
        onRetry: _loadBills,
      );
    }
    if (_bills.isEmpty) {
      return _EmptyState(onNewBill: _openNewBill);
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView(
        padding: AppSpacing.pagePadding(
          AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width),
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent sales',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.x4),
                            Text(
                              'Completed billing transactions',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x12),
                      Text(
                        '${_bills.length} ${_bills.length == 1 ? 'bill' : 'bills'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  for (final bill in _bills) ...[
                    _BillCard(
                      bill: bill,
                      dateTime: _formatDateTime(context, bill.createdAt),
                      formatPrice: _formatPrice,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => BillDetailsScreen(
                            billId: bill.id,
                            billRepository: _billRepository,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x8),
                  ],
                  const SizedBox(height: AppSpacing.x4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _openNewBill,
                      icon: const Icon(Icons.add),
                      label: const Text('New bill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.dateTime,
    required this.formatPrice,
    required this.onTap,
  });

  final Bill bill;
  final String dateTime;
  final String Function(double) formatPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      bill.billNumber.isEmpty ? 'Bill' : bill.billNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  Flexible(
                    child: Text(
                      formatPrice(bill.total),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: secondaryColor),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                    child: Text(
                      bill.customerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.x12,
                runSpacing: AppSpacing.x8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 16, color: secondaryColor),
                      const SizedBox(width: AppSpacing.x4),
                      Text(
                        dateTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  _PaymentMethodTag(method: bill.paymentMethod),
                  Text(
                    '${bill.items.length} ${bill.items.length == 1 ? 'item' : 'items'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTag extends StatelessWidget {
  const _PaymentMethodTag({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x8,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined, size: 14, color: AppTheme.teal),
          const SizedBox(width: AppSpacing.x4),
          Text(method, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewBill});

  final VoidCallback onNewBill;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x20),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppTheme.teal,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  Text(
                    'No bills yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  Text(
                    'Create a bill from your real inventory products when you are ready to make a sale.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.secondaryText,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  FilledButton.icon(
                    onPressed: onNewBill,
                    icon: const Icon(Icons.add),
                    label: const Text('New bill'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
