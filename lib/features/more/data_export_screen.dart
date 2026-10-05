import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../services/csv_export_service.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({
    this.billRepository,
    this.productRepository,
    this.supplierRepository,
    super.key,
  });

  final BillRepository? billRepository;
  final ProductRepository? productRepository;
  final SupplierRepository? supplierRepository;

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  late final BillRepository _billRepository;
  late final ProductRepository _productRepository;
  late final SupplierRepository _supplierRepository;
  final _csvExportService = const CsvExportService();
  String? _activeExport;

  @override
  void initState() {
    super.initState();
    _billRepository = widget.billRepository ?? BillRepository();
    _productRepository = widget.productRepository ?? ProductRepository();
    _supplierRepository = widget.supplierRepository ?? SupplierRepository();
  }

  Future<Uint8List> _loadSalesCsv() async {
    final bills = await _billRepository.getBills();
    return _csvExportService.generateSalesCsv(bills);
  }

  Future<Uint8List> _loadInventoryCsv() async {
    final data = await Future.wait<Object>([
      _productRepository.getProducts(),
      _supplierRepository.getSuppliers(),
    ]);
    return _csvExportService.generateInventoryCsv(
      data[0] as List<Product>,
      suppliers: data[1] as List<Supplier>,
    );
  }

  Future<Uint8List> _loadCustomersCsv() async {
    final bills = await _billRepository.getBills();
    return _csvExportService.generateCustomersCsv(bills);
  }

  Future<void> _export({
    required String key,
    required String filename,
    required Future<Uint8List> Function() loadCsv,
  }) async {
    if (_activeExport != null) return;
    setState(() => _activeExport = key);

    try {
      final bytes = await loadCsv();
      final result = await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: 'text/csv',
          ),
        ],
        subject: filename,
      );
      if (!mounted) return;
      final message = result.status == ShareResultStatus.unavailable
          ? '$filename was downloaded.'
          : '$filename is ready to share.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
              content: Text('Unable to export $filename. Please try again.')),
        );
    } finally {
      if (mounted) setState(() => _activeExport = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Export RetailIQ business data for analysis in Excel, '
                    'Power BI, Tableau or Python.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _ExportAction(
                    title: 'Export Sales',
                    filename: 'sales.csv',
                    icon: Icons.point_of_sale_outlined,
                    isLoading: _activeExport == 'sales',
                    isDisabled: _activeExport != null,
                    onPressed: () => _export(
                      key: 'sales',
                      filename: 'sales.csv',
                      loadCsv: _loadSalesCsv,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExportAction(
                    title: 'Export Inventory',
                    filename: 'inventory.csv',
                    icon: Icons.inventory_2_outlined,
                    isLoading: _activeExport == 'inventory',
                    isDisabled: _activeExport != null,
                    onPressed: () => _export(
                      key: 'inventory',
                      filename: 'inventory.csv',
                      loadCsv: _loadInventoryCsv,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExportAction(
                    title: 'Export Customers',
                    filename: 'customers.csv',
                    icon: Icons.people_outline,
                    isLoading: _activeExport == 'customers',
                    isDisabled: _activeExport != null,
                    onPressed: () => _export(
                      key: 'customers',
                      filename: 'customers.csv',
                      loadCsv: _loadCustomersCsv,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.title,
    required this.filename,
    required this.icon,
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
  });

  final String title;
  final String filename;
  final IconData icon;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(isLoading ? 'Preparing $filename...' : filename),
        trailing: isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: title,
                onPressed: isDisabled ? null : onPressed,
                icon: const Icon(Icons.file_download_outlined),
              ),
        onTap: isDisabled ? null : onPressed,
      ),
    );
  }
}
