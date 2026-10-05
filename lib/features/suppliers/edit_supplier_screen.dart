import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';

class EditSupplierScreen extends StatefulWidget {
  const EditSupplierScreen({
    required this.supplier,
    this.repository,
    super.key,
  });

  final Supplier supplier;
  final SupplierRepository? repository;

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final SupplierRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    _repository = widget.repository ?? SupplierRepository();
    _nameController = TextEditingController(text: supplier.name);
    _phoneController = TextEditingController(text: supplier.phone);
    _emailController = TextEditingController(text: supplier.email);
    _addressController = TextEditingController(text: supplier.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final supplier = widget.supplier;
    final updatedSupplier = supplier.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
    );

    try {
      await _repository.updateSupplier(updatedSupplier);
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
    if (error is SupplierUnauthenticatedException ||
        error is SupplierRepositoryException ||
        error is SupplierNotFoundException) {
      return error.toString();
    }
    return 'Unable to save changes. Please try again.';
  }

  String? _requiredName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Supplier name cannot be empty.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit supplier'),
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
          final wide = layout != AppLayoutSize.mobile;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding(layout).copyWith(
                  top: AppSpacing.x8,
                  bottom: AppSpacing.x32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Edit supplier details',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        Text(
                          'Update the contact details for ${widget.supplier.name}.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.secondaryText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Supplier name',
                                  ),
                                  validator: _requiredName,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x16),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone (optional)',
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Supplier name',
                            ),
                            validator: _requiredName,
                          ),
                          const SizedBox(height: AppSpacing.x12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.x12),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email (optional)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x16),
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  textInputAction: TextInputAction.done,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Address (optional)',
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x12),
                          TextFormField(
                            controller: _addressController,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Address (optional)',
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.x20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: AppSpacing.x12),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _saveChanges,
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
                                _isSaving ? 'Saving...' : 'Save changes',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}