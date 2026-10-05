import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bill.dart';
import '../../repositories/bill_repository.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.bill,
    this.billRepository,
    super.key,
  });

  final Bill bill;
  final BillRepository? billRepository;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final BillRepository _billRepository;
  bool _isSaving = false;
  Bill? _savedBill;
  String? _savedDocumentId;
  String? _saveError;

  Bill get bill => widget.bill;

  @override
  void initState() {
    super.initState();
    _billRepository = widget.billRepository ?? BillRepository();
  }

  bool get _isValid {
    if (bill.items.isEmpty || bill.customerName.trim().isEmpty) return false;
    if (!const ['Cash', 'UPI', 'Card', 'Other'].contains(bill.paymentMethod)) {
      return false;
    }
    if (bill.discount < 0 || bill.total < 0) return false;
    return bill.items.every(
      (item) =>
          item.quantity >= 1 &&
          item.sellingPrice >= 0 &&
          item.purchasePrice >= 0 &&
          item.discount >= 0 &&
          item.lineTotal >= 0,
    );
  }

  String _finalBillNumber(DateTime confirmedAt) {
    String pad(int value, [int width = 2]) =>
        value.toString().padLeft(width, '0');
    return 'INV-${confirmedAt.year}${pad(confirmedAt.month)}'
        '${pad(confirmedAt.day)}-${pad(confirmedAt.hour)}'
        '${pad(confirmedAt.minute)}${pad(confirmedAt.second)}'
        '${pad(confirmedAt.millisecond, 3)}';
  }

  Future<void> _confirmSale() async {
    if (_isSaving || _savedBill != null) return;
    if (!_isValid) {
      setState(() =>
          _saveError = 'Check the bill items, customer, payment, and totals.');
      return;
    }

    final confirmedAt = DateTime.now();
    final finalBill = bill.copyWith(
      billNumber: _finalBillNumber(confirmedAt),
      createdAt: confirmedAt,
    );
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final documentId = await _billRepository.completeSale(finalBill);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _savedBill = finalBill;
        _savedDocumentId = documentId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is SaleProductNotFoundException) {
      return error.toString();
    }
    if (error is InsufficientStockException) {
      return error.toString();
    }
    if (error is BillUnauthenticatedException ||
        error is BillRepositoryException ||
        error is SaleValidationException) {
      return error.toString();
    }
    return 'Unable to save the sale. Please try again.';
  }

  String _formatPrice(double value) => '₹${value.toStringAsFixed(2)}';

  void _editBill() {
    if (_isSaving) return;
    Navigator.of(context).pop(bill);
  }

  Widget _buildSuccessState(BuildContext context, Bill savedBill) {
    final isMobile =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile;
    return Scaffold(
      appBar: AppBar(title: const Text('Sale completed')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.pagePadding(
              AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    isMobile ? AppSpacing.x16 : AppSpacing.x24,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 56,
                        color: AppTheme.success,
                      ),
                      const SizedBox(height: AppSpacing.x12),
                      Text(
                        'Sale completed',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.x16),
                      _DetailRow(
                        label: 'Bill number',
                        value: savedBill.billNumber,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Total',
                        value: _formatPrice(savedBill.total),
                        prominent: true,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Payment',
                        value: savedBill.paymentMethod,
                      ),
                      const SizedBox(height: 12),
                      const Text('Transaction saved successfully.'),
                      const SizedBox(height: 8),
                      const Text('Inventory updated.'),
                      if (_savedDocumentId != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Document ID: $_savedDocumentId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_savedBill != null) {
      return _buildSuccessState(context, _savedBill!);
    }

    final layoutSize =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
    final isMobile = layoutSize == AppLayoutSize.mobile;
    final sectionGap = isMobile ? AppSpacing.x12 : AppSpacing.x16;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout review'),
        leading: IconButton(
          onPressed: _isSaving ? null : _editBill,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Edit bill',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding(layoutSize),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReviewCard(
                    title: 'Customer',
                    icon: Icons.person_outline,
                    child: Text(
                      bill.customerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _ReviewCard(
                    title: 'Bill details',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _DetailRow(label: 'Reference', value: bill.billNumber),
                        const SizedBox(height: 14),
                        for (var index = 0; index < bill.items.length; index++)
                          _ReviewItem(
                            item: bill.items[index],
                            formatPrice: _formatPrice,
                            isLast: index == bill.items.length - 1,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _ReviewCard(
                    title: 'Payment',
                    icon: Icons.payments_outlined,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x12,
                        vertical: AppSpacing.x8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppTheme.teal,
                          ),
                          const SizedBox(width: AppSpacing.x8),
                          Text(
                            bill.paymentMethod,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _ReviewCard(
                    title: 'Summary',
                    icon: Icons.calculate_outlined,
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Subtotal',
                          value: _formatPrice(bill.subtotal),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Bill discount',
                          value: _formatPrice(bill.discount),
                        ),
                        const Divider(height: 28),
                        _DetailRow(
                          label: 'Total',
                          value: _formatPrice(bill.total),
                          prominent: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _confirmSale,
                          icon: const Icon(Icons.check_circle_outline),
                          label: _isSaving
                              ? const Text('Saving...')
                              : const Text('Confirm sale'),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _editBill,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit bill'),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.x12,
                        runSpacing: AppSpacing.x8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _editBill,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit bill'),
                          ),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _confirmSale,
                            icon: const Icon(Icons.check_circle_outline),
                            label: _isSaving
                                ? const Text('Saving...')
                                : const Text('Confirm sale'),
                          ),
                        ],
                      ),
                    ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _saveError!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.x12 : AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: AppSpacing.x8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.item,
    required this.formatPrice,
    required this.isLast,
  });

  final BillItem item;
  final String Function(double) formatPrice;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName,
                style: Theme.of(context).textTheme.titleSmall),
            Text(
              'SKU: ${item.sku} · Qty: ${item.quantity}',
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
            Text(
              'Selling: ${formatPrice(item.sellingPrice)} · '
              'Item discount: ${formatPrice(item.discount)}',
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
          ],
        );
        final lineTotal = Text(
          formatPrice(item.lineTotal),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
        );
        return Column(
          children: [
            if (constraints.maxWidth < 560)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.x8),
                  Flexible(child: lineTotal),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.x16),
                  SizedBox(width: 96, child: lineTotal),
                ],
              ),
            if (!isLast) const Divider(height: AppSpacing.x24),
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final style = prominent
        ? Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              color: AppTheme.navy,
            )
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child:
              Text(label, style: style?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.x12),
        Flexible(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: prominent ? AppTheme.teal : null,
            ),
          ),
        ),
      ],
    );
  }
}
