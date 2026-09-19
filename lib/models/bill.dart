import '../utils/currency_utils.dart';
import 'bill_item.dart';
import 'map_helpers.dart';

class BillStatus {
  static const generated = 'generated';
}

/// Payment tracking for a saved bill (bonus feature).
class PaymentStatus {
  static const paid = 'paid';
  static const unpaid = 'unpaid';
  static const partial = 'partial';

  static const List<String> values = [paid, unpaid, partial];

  static String label(String status) {
    switch (status) {
      case paid:
        return 'Paid';
      case unpaid:
        return 'Unpaid';
      case partial:
        return 'Partial';
      default:
        return status;
    }
  }

  static bool isValid(String status) => values.contains(status);
}

/// Resolved paid / remaining amounts for a given payment status.
class PaymentBreakdown {
  final String paymentStatus;
  final double paidAmount;
  final double remainingAmount;

  const PaymentBreakdown({
    required this.paymentStatus,
    required this.paidAmount,
    required this.remainingAmount,
  });
}

class Bill {
  final String billId;
  final String invoiceNo;
  final DateTime invoiceDate;
  final String partyId;
  final String partyName;
  final String partyAddress;
  final String partyState;
  final String partyGSTIN;
  final List<BillItem> items;
  final double subtotal;
  final double totalTax;
  final double grandTotal;
  final String status;
  final String paymentStatus;
  final double paidAmount;
  final double remainingAmount;

  const Bill({
    required this.billId,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.partyId,
    required this.partyName,
    this.partyAddress = '',
    required this.partyState,
    this.partyGSTIN = '',
    required this.items,
    required this.subtotal,
    required this.totalTax,
    required this.grandTotal,
    this.status = BillStatus.generated,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paidAmount = 0,
    double? remainingAmount,
  }) : remainingAmount = remainingAmount ?? grandTotal;

  /// Applies payment rules without changing GST totals.
  static PaymentBreakdown resolvePayment({
    required String paymentStatus,
    required double grandTotal,
    double? paidAmount,
  }) {
    final total = CurrencyUtils.roundMoney(grandTotal);

    switch (paymentStatus) {
      case PaymentStatus.paid:
        return PaymentBreakdown(
          paymentStatus: PaymentStatus.paid,
          paidAmount: total,
          remainingAmount: 0,
        );
      case PaymentStatus.unpaid:
        return PaymentBreakdown(
          paymentStatus: PaymentStatus.unpaid,
          paidAmount: 0,
          remainingAmount: total,
        );
      case PaymentStatus.partial:
        final paid = CurrencyUtils.roundMoney(paidAmount ?? 0);
        return PaymentBreakdown(
          paymentStatus: PaymentStatus.partial,
          paidAmount: paid,
          remainingAmount: CurrencyUtils.roundMoney(total - paid),
        );
      default:
        throw ArgumentError('Invalid payment status: $paymentStatus');
    }
  }

  /// Returns an error message if payment values are invalid, otherwise null.
  static String? validatePayment({
    required String paymentStatus,
    required double grandTotal,
    double? paidAmount,
  }) {
    if (!PaymentStatus.isValid(paymentStatus)) {
      return 'Select a payment status';
    }

    final total = CurrencyUtils.roundMoney(grandTotal);
    if (total < 0) {
      return 'Grand total is invalid';
    }

    if (paymentStatus == PaymentStatus.partial) {
      if (paidAmount == null) {
        return 'Enter the paid amount';
      }
      final paid = CurrencyUtils.roundMoney(paidAmount);
      if (paid <= 0) {
        return 'Paid amount must be greater than 0';
      }
      if (paid >= total) {
        return 'For Partial, paid amount must be less than grand total';
      }
    }

    return null;
  }

  /// Payment-only copy. GST totals and line items stay unchanged.
  Bill withPayment(PaymentBreakdown payment) {
    return Bill(
      billId: billId,
      invoiceNo: invoiceNo,
      invoiceDate: invoiceDate,
      partyId: partyId,
      partyName: partyName,
      partyAddress: partyAddress,
      partyState: partyState,
      partyGSTIN: partyGSTIN,
      items: items,
      subtotal: subtotal,
      totalTax: totalTax,
      grandTotal: grandTotal,
      status: status,
      paymentStatus: payment.paymentStatus,
      paidAmount: payment.paidAmount,
      remainingAmount: payment.remainingAmount,
    );
  }

  factory Bill.fromMap(String billId, Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => BillItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <BillItem>[];

    final grandTotal = parseDouble(map['grandTotal']);
    final rawStatus = parseString(map['paymentStatus'], PaymentStatus.unpaid);
    final paymentStatus =
        PaymentStatus.isValid(rawStatus) ? rawStatus : PaymentStatus.unpaid;

    // Legacy bills may omit payment fields — treat as unpaid.
    final hasPaymentFields = map.containsKey('paymentStatus') ||
        map.containsKey('paidAmount') ||
        map.containsKey('remainingAmount');

    final breakdown = hasPaymentFields
        ? resolvePayment(
            paymentStatus: paymentStatus,
            grandTotal: grandTotal,
            paidAmount: parseDouble(map['paidAmount']),
          )
        : resolvePayment(
            paymentStatus: PaymentStatus.unpaid,
            grandTotal: grandTotal,
          );

    return Bill(
      billId: billId,
      invoiceNo: parseString(map['invoiceNo']),
      invoiceDate: parseDate(map['invoiceDate']),
      partyId: parseString(map['partyId']),
      partyName: parseString(map['partyName']),
      partyAddress: parseString(map['partyAddress']),
      partyState: parseString(map['partyState']),
      partyGSTIN: parseString(map['partyGSTIN']),
      items: items,
      subtotal: parseDouble(map['subtotal']),
      totalTax: parseDouble(map['totalTax']),
      grandTotal: grandTotal,
      status: parseString(map['status'], BillStatus.generated),
      paymentStatus: breakdown.paymentStatus,
      paidAmount: breakdown.paidAmount,
      remainingAmount: breakdown.remainingAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'invoiceNo': invoiceNo,
      'invoiceDate': invoiceDate,
      'partyId': partyId,
      'partyName': partyName,
      'partyAddress': partyAddress,
      'partyState': partyState,
      'partyGSTIN': partyGSTIN,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'totalTax': totalTax,
      'grandTotal': grandTotal,
      'status': status,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
    };
  }
}
