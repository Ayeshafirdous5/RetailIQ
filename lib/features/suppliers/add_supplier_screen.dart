import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({this.repository, super.key});

  final SupplierRepository? repository;

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  late final SupplierRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupplierRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final supplier = Supplier(
      id: '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _repository.addSupplier(supplier);
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
        error is SupplierRepositoryException) {
      return error.toString();
    }
    return 'Unable to save supplier. Please try again.';
  }

  String? _requiredName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Supplier name cannot be empty.';
    }
    return null;
  }

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add supplier'),
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
                          'Supplier details',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        Text(
                          'Save the contact details you use when buying stock.',
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
                                  decoration: _decoration('Supplier name'),
                                  validator: _requiredName,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x16),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration:
                                      _decoration('Phone (optional)'),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration('Supplier name'),
                            validator: _requiredName,
                          ),
                          const SizedBox(height: AppSpacing.x12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration('Phone (optional)'),
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
                                  decoration:
                                      _decoration('Email (optional)'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x16),
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  textInputAction: TextInputAction.done,
                                  maxLines: 4,
                                  decoration:
                                      _decoration('Address (optional)'),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration('Email (optional)'),
                          ),
                          const SizedBox(height: AppSpacing.x12),
                          TextFormField(
                            controller: _addressController,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            decoration: _decoration('Address (optional)'),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.x20),
                        _FormActions(
                          isSaving: _isSaving,
                          onCancel: () => Navigator.of(context).pop(),
                          onSave: _saveSupplier,
                          saveLabel: 'Save supplier',
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

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
  });

  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isSaving ? null : onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.x12),
        FilledButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Saving...' : saveLabel),
        ),
      ],
    );
  }
}