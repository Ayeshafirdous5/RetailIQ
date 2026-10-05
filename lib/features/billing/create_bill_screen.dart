import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bill.dart';
import '../../models/product.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/product_repository.dart';
import 'checkout_screen.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({
    this.productRepository,
    this.billRepository,
    this.initialBill,
    super.key,
  });

  final ProductRepository? productRepository;
  final BillRepository? billRepository;
  final Bill? initialBill;

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  static const _walkInCustomer = 'Walk-in Customer';
  static const _paymentMethods = ['Cash', 'UPI', 'Card', 'Other'];

  late final ProductRepository _productRepository;
  final _discountController = TextEditingController();
  List<Product> _products = const [];
  List<BillItem> _items = const [];
  String? _productsError;
  String? _discountError;
  String _paymentMethod = 'Cash';
  bool _isLoadingProducts = true;
  late DateTime _createdAt;
  late String _billNumber;

  @override
  void initState() {
    super.initState();
    _productRepository = widget.productRepository ?? ProductRepository();
    final initialBill = widget.initialBill;
    _createdAt = initialBill?.createdAt ?? DateTime.now();
    _billNumber =
        initialBill?.billNumber ?? 'TEMP-${_createdAt.millisecondsSinceEpoch}';
    if (initialBill != null) {
      _items = List<BillItem>.of(initialBill.items);
      _paymentMethod = initialBill.paymentMethod;
      if (initialBill.discount > 0) {
        _discountController.text = initialBill.discount.toString();
      }
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final products = await _productRepository.getProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productsError = 'Unable to load products. Please try again.';
        _isLoadingProducts = false;
      });
    }
  }

  Bill get _currentBill {
    return Bill(
      id: '',
      billNumber: _billNumber,
      customerId: null,
      customerName: _walkInCustomer,
      items: _items,
      discount: _discountValue,
      paymentMethod: _paymentMethod,
      createdAt: _createdAt,
    );
  }

  double get _discountValue {
    final value = double.tryParse(_discountController.text.trim());
    return value != null && value >= 0 ? value : 0;
  }

  void _addProduct(Product product) {
    final itemIndex = _items.indexWhere((item) => item.productId == product.id);
    setState(() {
      if (itemIndex == -1) {
        _items = [
          ..._items,
          BillItem(
            productId: product.id,
            productName: product.name,
            sku: product.sku,
            category: product.category,
            quantity: 1,
            sellingPrice: product.sellingPrice,
            purchasePrice: product.purchasePrice,
            discount: 0,
          ),
        ];
      } else {
        final item = _items[itemIndex];
        _items = [
          for (var index = 0; index < _items.length; index++)
            index == itemIndex
                ? item.copyWith(quantity: item.quantity + 1)
                : _items[index],
        ];
      }
    });
  }

  void _changeQuantity(BillItem item, int change) {
    final nextQuantity = item.quantity + change;
    if (nextQuantity < 1) return;
    setState(() {
      _items = _items
          .map(
            (currentItem) => currentItem.productId == item.productId
                ? currentItem.copyWith(quantity: nextQuantity)
                : currentItem,
          )
          .toList(growable: false);
    });
  }

  void _removeItem(BillItem item) {
    setState(() {
      _items = _items
          .where((currentItem) => currentItem.productId != item.productId)
          .toList(growable: false);
    });
  }

  void _onDiscountChanged(String value) {
    final trimmedValue = value.trim();
    final parsedValue = double.tryParse(trimmedValue);
    setState(() {
      if (trimmedValue.isEmpty) {
        _discountError = null;
      } else if (parsedValue == null) {
        _discountError = 'Enter a valid discount.';
      } else if (parsedValue < 0) {
        _discountError = 'Discount cannot be negative.';
      } else {
        _discountError = null;
      }
    });
  }

  Future<void> _reviewBill() async {
    final discount = _discountController.text.trim();
    final parsedDiscount = double.tryParse(discount);
    if (_items.isEmpty) {
      _showMessage('Add at least one product before reviewing the bill.');
      return;
    }
    if (discount.isNotEmpty && (parsedDiscount == null || parsedDiscount < 0)) {
      setState(() => _discountError = parsedDiscount == null
          ? 'Enter a valid discount.'
          : 'Discount cannot be negative.');
      return;
    }
    final bill = _currentBill;
    if (bill.total < 0 || bill.paymentMethod.isEmpty) {
      _showMessage('Check the bill details before continuing.');
      return;
    }

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => CheckoutScreen(
          bill: bill,
          billRepository: widget.billRepository,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == true) {
      Navigator.of(context).pop(true);
      return;
    }
    if (result is! Bill) return;
    final editedBill = result;
    setState(() {
      _items = List<BillItem>.of(editedBill.items);
      _paymentMethod = editedBill.paymentMethod;
      _discountController.text =
          editedBill.discount == 0 ? '' : editedBill.discount.toString();
      _createdAt = editedBill.createdAt;
      _billNumber = editedBill.billNumber;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatPrice(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final bill = _currentBill;
    final layoutSize =
        AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
    final isMobile = layoutSize == AppLayoutSize.mobile;
    final sectionGap = isMobile ? AppSpacing.x12 : AppSpacing.x16;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New bill'),
        leading: IconButton(
          onPressed: _confirmDiscard,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
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
                  _SectionCard(
                    title: 'Customer',
                    icon: Icons.person_outline,
                    child: DropdownButtonFormField<String>(
                      value: _walkInCustomer,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _walkInCustomer,
                          child: Text(_walkInCustomer),
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _SectionCard(
                    title: 'Add products',
                    icon: Icons.add_shopping_cart_outlined,
                    child: _buildProductPicker(),
                  ),
                  SizedBox(height: sectionGap),
                  _SectionCard(
                    title: 'Bill items',
                    icon: Icons.receipt_long_outlined,
                    child: _buildBillItems(),
                  ),
                  SizedBox(height: sectionGap),
                  _SectionCard(
                    title: 'Payment and discount',
                    icon: Icons.payments_outlined,
                    child: _buildPaymentSection(),
                  ),
                  SizedBox(height: sectionGap),
                  _SummaryCard(bill: bill, formatPrice: _formatPrice),
                  const SizedBox(height: AppSpacing.x16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: FilledButton.icon(
                        onPressed: _reviewBill,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Review bill'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    if (_items.isEmpty && _discountController.text.trim().isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this bill?'),
        content: const Text(
          'This bill has unsaved items. Are you sure you want to discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) Navigator.of(context).pop();
  }

  Widget _buildProductPicker() {
    if (_isLoadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_productsError != null) {
      return _InlineState(
        icon: Icons.cloud_off_outlined,
        message: _productsError!,
        actionLabel: 'Retry',
        onAction: _loadProducts,
      );
    }
    if (_products.isEmpty) {
      return const _InlineState(
        icon: Icons.inventory_2_outlined,
        message: 'No products are available to add to this bill.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _products.length; index++) ...[
          _ProductPickerRow(
            product: _products[index],
            price: _formatPrice(_products[index].sellingPrice),
            onTap: () => _addProduct(_products[index]),
          ),
          if (index < _products.length - 1)
            const SizedBox(height: AppSpacing.x8),
        ],
      ],
    );
  }

  Widget _buildBillItems() {
    if (_items.isEmpty) {
      return const _InlineState(
        icon: Icons.receipt_long_outlined,
        message: 'No products added yet. Choose a product above to begin.',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < _items.length; index++) ...[
          _BillItemTile(
            item: _items[index],
            formatPrice: _formatPrice,
            onDecrease: () => _changeQuantity(_items[index], -1),
            onIncrease: () => _changeQuantity(_items[index], 1),
            onRemove: () => _removeItem(_items[index]),
          ),
          if (index < _items.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }

  Widget _buildPaymentSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paymentField = DropdownButtonFormField<String>(
          value: _paymentMethod,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: _paymentMethods
              .map(
                (method) => DropdownMenuItem(
                  value: method,
                  child: Text(method),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _paymentMethod = value);
          },
        );
        final discountField = TextFormField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Bill discount',
            prefixText: '₹ ',
            errorText: _discountError,
          ),
          onChanged: _onDiscountChanged,
        );
        if (AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
            AppLayoutSize.mobile) {
          return Column(
            children: [paymentField, const SizedBox(height: 16), discountField],
          );
        }
        return Row(
          children: [
            Expanded(child: paymentField),
            const SizedBox(width: 16),
            Expanded(child: discountField),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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

class _ProductPickerRow extends StatelessWidget {
  const _ProductPickerRow({
    required this.product,
    required this.price,
    required this.onTap,
  });

  final Product product;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x12,
            vertical: AppSpacing.x8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'SKU: ${product.sku}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: Theme.of(context).textTheme.titleSmall),
                const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppTheme.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillItemTile extends StatelessWidget {
  const _BillItemTile({
    required this.item,
    required this.formatPrice,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final BillItem item;
  final String Function(double) formatPrice;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: Theme.of(context).textTheme.titleSmall,
              softWrap: true,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'SKU: ${item.sku} · Selling: ${formatPrice(item.sellingPrice)}',
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
            Text(
              'Item discount: ${formatPrice(item.discount)}',
              style: Theme.of(context).textTheme.bodySmall,
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
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.x8),
                  Flexible(child: lineTotal),
                ],
              ),
              const SizedBox(height: AppSpacing.x8),
              Row(
                children: [
                  const Spacer(),
                  _quantityControls(context),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove item',
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: details),
            const SizedBox(width: AppSpacing.x12),
            _quantityControls(context),
            const SizedBox(width: AppSpacing.x8),
            SizedBox(width: 96, child: lineTotal),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove item',
            ),
          ],
        );
      },
    );
  }

  Widget _quantityControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: item.quantity > 1 ? onDecrease : null,
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Decrease quantity',
        ),
        Text(
          '${item.quantity}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        IconButton(
          onPressed: onIncrease,
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Increase quantity',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.bill, required this.formatPrice});

  final Bill bill;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          children: [
            _SummaryRow(label: 'Subtotal', value: formatPrice(bill.subtotal)),
            const SizedBox(height: AppSpacing.x8),
            _SummaryRow(
              label: 'Discount',
              value: formatPrice(bill.discount),
              subdued: true,
            ),
            const Divider(height: 28),
            _SummaryRow(
              label: 'Total',
              value: formatPrice(bill.total),
              prominent: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
    this.subdued = false,
  });

  final String label;
  final String value;
  final bool prominent;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final style = prominent
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              color: AppTheme.navy,
            )
        : subdued
            ? Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText,
                )
            : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.x8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
