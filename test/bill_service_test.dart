import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/models/bill.dart';
import 'package:gst_billing/services/bill_service.dart';

void main() {
  final service = BillService();

  Bill bill({
    required String id,
    required String invoiceNo,
    required String party,
    required DateTime date,
    required double total,
    required double tax,
  }) {
    return Bill(
      billId: id,
      invoiceNo: invoiceNo,
      invoiceDate: date,
      partyId: 'p1',
      partyName: party,
      partyState: 'Maharashtra',
      items: const [],
      subtotal: total - tax,
      totalTax: tax,
      grandTotal: total,
    );
  }

  group('BillService.filterBills', () {
    final bills = [
      bill(
        id: '1',
        invoiceNo: 'INV-0001',
        party: 'Acme Traders',
        date: DateTime(2026, 3, 1),
        total: 100,
        tax: 18,
      ),
      bill(
        id: '2',
        invoiceNo: 'INV-0002',
        party: 'Beta Stores',
        date: DateTime(2026, 3, 2),
        total: 200,
        tax: 36,
      ),
    ];

    test('filters by invoice number', () {
      final result = service.filterBills(bills, 'inv-0002');
      expect(result.length, 1);
      expect(result.first.invoiceNo, 'INV-0002');
    });

    test('filters by party name', () {
      final result = service.filterBills(bills, 'acme');
      expect(result.length, 1);
      expect(result.first.partyName, 'Acme Traders');
    });
  });

  group('BillService.buildDashboardStats', () {
    test('computes today and month metrics', () {
      final now = DateTime(2026, 3, 19, 12);
      final bills = [
        bill(
          id: '1',
          invoiceNo: 'INV-0001',
          party: 'A',
          date: DateTime(2026, 3, 19, 9),
          total: 118,
          tax: 18,
        ),
        bill(
          id: '2',
          invoiceNo: 'INV-0002',
          party: 'B',
          date: DateTime(2026, 3, 10),
          total: 236,
          tax: 36,
        ),
        bill(
          id: '3',
          invoiceNo: 'INV-0003',
          party: 'C',
          date: DateTime(2026, 2, 1),
          total: 500,
          tax: 50,
        ),
      ];

      final stats = service.buildDashboardStats(bills, now: now);

      expect(stats.todaySales, 118);
      expect(stats.todayBillCount, 1);
      expect(stats.monthlySales, 354);
      expect(stats.monthlyBillCount, 2);
      expect(stats.totalTax, 104);
      expect(stats.recentBills.length, 3);
    });
  });
}
