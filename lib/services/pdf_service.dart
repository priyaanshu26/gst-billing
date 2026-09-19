import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/shop_config.dart';
import '../utils/date_utils.dart';

/// Builds and shares invoice PDFs from saved [Bill] snapshots.
/// Does not recalculate GST — uses amounts already stored on the bill.
class PdfService {
  String _money(num value) => 'Rs. ${value.toStringAsFixed(2)}';

  String _qty(num value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Future<Uint8List> buildInvoicePdf({
    required Bill bill,
    required ShopConfig shop,
  }) async {
    final totalCgst = bill.items.fold<double>(0, (sum, i) => sum + i.cgst);
    final totalSgst = bill.items.fold<double>(0, (sum, i) => sum + i.sgst);
    final totalIgst = bill.items.fold<double>(0, (sum, i) => sum + i.igst);
    final isIntra = totalIgst == 0;

    final doc = pw.Document(
      title: bill.invoiceNo,
      author: shop.shopName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(shop, bill),
          pw.SizedBox(height: 16),
          _partyBlock(bill),
          pw.SizedBox(height: 16),
          _itemsTable(bill.items),
          pw.SizedBox(height: 16),
          _totalsBlock(
            bill: bill,
            totalCgst: totalCgst,
            totalSgst: totalSgst,
            totalIgst: totalIgst,
            isIntra: isIntra,
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'This is a computer-generated invoice.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(ShopConfig shop, Bill bill) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                shop.shopName.isEmpty ? 'Shop' : shop.shopName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              if (shop.address.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 10)),
              ],
              if (shop.state.isNotEmpty)
                pw.Text(
                  'State: ${shop.state}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (shop.gstin.isNotEmpty)
                pw.Text(
                  'GSTIN: ${shop.gstin}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (shop.mobile.isNotEmpty)
                pw.Text(
                  'Mobile: ${shop.mobile}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Invoice No: ${bill.invoiceNo}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Date: ${AppDateUtils.formatInvoice(bill.invoiceDate)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _partyBlock(Bill bill) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Bill To',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            bill.partyName,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          if (bill.partyAddress.isNotEmpty)
            pw.Text(
              bill.partyAddress,
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Text(
            'State: ${bill.partyState}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (bill.partyGSTIN.isNotEmpty)
            pw.Text(
              'GSTIN: ${bill.partyGSTIN}',
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(List<BillItem> items) {
    final headers = [
      'Item',
      'HSN',
      'Qty',
      'Rate',
      'Taxable',
      'GST %',
      'CGST',
      'SGST',
      'IGST',
      'Line Total',
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: [
        for (final item in items)
          [
            item.name,
            item.hsnCode.isEmpty ? '-' : item.hsnCode,
            _qty(item.quantity),
            _money(item.rate),
            _money(item.taxableAmount),
            item.gstPercent.toStringAsFixed(0),
            _money(item.cgst),
            _money(item.sgst),
            _money(item.igst),
            _money(item.lineTotal),
          ],
      ],
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(1.1),
        7: const pw.FlexColumnWidth(1.1),
        8: const pw.FlexColumnWidth(1.1),
        9: const pw.FlexColumnWidth(1.3),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerAlignments: {
        for (var i = 0; i < headers.length; i++) i: pw.Alignment.center,
      },
    );
  }

  pw.Widget _totalsBlock({
    required Bill bill,
    required double totalCgst,
    required double totalSgst,
    required double totalIgst,
    required bool isIntra,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 260,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              _totalRow('Subtotal', _money(bill.subtotal)),
              if (isIntra) ...[
                _totalRow('CGST', _money(totalCgst)),
                _totalRow('SGST', _money(totalSgst)),
              ] else
                _totalRow('IGST', _money(totalIgst)),
              _totalRow('Total Tax', _money(bill.totalTax)),
              pw.Divider(color: PdfColors.grey400),
              _totalRow(
                'Grand Total',
                _money(bill.grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> previewInvoice({
    required Bill bill,
    required ShopConfig shop,
  }) async {
    final bytes = await buildInvoicePdf(bill: bill, shop: shop);
    await Printing.layoutPdf(
      name: bill.invoiceNo,
      onLayout: (format) async => bytes,
    );
  }

  Future<void> shareInvoice({
    required Bill bill,
    required ShopConfig shop,
  }) async {
    final bytes = await buildInvoicePdf(bill: bill, shop: shop);
    final filename = '${bill.invoiceNo}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
