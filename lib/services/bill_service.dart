import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/invoice_counter.dart';
import '../models/party.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import 'firebase_service.dart';

class DashboardStats {
  final double todaySales;
  final double monthlySales;
  final int todayBillCount;
  final int monthlyBillCount;
  final double totalTax;
  final List<Bill> recentBills;

  const DashboardStats({
    required this.todaySales,
    required this.monthlySales,
    required this.todayBillCount,
    required this.monthlyBillCount,
    required this.totalTax,
    required this.recentBills,
  });
}

class BillService {
  CollectionReference<Map<String, dynamic>> get _bills {
    return FirebaseService.firestore.collection(Collections.bills);
  }

  DocumentReference<Map<String, dynamic>> get _invoiceCounter {
    return FirebaseService.firestore
        .collection(Collections.counters)
        .doc(Collections.invoiceCounterDocId);
  }

  Stream<List<Bill>> watchBills() {
    return _bills.orderBy('invoiceDate', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Bill.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Bill?> getBill(String billId) async {
    final doc = await _bills.doc(billId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Bill.fromMap(doc.id, doc.data()!);
  }

  List<Bill> filterBills(List<Bill> bills, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return bills;
    return bills.where((bill) {
      return bill.invoiceNo.toLowerCase().contains(q) ||
          bill.partyName.toLowerCase().contains(q) ||
          bill.partyGSTIN.toLowerCase().contains(q);
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
    var totalTax = 0.0;

    for (final bill in bills) {
      totalTax += bill.totalTax;
      if (AppDateUtils.isSameDay(bill.invoiceDate, reference)) {
        todaySales += bill.grandTotal;
        todayCount += 1;
      }
      if (AppDateUtils.isSameMonth(bill.invoiceDate, reference)) {
        monthlySales += bill.grandTotal;
        monthlyCount += 1;
      }
    }

    return DashboardStats(
      todaySales: CurrencyUtils.roundMoney(todaySales),
      monthlySales: CurrencyUtils.roundMoney(monthlySales),
      todayBillCount: todayCount,
      monthlyBillCount: monthlyCount,
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
    DateTime? invoiceDate,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Invoice must have at least one item');
    }

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
