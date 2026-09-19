import 'map_helpers.dart';

class BillItem {
  final String productId;
  final String name;
  final String hsnCode;
  final double quantity;
  final double rate;
  final double gstPercent;

  /// rate × quantity (before discount).
  final double grossAmount;

  /// Per-item discount amount (₹), applied before GST.
  final double discount;

  /// grossAmount − discount (GST base).
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
    required this.grossAmount,
    this.discount = 0,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.lineTotal,
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    final quantity = parseDouble(map['quantity']);
    final rate = parseDouble(map['rate']);
    final grossFromRateQty = double.parse((rate * quantity).toStringAsFixed(2));
    final grossAmount = map.containsKey('grossAmount')
        ? parseDouble(map['grossAmount'])
        : grossFromRateQty;
    final discount = parseDouble(map['discount']);
    final taxableAmount = map.containsKey('taxableAmount')
        ? parseDouble(map['taxableAmount'])
        : double.parse((grossAmount - discount).toStringAsFixed(2));

    return BillItem(
      productId: parseString(map['productId']),
      name: parseString(map['name']),
      hsnCode: parseString(map['hsnCode']),
      quantity: quantity,
      rate: rate,
      gstPercent: parseDouble(map['gstPercent']),
      grossAmount: grossAmount,
      discount: discount,
      taxableAmount: taxableAmount,
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
      'grossAmount': grossAmount,
      'discount': discount,
      'taxableAmount': taxableAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'lineTotal': lineTotal,
    };
  }
}
