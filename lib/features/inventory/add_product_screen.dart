import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({this.repository, super.key});

  final ProductRepository? repository;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController();
  final _supplierController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  late final ProductRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _supplierController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final product = Product(
      id: '',
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      category: _categoryController.text.trim(),
      supplierId: _supplierController.text.trim(),
      purchasePrice: double.parse(_purchasePriceController.text.trim()),
      sellingPrice: double.parse(_sellingPriceController.text.trim()),
      stockQuantity: int.parse(_stockController.text.trim()),
      reorderLevel: int.parse(_reorderLevelController.text.trim()),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _repository.addProduct(product);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  String _errorMessage(Object error) {
    if (error is UnauthenticatedException ||
        error is ProductRepositoryException ||
        error is ProductNotFoundException) {
      return error.toString();
    }
    return 'Unable to save product. Please try again.';
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label cannot be empty.';
    }
    return null;
  }

  String? _requiredDecimal(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    final number = double.tryParse(value.trim());
    if (number == null) {
      return 'Enter a valid $label.';
    }
    if (number < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  String? _requiredQuantity(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    final quantity = int.tryParse(value.trim());
    if (quantity == null) {
      return 'Enter a whole number for $label.';
    }
    if (quantity < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(labelText: label, hintText: hint);
  }

  Widget _fieldGroup({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.x12),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add product'),
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x16,
              AppSpacing.x12,
              AppSpacing.x16,
              AppSpacing.x32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x20),
                  child: Form(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact =
                            AppBreakpoints.fromWidth(constraints.maxWidth) ==
                                AppLayoutSize.mobile;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Add product',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.x8),
                            Text(
                              'Add an item to your inventory using the details on its packaging or invoice.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.x24),
                            _fieldGroup(
                              title: 'Product information',
                              children: [
                                if (isCompact)
                                  Column(
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('Product name'),
                                        validator: (value) =>
                                            _requiredText(value, 'Product name'),
                                      ),
                                      const SizedBox(height: AppSpacing.x16),
                                      TextFormField(
                                        controller: _skuController,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('SKU'),
                                        validator: (value) =>
                                            _requiredText(value, 'SKU'),
                                      ),
                                      const SizedBox(height: AppSpacing.x16),
                                      TextFormField(
                                        controller: _categoryController,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('Category'),
                                        validator: (value) =>
                                            _requiredText(value, 'Category'),
                                      ),
                                      const SizedBox(height: AppSpacing.x16),
                                      TextFormField(
                                        controller: _supplierController,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration(
                                          'Supplier (optional)',
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Wrap(
                                    spacing: AppSpacing.x16,
                                    runSpacing: AppSpacing.x16,
                                    children: [
                                      SizedBox(
                                        width: (constraints.maxWidth - AppSpacing.x16) /
                                            2,
                                        child: TextFormField(
                                          controller: _nameController,
                                          textInputAction: TextInputAction.next,
                                          decoration: _decoration('Product name'),
                                          validator: (value) =>
                                              _requiredText(value, 'Product name'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: (constraints.maxWidth - AppSpacing.x16) /
                                            2,
                                        child: TextFormField(
                                          controller: _skuController,
                                          textInputAction: TextInputAction.next,
                                          decoration: _decoration('SKU'),
                                          validator: (value) =>
                                              _requiredText(value, 'SKU'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: (constraints.maxWidth - AppSpacing.x16) /
                                            2,
                                        child: TextFormField(
                                          controller: _categoryController,
                                          textInputAction: TextInputAction.next,
                                          decoration: _decoration('Category'),
                                          validator: (value) =>
                                              _requiredText(value, 'Category'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: (constraints.maxWidth - AppSpacing.x16) /
                                            2,
                                        child: TextFormField(
                                          controller: _supplierController,
                                          textInputAction: TextInputAction.next,
                                          decoration: _decoration(
                                            'Supplier (optional)',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.x24),
                            _fieldGroup(
                              title: 'Pricing',
                              children: [
                                if (isCompact)
                                  Column(
                                    children: [
                                      TextFormField(
                                        controller: _purchasePriceController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('Purchase price'),
                                        validator: (value) =>
                                            _requiredDecimal(value, 'Purchase price'),
                                      ),
                                      const SizedBox(height: AppSpacing.x16),
                                      TextFormField(
                                        controller: _sellingPriceController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('Selling price'),
                                        validator: (value) =>
                                            _requiredDecimal(value, 'Selling price'),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _purchasePriceController,
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          textInputAction: TextInputAction.next,
                                          decoration:
                                              _decoration('Purchase price'),
                                          validator: (value) =>
                                              _requiredDecimal(
                                                value,
                                                'Purchase price',
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.x16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _sellingPriceController,
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          textInputAction: TextInputAction.next,
                                          decoration:
                                              _decoration('Selling price'),
                                          validator: (value) =>
                                              _requiredDecimal(
                                                value,
                                                'Selling price',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.x24),
                            _fieldGroup(
                              title: 'Stock',
                              children: [
                                if (isCompact)
                                  Column(
                                    children: [
                                      TextFormField(
                                        controller: _stockController,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration('Current stock'),
                                        validator: (value) =>
                                            _requiredQuantity(value, 'Stock quantity'),
                                      ),
                                      const SizedBox(height: AppSpacing.x16),
                                      TextFormField(
                                        controller: _reorderLevelController,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        decoration: _decoration('Reorder level'),
                                        validator: (value) =>
                                            _requiredQuantity(value, 'Reorder level'),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _stockController,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          decoration:
                                              _decoration('Current stock'),
                                          validator: (value) =>
                                              _requiredQuantity(
                                                value,
                                                'Stock quantity',
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.x16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _reorderLevelController,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.done,
                                          decoration:
                                              _decoration('Reorder level'),
                                          validator: (value) =>
                                              _requiredQuantity(
                                                value,
                                                'Reorder level',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.x28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: AppSpacing.x12),
                                FilledButton.icon(
                                  onPressed: _isSaving ? null : _saveProduct,
                                  icon: _isSaving
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSaving ? 'Saving...' : 'Add product',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
