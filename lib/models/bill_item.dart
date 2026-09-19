import 'map_helpers.dart';

class BillItem {
  final String productId;
  final String name;
  final String hsnCode;
  final double quantity;
  final double rate;
  final double gstPercent;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double lineTotal;

  const BillItem({
    required this.productId,
    required this.name,
    this.hsnCode = '',
    required this.quantity,
    required this.rate,
    required this.gstPercent,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.lineTotal,
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      productId: parseString(map['productId']),
      name: parseString(map['name']),
      hsnCode: parseString(map['hsnCode']),
      quantity: parseDouble(map['quantity']),
      rate: parseDouble(map['rate']),
      gstPercent: parseDouble(map['gstPercent']),
      taxableAmount: parseDouble(map['taxableAmount']),
      cgst: parseDouble(map['cgst']),
      sgst: parseDouble(map['sgst']),
      igst: parseDouble(map['igst']),
      lineTotal: parseDouble(map['lineTotal']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'rate': rate,
      'gstPercent': gstPercent,
      'taxableAmount': taxableAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'lineTotal': lineTotal,
    };
  }
}
