import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../models/bill.dart';

class BillPdfService {
  BillPdfService._();

  static Future<(pw.Font, pw.Font)>? _fontFuture;

  static Future<Uint8List> generate(Bill bill) async {
    final fonts = await (_fontFuture ??= _loadFonts());
    final document = pw.Document();
    final theme = pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2);

    document.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(36, 38, 36, 40),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            'RETAILIQ  |  INVOICE',
            style: pw.TextStyle(
              fontSize: 8,
              color: pw.PdfColors.blueGrey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: pw.PdfColors.grey700),
          ),
        ),
        build: (context) => [
          _invoiceHeading(),
          pw.SizedBox(height: 24),
          _billInformation(bill),
          pw.SizedBox(height: 24),
          pw.Text(
            'ITEMS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: pw.PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          _itemsTable(bill.items),
          pw.SizedBox(height: 20),
          _totals(bill),
          pw.SizedBox(height: 28),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Thank You!',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: pw.PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'RetailIQ',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: pw.PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<(pw.Font, pw.Font)> _loadFonts() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-bold.ttf'),
    );
    return (regular, bold);
  }

  static pw.Widget _invoiceHeading() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RETAILIQ',
          style: pw.TextStyle(
            fontSize: 25,
            fontWeight: pw.FontWeight.bold,
            color: pw.PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Retail Sales, Inventory & Business Intelligence Platform',
          style:
              const pw.TextStyle(fontSize: 9, color: pw.PdfColors.blueGrey700),
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: pw.PdfColors.teal700),
      ],
    );
  }

  static pw.Widget _billInformation(Bill bill) {
    final customer = bill.customerName.trim().isEmpty
        ? 'Walk-in Customer'
        : bill.customerName.trim();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _informationBlock('BILL TO', [customer]),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: _informationBlock('INVOICE DETAILS', [
            'Bill number: ${bill.billNumber}',
            'Date and time: ${_formatDateTime(bill.createdAt)}',
            'Payment method: ${bill.paymentMethod}',
          ]),
        ),
      ],
    );
  }

  static pw.Widget _informationBlock(String heading, List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          heading,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: pw.PdfColors.blueGrey700,
          ),
        ),
        pw.SizedBox(height: 7),
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
          ),
      ],
    );
  }

  static pw.Widget _itemsTable(List<BillItem> items) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: pw.PdfColors.blueGrey900),
        children: [
          _tableCell('Product', header: true),
          _tableCell('SKU', header: true),
          _tableCell('Qty', header: true, alignment: pw.Alignment.center),
          _tableCell('Unit Price',
              header: true, alignment: pw.Alignment.centerRight),
          _tableCell('Discount',
              header: true, alignment: pw.Alignment.centerRight),
          _tableCell('Line Total',
              header: true, alignment: pw.Alignment.centerRight),
        ],
      ),
      for (final item in items)
        pw.TableRow(
          children: [
            _productCell(item),
            _tableCell(item.sku.isEmpty ? 'N/A' : item.sku),
            _tableCell('${item.quantity}', alignment: pw.Alignment.center),
            _tableCell(_formatPrice(item.sellingPrice),
                alignment: pw.Alignment.centerRight),
            _tableCell(_formatPrice(item.discount),
                alignment: pw.Alignment.centerRight),
            _tableCell(_formatPrice(item.lineTotal),
                alignment: pw.Alignment.centerRight),
          ],
        ),
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(2.15),
        1: pw.FlexColumnWidth(1.35),
        2: pw.FlexColumnWidth(0.55),
        3: pw.FlexColumnWidth(1.05),
        4: pw.FlexColumnWidth(0.9),
        5: pw.FlexColumnWidth(1.1),
      },
      border: const pw.TableBorder(
        horizontalInside:
            pw.BorderSide(color: pw.PdfColors.grey300, width: 0.5),
        bottom: pw.BorderSide(color: pw.PdfColors.grey400, width: 0.7),
      ),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _productCell(BillItem item) {
    final category = item.category?.trim();
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(item.productName, style: const pw.TextStyle(fontSize: 8)),
          if (category != null && category.isNotEmpty)
            pw.Text(
              category,
              style:
                  const pw.TextStyle(fontSize: 7, color: pw.PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String value, {
    bool header = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: pw.Text(
        value,
        textAlign: alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : alignment == pw.Alignment.centerRight
                ? pw.TextAlign.right
                : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: header ? 7.5 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? pw.PdfColors.white : pw.PdfColors.blueGrey900,
        ),
      ),
    );
  }

  static pw.Widget _totals(Bill bill) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 225,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', _formatPrice(bill.subtotal)),
            pw.SizedBox(height: 7),
            _totalRow('Total Discount', _formatPrice(bill.discount)),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 9),
              height: 1,
              color: pw.PdfColors.grey400,
            ),
            _totalRow('Grand Total', _formatPrice(bill.total), prominent: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool prominent = false,
  }) {
    final style = pw.TextStyle(
      fontSize: prominent ? 12 : 9,
      fontWeight: prominent ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: pw.PdfColors.blueGrey900,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    );
  }

  static String _formatPrice(double value) => '₹${value.toStringAsFixed(2)}';

  static String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}, '
        '${hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.hour < 12 ? 'AM' : 'PM'}';
  }
}
