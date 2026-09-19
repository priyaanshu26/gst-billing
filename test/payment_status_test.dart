import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/models/bill.dart';

void main() {
  group('Bill.resolvePayment', () {
    test('PAID sets paidAmount = grandTotal and remaining = 0', () {
      final payment = Bill.resolvePayment(
        paymentStatus: PaymentStatus.paid,
        grandTotal: 118.5,
      );
      expect(payment.paymentStatus, PaymentStatus.paid);
      expect(payment.paidAmount, 118.5);
      expect(payment.remainingAmount, 0);
    });

    test('UNPAID sets paidAmount = 0 and remaining = grandTotal', () {
      final payment = Bill.resolvePayment(
        paymentStatus: PaymentStatus.unpaid,
        grandTotal: 236,
      );
      expect(payment.paymentStatus, PaymentStatus.unpaid);
      expect(payment.paidAmount, 0);
      expect(payment.remainingAmount, 236);
    });

    test('PARTIAL sets remaining = grandTotal - paidAmount', () {
      final payment = Bill.resolvePayment(
        paymentStatus: PaymentStatus.partial,
        grandTotal: 200,
        paidAmount: 75.5,
      );
      expect(payment.paymentStatus, PaymentStatus.partial);
      expect(payment.paidAmount, 75.5);
      expect(payment.remainingAmount, 124.5);
    });
  });

  group('Bill.validatePayment', () {
    test('accepts paid and unpaid', () {
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.paid,
          grandTotal: 100,
        ),
        isNull,
      );
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.unpaid,
          grandTotal: 100,
        ),
        isNull,
      );
    });

    test('partial requires paidAmount > 0 and < grandTotal', () {
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: 100,
          paidAmount: null,
        ),
        isNotNull,
      );
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: 100,
          paidAmount: 0,
        ),
        isNotNull,
      );
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: 100,
          paidAmount: 100,
        ),
        isNotNull,
      );
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: 100,
          paidAmount: 150,
        ),
        isNotNull,
      );
      expect(
        Bill.validatePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: 100,
          paidAmount: 40,
        ),
        isNull,
      );
    });
  });

  group('Bill Firestore payment snapshot', () {
    test('round-trips payment fields', () {
      final bill = Bill(
        billId: 'b1',
        invoiceNo: 'INV-0009',
        invoiceDate: DateTime(2026, 9, 19),
        partyId: 'p1',
        partyName: 'Acme',
        partyState: 'Maharashtra',
        items: const [],
        subtotal: 100,
        totalTax: 18,
        grandTotal: 118,
        paymentStatus: PaymentStatus.partial,
        paidAmount: 50,
        remainingAmount: 68,
      );

      final restored = Bill.fromMap(bill.billId, bill.toMap());
      expect(restored.paymentStatus, PaymentStatus.partial);
      expect(restored.paidAmount, 50);
      expect(restored.remainingAmount, 68);
    });

    test('legacy bills without payment fields default to unpaid', () {
      final restored = Bill.fromMap('legacy', {
        'invoiceNo': 'INV-0001',
        'invoiceDate': DateTime(2026, 1, 1),
        'partyId': 'p1',
        'partyName': 'Old',
        'partyState': 'Maharashtra',
        'items': [],
        'subtotal': 100,
        'totalTax': 18,
        'grandTotal': 118,
        'status': 'generated',
      });

      expect(restored.paymentStatus, PaymentStatus.unpaid);
      expect(restored.paidAmount, 0);
      expect(restored.remainingAmount, 118);
    });

    test('withPayment updates status amounts without changing GST totals', () {
      final bill = Bill(
        billId: 'b1',
        invoiceNo: 'INV-0009',
        invoiceDate: DateTime(2026, 9, 19),
        partyId: 'p1',
        partyName: 'Acme',
        partyState: 'Maharashtra',
        items: const [],
        subtotal: 100,
        totalTax: 18,
        grandTotal: 118,
        paymentStatus: PaymentStatus.unpaid,
        paidAmount: 0,
        remainingAmount: 118,
      );

      final updated = bill.withPayment(
        Bill.resolvePayment(
          paymentStatus: PaymentStatus.partial,
          grandTotal: bill.grandTotal,
          paidAmount: 40,
        ),
      );

      expect(updated.paymentStatus, PaymentStatus.partial);
      expect(updated.paidAmount, 40);
      expect(updated.remainingAmount, 78);
      expect(updated.subtotal, 100);
      expect(updated.totalTax, 18);
      expect(updated.grandTotal, 118);
      expect(updated.invoiceNo, 'INV-0009');
    });
  });
}
