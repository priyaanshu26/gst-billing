import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/invoice_counter.dart';
import '../models/party.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import 'firebase_service.dart';
import 'live_firestore.dart';
import 'session_service.dart';

class DashboardStats {
  final double todaySales;
  final double monthlySales;
  final int todayBillCount;
  final int monthlyBillCount;
  final double todayTax;
  final double monthlyTax;
  final double totalTax;
  final List<Bill> recentBills;

  const DashboardStats({
    required this.todaySales,
    required this.monthlySales,
    required this.todayBillCount,
    required this.monthlyBillCount,
    required this.todayTax,
    required this.monthlyTax,
    required this.totalTax,
    required this.recentBills,
  });
}

class BillService {
  String get _shopId => SessionService.instance.requireShopId();

  CollectionReference<Map<String, dynamic>> get _bills {
    return FirebaseService.shopCollection(_shopId, Collections.bills);
  }

  DocumentReference<Map<String, dynamic>> get _invoiceCounter {
    return FirebaseService.shopCollection(_shopId, Collections.counters)
        .doc(Collections.invoiceCounterDocId);
  }

  /// Newest first. Sorted in memory so History does not depend on a Firestore
  /// composite/single-field index, and one malformed bill cannot blank the page.
  Stream<List<Bill>> watchBills() {
    return _bills.snapshots().map((snapshot) => _parseBills(snapshot.docs));
  }

  Future<List<Bill>> getBills() async {
    final snapshot = await LiveFirestore.query(_bills);
    return _parseBills(snapshot.docs);
  }

  /// Bills for one party, newest first. Sorted in memory so Firestore does not
  /// need a composite index on (partyId, invoiceDate).
  Stream<List<Bill>> watchPartyBills(String partyId) {
    return _bills
        .where('partyId', isEqualTo: partyId)
        .snapshots()
        .map((snapshot) => _parseBills(snapshot.docs));
  }

  Future<List<Bill>> getPartyBills(String partyId) async {
    final snapshot = await LiveFirestore.query(
      _bills.where('partyId', isEqualTo: partyId),
    );
    return _parseBills(snapshot.docs);
  }

  Future<Bill?> getBill(String billId) async {
    final doc = await LiveFirestore.doc(_bills.doc(billId));
    if (!doc.exists || doc.data() == null) return null;
    return Bill.fromMap(doc.id, doc.data()!);
  }

  List<Bill> _parseBills(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final bills = <Bill>[];
    for (final doc in docs) {
      try {
        bills.add(Bill.fromMap(doc.id, doc.data()));
      } catch (_) {
        // Skip unreadable documents so the rest of history still loads.
      }
    }
    bills.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return bills;
  }

  /// Text search on invoice no / party / GSTIN, plus an inclusive date range.
  List<Bill> filterBills(
    List<Bill> bills,
    String query, {
    DateTime? from,
    DateTime? to,
  }) {
    final q = query.trim().toLowerCase();
    final start = from == null ? null : AppDateUtils.startOfDay(from);
    final end = to == null ? null : AppDateUtils.endOfDay(to);

    return bills.where((bill) {
      if (q.isNotEmpty) {
        final matchesText = bill.invoiceNo.toLowerCase().contains(q) ||
            bill.partyName.toLowerCase().contains(q) ||
            bill.partyGSTIN.toLowerCase().contains(q);
        if (!matchesText) return false;
      }
      if (start != null && bill.invoiceDate.isBefore(start)) return false;
      if (end != null && bill.invoiceDate.isAfter(end)) return false;
      return true;
    }).toList();
  }

  DashboardStats buildDashboardStats(
    List<Bill> bills, {
    DateTime? now,
    int recentLimit = 5,
  }) {
    final reference = now ?? DateTime.now();
    var todaySales = 0.0;
    var monthlySales = 0.0;
    var todayCount = 0;
    var monthlyCount = 0;
    var todayTax = 0.0;
    var monthlyTax = 0.0;
    var totalTax = 0.0;

    for (final bill in bills) {
      totalTax += bill.totalTax;
      if (AppDateUtils.isSameDay(bill.invoiceDate, reference)) {
        todaySales += bill.grandTotal;
        todayTax += bill.totalTax;
        todayCount += 1;
      }
      if (AppDateUtils.isSameMonth(bill.invoiceDate, reference)) {
        monthlySales += bill.grandTotal;
        monthlyTax += bill.totalTax;
        monthlyCount += 1;
      }
    }

    return DashboardStats(
      todaySales: CurrencyUtils.roundMoney(todaySales),
      monthlySales: CurrencyUtils.roundMoney(monthlySales),
      todayBillCount: todayCount,
      monthlyBillCount: monthlyCount,
      todayTax: CurrencyUtils.roundMoney(todayTax),
      monthlyTax: CurrencyUtils.roundMoney(monthlyTax),
      totalTax: CurrencyUtils.roundMoney(totalTax),
      recentBills: bills.take(recentLimit).toList(),
    );
  }

  /// Creates a read-only bill. Invoice number is assigned inside a transaction.
  Future<Bill> createBill({
    required Party party,
    required List<BillItem> items,
    required double subtotal,
    required double totalTax,
    required double grandTotal,
    String paymentStatus = PaymentStatus.unpaid,
    double? paidAmount,
    DateTime? invoiceDate,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Invoice must have at least one item');
    }

    final paymentError = Bill.validatePayment(
      paymentStatus: paymentStatus,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
    );
    if (paymentError != null) {
      throw ArgumentError(paymentError);
    }

    final payment = Bill.resolvePayment(
      paymentStatus: paymentStatus,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
    );

    final date = invoiceDate ?? DateTime.now();

    return FirebaseService.firestore.runTransaction((transaction) async {
      final counterSnap = await transaction.get(_invoiceCounter);

      var counter = const InvoiceCounter();
      if (counterSnap.exists && counterSnap.data() != null) {
        counter = InvoiceCounter.fromMap(counterSnap.data()!);
      }

      final nextNumber = counter.lastNumber + 1;
      final invoiceNo = counter.formatInvoiceNo(nextNumber);
      final billRef = _bills.doc();

      final bill = Bill(
        billId: billRef.id,
        invoiceNo: invoiceNo,
        invoiceDate: date,
        partyId: party.partyId,
        partyName: party.name,
        partyAddress: party.address,
        partyState: party.state,
        partyGSTIN: party.gstin,
        items: items,
        subtotal: subtotal,
        totalTax: totalTax,
        grandTotal: grandTotal,
        status: BillStatus.generated,
        paymentStatus: payment.paymentStatus,
        paidAmount: payment.paidAmount,
        remainingAmount: payment.remainingAmount,
      );

      transaction.set(
        _invoiceCounter,
        InvoiceCounter(
          lastNumber: nextNumber,
          prefix: counter.prefix,
        ).toMap(),
      );
      transaction.set(billRef, bill.toMap());

      return bill;
    });
  }
}
