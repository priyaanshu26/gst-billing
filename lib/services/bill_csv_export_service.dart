import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bill.dart';

/// Builds and shares a CSV export of bill history records.
/// Does not touch GST / invoice calculation logic.
class BillCsvExportService {
  static const List<String> headers = [
    'Invoice Number',
    'Invoice Date',
    'Party Name',
    'Party State',
    'Subtotal',
    'Total Tax',
    'Grand Total',
    'Payment Status',
    'Paid Amount',
    'Remaining Amount',
  ];

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  /// Escapes a single CSV field per RFC 4180-style rules.
  String escapeField(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _money(num value) => value.toStringAsFixed(2);

  List<String> _row(Bill bill) {
    return [
      bill.invoiceNo,
      _dateFormat.format(bill.invoiceDate),
      bill.partyName,
      bill.partyState,
      _money(bill.subtotal),
      _money(bill.totalTax),
      _money(bill.grandTotal),
      PaymentStatus.label(bill.paymentStatus),
      _money(bill.paidAmount),
      _money(bill.remainingAmount),
    ];
  }

  /// Builds a UTF-8 CSV string (with BOM) for [bills].
  String buildCsv(List<Bill> bills) {
    final buffer = StringBuffer();
    // UTF-8 BOM helps Excel open the file with correct encoding.
    buffer.write('\uFEFF');
    buffer.writeln(headers.map(escapeField).join(','));
    for (final bill in bills) {
      buffer.writeln(_row(bill).map(escapeField).join(','));
    }
    return buffer.toString();
  }

  String defaultFilename({DateTime? now}) {
    final stamp = _fileStamp.format(now ?? DateTime.now());
    return 'bill_history_$stamp.csv';
  }

  /// Shares the CSV via the platform share sheet / save dialog.
  Future<ShareResult> shareCsv(List<Bill> bills, {String? filename}) async {
    if (bills.isEmpty) {
      throw ArgumentError('No bills to export');
    }

    final name = filename ?? defaultFilename();
    final bytes = Uint8List.fromList(utf8.encode(buildCsv(bills)));

    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
            name: name,
          ),
        ],
        subject: 'Bill History Export',
        text: 'GST Billing — bill history CSV ($name)',
        fileNameOverrides: [name],
      ),
    );
  }
}
