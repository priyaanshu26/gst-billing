import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/models/bill.dart';
import 'package:gst_billing/services/bill_csv_export_service.dart';

void main() {
  final service = BillCsvExportService();

  Bill sampleBill({
    String invoiceNo = 'INV-0001',
    String partyName = 'Acme Traders',
    String partyState = 'Maharashtra',
    double subtotal = 100,
    double tax = 18,
    String paymentStatus = PaymentStatus.paid,
    double? paidAmount,
    double? remainingAmount,
  }) {
    final total = subtotal + tax;
    return Bill(
      billId: 'b-$invoiceNo',
      invoiceNo: invoiceNo,
      invoiceDate: DateTime(2026, 9, 19),
      partyId: 'p1',
      partyName: partyName,
      partyState: partyState,
      items: const [],
      subtotal: subtotal,
      totalTax: tax,
      grandTotal: total,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount ??
          (paymentStatus == PaymentStatus.paid
              ? total
              : paymentStatus == PaymentStatus.unpaid
                  ? 0
                  : 40),
      remainingAmount: remainingAmount ??
          (paymentStatus == PaymentStatus.paid
              ? 0
              : paymentStatus == PaymentStatus.unpaid
                  ? total
                  : total - 40),
    );
  }

  group('BillCsvExportService.buildCsv', () {
    test('includes required headers', () {
      final csv = service.buildCsv([sampleBill()]);
      for (final header in BillCsvExportService.headers) {
        expect(csv, contains(header));
      }
    });

    test('exports invoice fields and payment columns', () {
      final csv = service.buildCsv([
        sampleBill(
          invoiceNo: 'INV-0042',
          partyName: 'Nakoda Stores',
          partyState: 'Gujarat',
          subtotal: 200,
          tax: 36,
          paymentStatus: PaymentStatus.partial,
          paidAmount: 100,
          remainingAmount: 136,
        ),
      ]);

      expect(csv, contains('INV-0042'));
      expect(csv, contains('19/09/2026'));
      expect(csv, contains('Nakoda Stores'));
      expect(csv, contains('Gujarat'));
      expect(csv, contains('200.00'));
      expect(csv, contains('36.00'));
      expect(csv, contains('236.00'));
      expect(csv, contains('Partial'));
      expect(csv, contains('100.00'));
      expect(csv, contains('136.00'));
    });

    test('escapes commas and quotes in party names', () {
      final csv = service.buildCsv([
        sampleBill(partyName: 'Acme, "Best" Traders'),
      ]);
      expect(csv, contains('"Acme, ""Best"" Traders"'));
    });

    test('exports multiple bill rows', () {
      final csv = service.buildCsv([
        sampleBill(invoiceNo: 'INV-0001'),
        sampleBill(invoiceNo: 'INV-0002', paymentStatus: PaymentStatus.unpaid),
      ]);
      final lines = csv
          .replaceFirst('\uFEFF', '')
          .trim()
          .split(RegExp(r'\r?\n'));
      // header + 2 data rows
      expect(lines.length, 3);
      expect(lines[1], contains('INV-0001'));
      expect(lines[2], contains('INV-0002'));
      expect(lines[2], contains('Unpaid'));
    });

    test('starts with UTF-8 BOM for Excel compatibility', () {
      final csv = service.buildCsv([sampleBill()]);
      expect(csv.codeUnitAt(0), 0xFEFF);
    });
  });

  group('BillCsvExportService.escapeField', () {
    test('leaves plain values unquoted', () {
      expect(service.escapeField('INV-0001'), 'INV-0001');
    });

    test('quotes values with commas', () {
      expect(service.escapeField('A, B'), '"A, B"');
    });
  });
}
