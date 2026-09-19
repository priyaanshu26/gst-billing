import 'bill_item.dart';
import 'map_helpers.dart';

class BillStatus {
  static const generated = 'generated';
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
  });

  factory Bill.fromMap(String billId, Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => BillItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <BillItem>[];

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
      grandTotal: parseDouble(map['grandTotal']),
      status: parseString(map['status'], BillStatus.generated),
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
    };
  }
}
