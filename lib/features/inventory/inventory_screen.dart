import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

String _stockStatusFor(Product product) {
  if (product.stockQuantity == 0) return 'Out of Stock';
  if (product.stockQuantity <= product.reorderLevel) return 'Low Stock';
  return 'In Stock';
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({this.repository, super.key});

  final ProductRepository? repository;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _allCategories = 'All Categories';
  static const _allStockStatuses = 'All Stock Status';

  late final ProductRepository _repository;
  final _searchController = TextEditingController();
  List<Product> _products = const [];
  String? _errorMessage;
  String? _deletingProductId;
  String _selectedCategory = _allCategories;
  String _selectedStockStatus = _allStockStatuses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProductRepository();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final categories = _products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [_allCategories, ...categories];
  }

  List<Product> get _visibleProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == _allCategories ||
          product.category.trim() == _selectedCategory;
      final matchesStock = _selectedStockStatus == _allStockStatuses ||
          _stockStatusFor(product) == _selectedStockStatus;
      return matchesSearch && matchesCategory && matchesStock;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategory != _allCategories ||
      _selectedStockStatus != _allStockStatuses;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = _allCategories;
      _selectedStockStatus = _allStockStatuses;
    });
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final products = await _repository.getProducts();
      if (!mounted) return;
      final categories = products
          .map((product) => product.category.trim())
          .where((category) => category.isNotEmpty)
          .toSet();
      setState(() {
        _products = products;
        if (_selectedCategory != _allCategories &&
            !categories.contains(_selectedCategory)) {
          _selectedCategory = _allCategories;
        }
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
    if (error is UnauthenticatedException ||
        error is ProductRepositoryException) {
      return error.toString();
    }
    return 'Unable to load inventory. Please try again.';
  }

  Future<void> _openAddProduct() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddProductScreen(repository: _repository),
      ),
    );
    if (!mounted || added != true) return;

    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product saved successfully.')),
    );
  }

  Future<void> _editProduct(Product product) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProductScreen(
          product: product,
          repository: _repository,
        ),
      ),
    );
    if (!mounted || updated != true) return;

    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product updated successfully.')),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Are you sure you want to delete "${product.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;

    setState(() => _deletingProductId = product.id);
    try {
      await _repository.deleteProduct(product.id);
      if (!mounted) return;
      final products = _products
          .where((currentProduct) => currentProduct.id != product.id)
          .toList();
      final categories = products
          .map((currentProduct) => currentProduct.category.trim())
          .where((category) => category.isNotEmpty)
          .toSet();
      setState(() {
        _products = products;
        if (_selectedCategory != _allCategories &&
            !categories.contains(_selectedCategory)) {
          _selectedCategory = _allCategories;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _deletingProductId = null);
    }
  }

  Widget _buildRefreshableContent() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: _StateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load inventory',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onAction: _loadProducts,
            ),
          ),
        ],
      );
    }

    if (_products.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 420,
            child: _StateMessage(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: 'Add your first product to start managing your inventory.',
              actionLabel: 'Add product',
              onAction: _openAddProduct,
            ),
          ),
        ],
      );
    }

    final visibleProducts = _visibleProducts;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x16,
        AppSpacing.x8,
        AppSpacing.x16,
        AppSpacing.x32,
      ),
      itemCount: visibleProducts.isEmpty ? 3 : visibleProducts.length + 2,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _InventoryHeader(
            productCount: visibleProducts.length,
            onAddProduct: _openAddProduct,
          );
        }
        if (index == 1) {
          return _FilterControls(
            searchController: _searchController,
            categories: _categories,
            selectedCategory: _selectedCategory,
            selectedStockStatus: _selectedStockStatus,
            hasActiveFilters: _hasActiveFilters,
            onSearchChanged: (_) => setState(() {}),
            onCategoryChanged: (category) => setState(
              () => _selectedCategory = category ?? _allCategories,
            ),
            onStockStatusChanged: (status) => setState(
              () => _selectedStockStatus = status ?? _allStockStatuses,
            ),
            onClearFilters: _clearFilters,
          );
        }
        if (visibleProducts.isEmpty) {
          return _StateMessage(
            icon: Icons.search_off_outlined,
            title: 'No matching products',
            message: 'Try changing your search or filters.',
            actionLabel: 'Clear filters',
            onAction: _clearFilters,
          );
        }

        final product = visibleProducts[index - 2];
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _ProductCard(
              product: product,
              onEdit: () => _editProduct(product),
              onDelete: () => _deleteProduct(product),
              isDeleting: _deletingProductId == product.id,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh inventory',
          ),
          const SizedBox(width: AppSpacing.x8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: _buildRefreshableContent(),
      ),
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.productCount,
    required this.onAddProduct,
  });

  final int productCount;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            AppBreakpoints.fromWidth(constraints.maxWidth) == AppLayoutSize.mobile;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              '$productCount ${productCount == 1 ? 'product' : 'products'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );

        if (isCompact) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: AppSpacing.x12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAddProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Add product'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: content),
                const SizedBox(width: AppSpacing.x16),
                FilledButton.icon(
                  onPressed: onAddProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.selectedStockStatus,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStockStatusChanged,
    required this.onClearFilters,
  });

  static const _stockStatuses = [
    'All Stock Status',
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final String selectedStockStatus;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStockStatusChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                AppBreakpoints.fromWidth(constraints.maxWidth) == AppLayoutSize.mobile;

            final searchField = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search products',
                hintText: 'Search by name or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearFilters,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                      ),
              ),
            );

            final categoryField = SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: onCategoryChanged,
              ),
            );

            final statusField = SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: selectedStockStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Stock status'),
                items: _stockStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ),
                    )
                    .toList(),
                onChanged: onStockStatusChanged,
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: AppSpacing.x12),
                  categoryField,
                  const SizedBox(height: AppSpacing.x12),
                  statusField,
                  if (hasActiveFilters) ...[
                    const SizedBox(height: AppSpacing.x8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onClearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      ),
                    ),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: AppSpacing.x12),
                Wrap(
                  spacing: AppSpacing.x12,
                  runSpacing: AppSpacing.x12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    categoryField,
                    statusField,
                    if (hasActiveFilters)
                      TextButton.icon(
                        onPressed: onClearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDeleting;

  String get _stockStatus => _stockStatusFor(product);

  Color _statusColor(BuildContext context) {
    switch (_stockStatus) {
      case 'Out of Stock':
        return Theme.of(context).colorScheme.error;
      case 'Low Stock':
        return Colors.orange.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  Widget _buildStatusBadge(BuildContext context) {
    final statusColor = _statusColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          _stockStatus,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasize
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = AppBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
        AppLayoutSize.mobile;

    final details = Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        _buildMetric(context, 'Selling price', _formatPrice(product.sellingPrice)),
        _buildMetric(
          context,
          'Purchase price',
          _formatPrice(product.purchasePrice),
        ),
        _buildMetric(context, 'Stock', '${product.stockQuantity}',
            emphasize: true),
        _buildMetric(context, 'Reorder', '${product.reorderLevel}'),
      ],
    );

    final supplierText = product.supplierId.trim();

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? AppSpacing.x16 : AppSpacing.x20,
          isCompact ? AppSpacing.x16 : AppSpacing.x20,
          isCompact ? AppSpacing.x16 : AppSpacing.x20,
          isCompact ? AppSpacing.x16 : AppSpacing.x20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        '${product.sku} • ${product.category}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            details,
            if (supplierText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Text(
                'Supplier: $supplierText',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.x12),
            if (isCompact)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                    child: isDeleting
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isDeleting)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final rounded = price.truncateToDouble();
    final showsDecimal = rounded != price;
    return '₹${showsDecimal ? price.toStringAsFixed(2) : price.toStringAsFixed(0)}';
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionLabel == 'Try again' ? Icons.refresh : Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
