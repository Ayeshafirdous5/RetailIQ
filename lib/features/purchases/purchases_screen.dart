import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/purchase.dart';
import '../../repositories/purchase_repository.dart';
import 'create_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({this.repository, super.key});

  final PurchaseRepository? repository;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final PurchaseRepository _repository;
  List<Purchase> _purchases = const [];
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PurchaseRepository();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final purchases = await _repository.getPurchases();
      purchases
          .sort((left, right) => right.createdAt.compareTo(left.createdAt));
      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is PurchaseUnauthenticatedException ||
        error is PurchaseRepositoryException) {
      return error.toString();
    }
    return 'Unable to load purchases. Please try again.';
  }

  Future<void> _openCreatePurchase() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreatePurchaseScreen(purchaseRepository: _repository),
      ),
    );
    if (!mounted || saved != true) return;
    await _loadPurchases();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase saved successfully.')),
    );
  }

  Widget _content() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
              height: 320, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: _PurchaseStateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load purchases',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onAction: _loadPurchases,
            ),
          ),
        ],
      );
    }
    if (_purchases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 480,
            child: _PurchaseStateMessage(
              icon: Icons.local_shipping_outlined,
              title: 'No purchases yet',
              message: 'Record your first supplier purchase to see it here.',
              actionLabel: 'New purchase',
              onAction: _openCreatePurchase,
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding(layout).copyWith(
            top: AppSpacing.x8,
            bottom: AppSpacing.x32,
          ),
          itemCount: _purchases.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? AppSpacing.x16 : AppSpacing.x12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _PurchasesHeader(
                purchaseCount: _purchases.length,
                onNewPurchase: _openCreatePurchase,
              );
            }
            final purchase = _purchases[index - 1];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _PurchaseCard(purchase: purchase),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPurchases,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh purchases',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPurchases,
        child: _content(),
      ),
    );
  }
}

class _PurchasesHeader extends StatelessWidget {
  const _PurchasesHeader(
      {required this.purchaseCount, required this.onNewPurchase});

  final int purchaseCount;
  final VoidCallback onNewPurchase;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchases',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    '$purchaseCount ${purchaseCount == 1 ? 'purchase' : 'purchases'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x16),
            FilledButton.icon(
              onPressed: onNewPurchase,
              icon: const Icon(Icons.add_outlined),
              label: const Text('New purchase'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final date =
        MaterialLocalizations.of(context).formatMediumDate(purchase.createdAt);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(purchase.createdAt));
    final quantity =
        purchase.items.fold<int>(0, (total, item) => total + item.quantity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    purchase.purchaseNumber,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x12,
                    vertical: AppSpacing.x8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₹${purchase.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              purchase.supplierName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.x16),
            Wrap(
              spacing: AppSpacing.x24,
              runSpacing: AppSpacing.x12,
              children: [
                _PurchaseInfo(label: 'Date', value: '$date, $time'),
                _PurchaseInfo(
                  label: 'Products',
                  value: '${purchase.items.length}',
                ),
                _PurchaseInfo(label: 'Total quantity', value: '$quantity'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseInfo extends StatelessWidget {
  const _PurchaseInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _PurchaseStateMessage extends StatelessWidget {
  const _PurchaseStateMessage(
      {required this.icon,
      required this.title,
      required this.message,
      required this.actionLabel,
      required this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: AppTheme.teal),
              const SizedBox(height: AppSpacing.x16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x20),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  actionLabel == 'Try again' ? Icons.refresh : Icons.add,
                ),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      );
}
