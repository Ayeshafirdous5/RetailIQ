import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../models/bill.dart';
import '../../repositories/bill_repository.dart';
import '../../services/bill_pdf_service.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({
    required this.billId,
    this.billRepository,
    super.key,
  });

  final String billId;
  final BillRepository? billRepository;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  late final BillRepository _billRepository;
  Bill? _bill;
  Object? _loadError;
  bool _isInvoiceActionRunning = false;

  @override
  void initState() {
    super.initState();
    _billRepository = widget.billRepository ?? BillRepository();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final bill = await _billRepository.getBill(widget.billId);
      if (!mounted) return;
      setState(() => _bill = bill);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  String _formatPrice(double value) => '₹${value.toStringAsFixed(2)}';

  String _invoiceFilename(Bill bill) {
    final billNumber =
        bill.billNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${billNumber.isEmpty ? 'invoice' : billNumber}.pdf';
  }

  Future<void> _runInvoiceAction({
    required String errorMessage,
    required Future<void> Function(Bill bill, Uint8List bytes) action,
  }) async {
    final bill = _bill;
    if (bill == null || _isInvoiceActionRunning) return;

    setState(() => _isInvoiceActionRunning = true);
    try {
      final bytes = await BillPdfService.generate(bill);
      if (!mounted) return;
      await action(bill, bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _isInvoiceActionRunning = false);
    }
  }

  Future<void> _previewInvoice() => _runInvoiceAction(
        errorMessage:
            'Unable to prepare the invoice preview. Please try again.',
        action: (bill, bytes) async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Invoice preview')),
                body: PdfPreview(
                  build: (_) async => bytes,
                  pdfFileName: _invoiceFilename(bill),
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                ),
              ),
            ),
          );
        },
      );

  Future<void> _printInvoice() => _runInvoiceAction(
        errorMessage: 'Unable to print the invoice. Please try again.',
        action: (bill, bytes) async {
          await Printing.layoutPdf(
            name: _invoiceFilename(bill),
            onLayout: (_) async => bytes,
          );
        },
      );

  Future<void> _shareInvoice() => _runInvoiceAction(
        errorMessage: 'Unable to share the invoice. Please try again.',
        action: (bill, bytes) async {
          await Printing.sharePdf(
            bytes: bytes,
            filename: _invoiceFilename(bill),
          );
        },
      );

  String _formatDateTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  String _errorMessage(Object error) {
    if (error is BillNotFoundException) {
      return 'This bill is no longer available.';
    }
    if (error is BillUnauthenticatedException ||
        error is BillRepositoryException) {
      return error.toString();
    }
    return 'Unable to load this bill. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill details'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_bill == null && _loadError == null) {
      return const AppLoadingState();
    }
    if (_loadError != null) {
      final isMissing = _loadError is BillNotFoundException;
      return _DetailsState(
        icon:
            isMissing ? Icons.receipt_long_outlined : Icons.cloud_off_outlined,
        title: isMissing ? 'Bill not found' : 'Could not load bill',
        message: _errorMessage(_loadError!),
        onRetry: isMissing ? null : _loadBill,
      );
    }

    return _InvoiceView(
      bill: _bill!,
      dateTime: _formatDateTime(context, _bill!.createdAt),
      formatPrice: _formatPrice,
      isInvoiceActionRunning: _isInvoiceActionRunning,
      onPreviewInvoice: _previewInvoice,
      onPrintInvoice: _printInvoice,
      onShareInvoice: _shareInvoice,
    );
  }
}

class _InvoiceView extends StatelessWidget {
  const _InvoiceView({
    required this.bill,
    required this.dateTime,
    required this.formatPrice,
    required this.isInvoiceActionRunning,
    required this.onPreviewInvoice,
    required this.onPrintInvoice,
    required this.onShareInvoice,
  });

  final Bill bill;
  final String dateTime;
  final String Function(double) formatPrice;
  final bool isInvoiceActionRunning;
  final VoidCallback onPreviewInvoice;
  final VoidCallback onPrintInvoice;
  final VoidCallback onShareInvoice;

  @override
  Widget build(BuildContext context) {
    final layoutSize =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
    final isMobile = layoutSize == AppLayoutSize.mobile;
    final sectionGap = isMobile ? AppSpacing.x12 : AppSpacing.x16;
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding(layoutSize),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile)
                Row(
                  children: [
                    Expanded(
                      child: _InvoiceActionButton(
                        label: 'Preview Invoice',
                        icon: Icons.preview_outlined,
                        compact: true,
                        onPressed:
                            isInvoiceActionRunning ? null : onPreviewInvoice,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: _InvoiceActionButton(
                        label: 'Print Invoice',
                        icon: Icons.print_outlined,
                        compact: true,
                        onPressed:
                            isInvoiceActionRunning ? null : onPrintInvoice,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: _InvoiceActionButton(
                        label: 'Share Invoice',
                        icon: Icons.share_outlined,
                        compact: true,
                        onPressed:
                            isInvoiceActionRunning ? null : onShareInvoice,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: AppSpacing.x8,
                  runSpacing: AppSpacing.x8,
                  children: [
                    _InvoiceActionButton(
                      label: 'Preview Invoice',
                      icon: Icons.preview_outlined,
                      onPressed:
                          isInvoiceActionRunning ? null : onPreviewInvoice,
                    ),
                    _InvoiceActionButton(
                      label: 'Print Invoice',
                      icon: Icons.print_outlined,
                      onPressed: isInvoiceActionRunning ? null : onPrintInvoice,
                    ),
                    _InvoiceActionButton(
                      label: 'Share Invoice',
                      icon: Icons.share_outlined,
                      onPressed: isInvoiceActionRunning ? null : onShareInvoice,
                    ),
                  ],
                ),
              SizedBox(height: sectionGap),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: AppTheme.teal,
                        ),
                        const SizedBox(width: AppSpacing.x8),
                        Expanded(
                          child: Text(
                            'RetailIQ',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          'INVOICE',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    _InfoRow(label: 'Invoice number', value: bill.billNumber),
                    const SizedBox(height: AppSpacing.x8),
                    _InfoRow(label: 'Date and time', value: dateTime),
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Customer',
                child: _InfoRow(
                  label: 'Customer name',
                  value: bill.customerId == null
                      ? 'Walk-in Customer'
                      : bill.customerName,
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Items',
                child: Column(
                  children: [
                    for (var index = 0; index < bill.items.length; index++) ...[
                      _ItemRow(
                        item: bill.items[index],
                        formatPrice: formatPrice,
                      ),
                      if (index != bill.items.length - 1)
                        const Divider(height: AppSpacing.x24),
                    ],
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Summary',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Subtotal',
                      value: formatPrice(bill.subtotal),
                    ),
                    const SizedBox(height: AppSpacing.x8),
                    _InfoRow(
                      label: 'Total discount',
                      value: formatPrice(bill.discount),
                    ),
                    const Divider(height: AppSpacing.x24),
                    _InfoRow(
                      label: 'Total amount',
                      value: formatPrice(bill.total),
                      prominent: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              _SectionCard(
                title: 'Payment',
                child: _InfoRow(
                  label: 'Payment method',
                  value: bill.paymentMethod,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceActionButton extends StatelessWidget {
  const _InvoiceActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: compact
          ? OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x8,
              ),
            )
          : null,
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                  softWrap: true,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.x8),
                Text(label),
              ],
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.formatPrice});

  final BillItem item;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) {
    final details = [
      'SKU: ${item.sku.isEmpty ? 'Not available' : item.sku}',
      'Qty: ${item.quantity}',
      'Selling price: ${formatPrice(item.sellingPrice)}',
      if (item.discount > 0) 'Item discount: ${formatPrice(item.discount)}',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final description = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.x4),
            Text(
              details.join('  ·  '),
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: description),
            if (constraints.maxWidth < 560)
              Flexible(child: lineTotal)
            else
              SizedBox(width: 96, child: lineTotal),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});

  final String? title;
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
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.x12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: AppSpacing.x12),
        Flexible(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: prominent
                ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal,
                    )
                : null,
          ),
        ),
      ],
    );
  }
}

class _DetailsState extends StatelessWidget {
  const _DetailsState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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
