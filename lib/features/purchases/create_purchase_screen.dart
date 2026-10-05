import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../repositories/supplier_repository.dart';

class CreatePurchaseScreen extends StatefulWidget {
  const CreatePurchaseScreen({
    this.purchaseRepository,
    this.productRepository,
    this.supplierRepository,
    super.key,
  });

  final PurchaseRepository? purchaseRepository;
  final ProductRepository? productRepository;
  final SupplierRepository? supplierRepository;

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  late final PurchaseRepository _purchaseRepository;
  late final ProductRepository _productRepository;
  late final SupplierRepository _supplierRepository;
  List<Supplier> _suppliers = const [];
  List<Product> _products = const [];
  final List<_DraftPurchaseItem> _items = [];
  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  String? _supplierError;
  String? _productError;
  Purchase? _savedPurchase;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _purchaseRepository = widget.purchaseRepository ?? PurchaseRepository();
    _productRepository = widget.productRepository ?? ProductRepository();
    _supplierRepository = widget.supplierRepository ?? SupplierRepository();
    _loadOptions();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.priceController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    if (mounted) setState(() => _isLoading = true);
    final results = await Future.wait<Object>([
      _supplierRepository
          .getSuppliers()
          .then<Object>((value) => value)
          .catchError((error) => error),
      _productRepository
          .getProducts()
          .then<Object>((value) => value)
          .catchError((error) => error),
    ]);
    if (!mounted) return;
    final suppliersResult = results[0];
    final productsResult = results[1];
    setState(() {
      _supplierError = suppliersResult is List<Supplier>
          ? null
          : _friendlySupplierError(suppliersResult);
      _productError = productsResult is List<Product>
          ? null
          : _friendlyProductError(productsResult);
      _suppliers =
          suppliersResult is List<Supplier> ? suppliersResult : const [];
      _products = productsResult is List<Product> ? productsResult : const [];
      _isLoading = false;
    });
  }

  String _friendlySupplierError(Object error) {
    if (error is SupplierUnauthenticatedException ||
        error is SupplierRepositoryException) {
      return error.toString();
    }
    return 'Unable to load suppliers. Please try again.';
  }

  String _friendlyProductError(Object error) {
    if (error is UnauthenticatedException ||
        error is ProductRepositoryException) {
      return error.toString();
    }
    return 'Unable to load products. Please try again.';
  }

  void _selectProduct(Product? product) {
    if (product == null) return;
    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);
    setState(() {
      if (existingIndex >= 0) {
        _items[existingIndex].quantity++;
        _selectedProduct = null;
      } else {
        _items.add(_DraftPurchaseItem(product));
        _selectedProduct = null;
      }
    });
  }

  void _removeItem(_DraftPurchaseItem item) {
    setState(() {
      _items.remove(item);
      item.priceController.dispose();
    });
  }

  double? _priceFor(_DraftPurchaseItem item) {
    final price = double.tryParse(item.priceController.text.trim());
    if (price == null || !price.isFinite || price < 0) return null;
    return price;
  }

  List<PurchaseItem>? _validatedItems() {
    if (_items.isEmpty) return null;
    final result = <PurchaseItem>[];
    for (final item in _items) {
      final price = _priceFor(item);
      if (item.quantity < 1 || price == null) return null;
      result.add(PurchaseItem(
        productId: item.product.id,
        productName: item.product.name,
        sku: item.product.sku,
        quantity: item.quantity,
        purchasePrice: price,
      ));
    }
    return result;
  }

  Purchase? _draftPurchase() {
    final items = _validatedItems();
    if (_selectedSupplier == null || items == null) return null;
    return Purchase(
      id: '',
      purchaseNumber: 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
      supplierId: _selectedSupplier!.id,
      supplierName: _selectedSupplier!.name,
      items: items,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _reviewPurchase() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draftPurchase();
    if (draft == null) {
      _showMessage(_validationMessage());
      return;
    }
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PurchaseReviewDialog(
        purchase: draft,
        onEdit: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (!mounted || shouldSave != true) return;
    await _savePurchase(draft);
  }

  String _validationMessage() {
    if (_selectedSupplier == null) return 'Select a supplier before reviewing.';
    if (_items.isEmpty) return 'Add at least one product before reviewing.';
    for (final item in _items) {
      if (item.quantity < 1) {
        return 'Every quantity must be a positive whole number.';
      }
      if (_priceFor(item) == null) {
        return 'Every purchase price must be a valid non-negative number.';
      }
    }
    return 'Review the purchase details and try again.';
  }

  String _purchaseNumber(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return 'PUR-${date.year}${two(date.month)}${two(date.day)}-'
        '${two(date.hour)}${two(date.minute)}${two(date.second)}${three(date.millisecond)}';
  }

  Future<void> _savePurchase(Purchase draft) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final savedAt = DateTime.now();
    final purchase = draft.copyWith(
      purchaseNumber: _purchaseNumber(savedAt),
      createdAt: savedAt,
    );
    try {
      await _purchaseRepository.completePurchase(purchase);
      if (!mounted) return;
      setState(() => _savedPurchase = purchase);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(_friendlySaveError(error));
    }
  }

  String _friendlySaveError(Object error) {
    if (error is PurchaseUnauthenticatedException ||
        error is PurchaseRepositoryException ||
        error is PurchaseValidationException ||
        error is PurchaseBusinessException) {
      return error.toString();
    }
    return 'Unable to save purchase. Please try again.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _close() async {
    if (_savedPurchase != null ||
        (_items.isEmpty && _selectedSupplier == null)) {
      if (mounted) Navigator.of(context).pop(_savedPurchase != null);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard purchase?'),
        content: const Text('Your current purchase details will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_savedPurchase != null) return _buildSuccess(context, _savedPurchase!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New purchase'),
        leading: IconButton(
            onPressed: _isSaving ? null : _close,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOptions, child: _buildEditor(context)),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final noSuppliers = _supplierError == null && _suppliers.isEmpty;
    final noProducts = _productError == null && _products.isEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Purchase details',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Reference: TEMP-${DateTime.now().millisecondsSinceEpoch}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 24),
                _buildSupplierSection(context, noSuppliers),
                const SizedBox(height: 20),
                _buildProductSection(context, noProducts),
                const SizedBox(height: 20),
                _buildSummary(context),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _reviewPurchase,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Review purchase'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierSection(BuildContext context, bool noSuppliers) {
    return _SectionCard(
      title: 'Supplier',
      child: _supplierError != null
          ? _InlineError(message: _supplierError!, onRetry: _loadOptions)
          : noSuppliers
              ? const _InlineEmpty(
                  message:
                      'No suppliers available. Add a supplier before creating a purchase.')
              : DropdownButtonFormField<Supplier>(
                  value: _selectedSupplier,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Select supplier'),
                  items: _suppliers
                      .map((supplier) => DropdownMenuItem(
                          value: supplier, child: Text(supplier.name)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _selectedSupplier = value),
                ),
    );
  }

  Widget _buildProductSection(BuildContext context, bool noProducts) {
    return _SectionCard(
      title: 'Products',
      child: _productError != null
          ? _InlineError(message: _productError!, onRetry: _loadOptions)
          : noProducts
              ? const _InlineEmpty(
                  message:
                      'No products available. Add a product before creating a purchase.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Add product'),
                      items: _products
                          .map((product) => DropdownMenuItem(
                              value: product,
                              child:
                                  Text('${product.name}  •  ${product.sku}')))
                          .toList(),
                      onChanged: _isSaving ? null : _selectProduct,
                    ),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ..._items.map((item) => _DraftItemRow(
                          item: item,
                          onRemove: () => _removeItem(item),
                          onChanged: () => setState(() {}))),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final totalQuantity =
        _items.fold<int>(0, (total, item) => total + item.quantity);
    final total = _items.fold<double>(
        0, (sum, item) => sum + (item.quantity * (_priceFor(item) ?? 0)));
    return _SectionCard(
      title: 'Summary',
      child: Wrap(
        spacing: 36,
        runSpacing: 18,
        children: [
          _SummaryValue(
              label: 'Supplier',
              value: _selectedSupplier?.name ?? 'Not selected'),
          _SummaryValue(label: 'Different products', value: '${_items.length}'),
          _SummaryValue(label: 'Total quantity', value: '$totalQuantity'),
          _SummaryValue(
              label: 'Subtotal', value: '₹${total.toStringAsFixed(2)}'),
          _SummaryValue(
              label: 'Total purchase amount',
              value: '₹${total.toStringAsFixed(2)}',
              emphasize: true),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, Purchase purchase) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase saved')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green.shade700),
                    const SizedBox(height: 16),
                    Text('Purchase record saved',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(purchase.purchaseNumber,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        'Total amount: ₹${purchase.totalAmount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    const Text('Inventory updated successfully.'),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Done')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftPurchaseItem {
  _DraftPurchaseItem(this.product)
      : priceController = TextEditingController(
            text: product.purchasePrice.toStringAsFixed(2));

  final Product product;
  final TextEditingController priceController;
  int quantity = 1;
}

class _DraftItemRow extends StatelessWidget {
  const _DraftItemRow(
      {required this.item, required this.onRemove, required this.onChanged});

  final _DraftPurchaseItem item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(item.priceController.text.trim()) ?? 0;
    final total = item.quantity * (price >= 0 ? price : 0);
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove product'),
              ],
            ),
            Text('SKU: ${item.product.sku}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.blueGrey.shade700)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final quantity =
                    _QuantityControl(item: item, onChanged: onChanged);
                final price = TextFormField(
                  controller: item.priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Purchase price'),
                  onChanged: (_) => onChanged(),
                );
                final totalWidget = _SummaryValue(
                    label: 'Line total',
                    value: '₹${total.toStringAsFixed(2)}',
                    emphasize: true);
                if (constraints.maxWidth < 560) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        quantity,
                        const SizedBox(height: 12),
                        price,
                        const SizedBox(height: 12),
                        totalWidget
                      ]);
                }
                return Row(children: [
                  Expanded(child: quantity),
                  const SizedBox(width: 16),
                  Expanded(child: price),
                  const SizedBox(width: 24),
                  totalWidget
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.item, required this.onChanged});

  final _DraftPurchaseItem item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(labelText: 'Quantity'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: item.quantity > 1
                    ? () {
                        item.quantity--;
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Decrease quantity'),
            Text('${item.quantity}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            IconButton(
                onPressed: () {
                  item.quantity++;
                  onChanged();
                },
                icon: const Icon(Icons.add),
                tooltip: 'Increase quantity'),
          ],
        ),
      );
}

class _PurchaseReviewDialog extends StatelessWidget {
  const _PurchaseReviewDialog(
      {required this.purchase, required this.onEdit, required this.onConfirm});

  final Purchase purchase;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Review purchase'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reference: ${purchase.purchaseNumber}'),
                const SizedBox(height: 6),
                Text('Supplier: ${purchase.supplierName}'),
                const SizedBox(height: 16),
                ...purchase.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(
                                  '${item.productName}\n${item.quantity} × ₹${item.purchasePrice.toStringAsFixed(2)}')),
                          Text('₹${item.lineTotal.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                const Divider(),
                Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                        'Total: ₹${purchase.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: onEdit, child: const Text('Edit purchase')),
          FilledButton(
              onPressed: onConfirm, child: const Text('Confirm purchase')),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            child
          ]),
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(
      {required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.blueGrey.shade700)),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasize
                      ? Theme.of(context).colorScheme.primary
                      : null)),
        ],
      );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Text(message,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(color: Colors.blueGrey.shade700));
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(message)),
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ],
      );
}
