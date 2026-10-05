import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';
import 'add_supplier_screen.dart';
import 'edit_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({this.repository, super.key});

  final SupplierRepository? repository;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierRepository _repository;
  List<Supplier> _suppliers = const [];
  String? _errorMessage;
  String? _deletingSupplierId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupplierRepository();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final suppliers = await _repository.getSuppliers();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
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
    if (error is SupplierUnauthenticatedException ||
        error is SupplierRepositoryException ||
        error is SupplierNotFoundException) {
      return error.toString();
    }
    return 'Unable to load suppliers. Please try again.';
  }

  Future<void> _openAddSupplier() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddSupplierScreen(repository: _repository),
      ),
    );
    if (!mounted || added != true) return;

    await _loadSuppliers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supplier saved successfully.')),
    );
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditSupplierScreen(
          supplier: supplier,
          repository: _repository,
        ),
      ),
    );
    if (!mounted || updated != true) return;

    await _loadSuppliers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supplier updated successfully.')),
    );
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete supplier?'),
        content: Text(
          'Are you sure you want to delete "${supplier.name}"?\n\n'
          'This will not delete related products or purchases.',
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

    setState(() => _deletingSupplierId = supplier.id);
    try {
      await _repository.deleteSupplier(supplier.id);
      if (!mounted) return;
      setState(() {
        _suppliers = _suppliers
            .where((currentSupplier) => currentSupplier.id != supplier.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _deletingSupplierId = null);
    }
  }

  Widget _buildContent() {
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
            child: _SupplierStateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load suppliers',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onAction: _loadSuppliers,
            ),
          ),
        ],
      );
    }

    if (_suppliers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 480,
            child: _SupplierStateMessage(
              icon: Icons.business_outlined,
              title: 'No suppliers yet',
              message: 'Add your first supplier to start managing contacts.',
              actionLabel: 'Add supplier',
              onAction: _openAddSupplier,
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
          itemCount: _suppliers.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? AppSpacing.x16 : AppSpacing.x12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _SuppliersHeader(
                supplierCount: _suppliers.length,
                onAddSupplier: _openAddSupplier,
              );
            }
            final supplier = _suppliers[index - 1];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _SupplierCard(
                  supplier: supplier,
                  onEdit: () => _editSupplier(supplier),
                  onDelete: () => _deleteSupplier(supplier),
                  isDeleting: _deletingSupplierId == supplier.id,
                ),
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
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSuppliers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh suppliers',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: _buildContent(),
      ),
    );
  }
}

class _SuppliersHeader extends StatelessWidget {
  const _SuppliersHeader({
    required this.supplierCount,
    required this.onAddSupplier,
  });

  final int supplierCount;
  final VoidCallback onAddSupplier;

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
                    'Suppliers',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    '$supplierCount ${supplierCount == 1 ? 'supplier' : 'suppliers'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x16),
            FilledButton.icon(
              onPressed: onAddSupplier,
              icon: const Icon(Icons.add_outlined),
              label: const Text('Add supplier'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
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
                    supplier.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            Wrap(
              spacing: AppSpacing.x24,
              runSpacing: AppSpacing.x12,
              children: [
                if (supplier.phone.trim().isNotEmpty)
                  _SupplierInfo(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: supplier.phone,
                  ),
                if (supplier.email.trim().isNotEmpty)
                  _SupplierInfo(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: supplier.email,
                  ),
                if (supplier.address.trim().isNotEmpty)
                  _SupplierInfo(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: supplier.address,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierInfo extends StatelessWidget {
  const _SupplierInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.teal),
          const SizedBox(width: AppSpacing.x8),
          Flexible(
            child: Column(
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
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierStateMessage extends StatelessWidget {
  const _SupplierStateMessage({
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
              color: AppTheme.teal,
            ),
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
                actionLabel == 'Try again'
                    ? Icons.refresh
                    : Icons.add,
              ),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}