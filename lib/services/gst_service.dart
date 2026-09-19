import '../models/bill_item.dart';
import '../models/product.dart';
import '../utils/currency_utils.dart';

/// Result of summing calculated bill lines.
class GstBillCalculation {
  final List<BillItem> items;
  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalTax;
  final double grandTotal;

  const GstBillCalculation({
    required this.items,
    required this.subtotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalTax,
    required this.grandTotal,
  });
}

/// Pure GST math — no Firebase / UI dependencies.
class GstService {
  GstService._();

  static double roundMoney(num value) => CurrencyUtils.roundMoney(value);

  /// Same-state comparison (trim + case-insensitive).
  static bool isSameState(String shopState, String partyState) {
    return shopState.trim().toLowerCase() == partyState.trim().toLowerCase();
  }

  /// taxableAmount = rate * quantity
  static double taxableAmount(double rate, double quantity) {
    return roundMoney(rate * quantity);
  }

  /// Builds one line with CGST/SGST or IGST based on [isIntraState].
  static BillItem calculateLineItem({
    required String productId,
    required String name,
    String hsnCode = '',
    required double quantity,
    required double rate,
    required double gstPercent,
    required bool isIntraState,
  }) {
    final taxable = taxableAmount(rate, quantity);

    late final double cgst;
    late final double sgst;
    late final double igst;

    if (isIntraState) {
      final half = roundMoney(taxable * gstPercent / 2 / 100);
      cgst = half;
      sgst = half;
      igst = 0;
    } else {
      cgst = 0;
      sgst = 0;
      igst = roundMoney(taxable * gstPercent / 100);
    }

    final tax = roundMoney(cgst + sgst + igst);
    final lineTotal = roundMoney(taxable + tax);

    return BillItem(
      productId: productId,
      name: name,
      hsnCode: hsnCode,
      quantity: quantity,
      rate: roundMoney(rate),
      gstPercent: gstPercent,
      taxableAmount: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      lineTotal: lineTotal,
    );
  }

  /// Snapshot a [Product] into a calculated [BillItem].
  static BillItem calculateLineFromProduct({
    required Product product,
    required double quantity,
    required bool isIntraState,
    double? rate,
  }) {
    return calculateLineItem(
      productId: product.productId,
      name: product.name,
      hsnCode: product.hsnCode,
      quantity: quantity,
      rate: rate ?? product.price,
      gstPercent: product.gstPercent,
      isIntraState: isIntraState,
    );
  }

  /// Calculate all lines using shop vs party state.
  static List<BillItem> calculateItems({
    required List<BillItemDraft> drafts,
    required String shopState,
    required String partyState,
  }) {
    final intra = isSameState(shopState, partyState);
    return drafts
        .map(
          (draft) => calculateLineItem(
            productId: draft.productId,
            name: draft.name,
            hsnCode: draft.hsnCode,
            quantity: draft.quantity,
            rate: draft.rate,
            gstPercent: draft.gstPercent,
            isIntraState: intra,
          ),
        )
        .toList();
  }

  /// subtotal, totalTax, grandTotal from calculated lines.
  static GstBillCalculation summarize(List<BillItem> items) {
    var subtotal = 0.0;
    var totalCgst = 0.0;
    var totalSgst = 0.0;
    var totalIgst = 0.0;

    for (final item in items) {
      subtotal += item.taxableAmount;
      totalCgst += item.cgst;
      totalSgst += item.sgst;
      totalIgst += item.igst;
    }

    subtotal = roundMoney(subtotal);
    totalCgst = roundMoney(totalCgst);
    totalSgst = roundMoney(totalSgst);
    totalIgst = roundMoney(totalIgst);
    final totalTax = roundMoney(totalCgst + totalSgst + totalIgst);
    final grandTotal = roundMoney(subtotal + totalTax);

    return GstBillCalculation(
      items: List.unmodifiable(items),
      subtotal: subtotal,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
      totalTax: totalTax,
      grandTotal: grandTotal,
    );
  }

  /// End-to-end: drafts + states → totals.
  static GstBillCalculation calculateBill({
    required List<BillItemDraft> drafts,
    required String shopState,
    required String partyState,
  }) {
    final items = calculateItems(
      drafts: drafts,
      shopState: shopState,
      partyState: partyState,
    );
    return summarize(items);
  }
}

/// Input line before GST is applied (product snapshot + qty/rate).
class BillItemDraft {
  final String productId;
  final String name;
  final String hsnCode;
  final double quantity;
  final double rate;
  final double gstPercent;

  const BillItemDraft({
    required this.productId,
    required this.name,
    this.hsnCode = '',
    required this.quantity,
    required this.rate,
    required this.gstPercent,
  });

  factory BillItemDraft.fromProduct(
    Product product, {
    required double quantity,
    double? rate,
  }) {
    return BillItemDraft(
      productId: product.productId,
      name: product.name,
      hsnCode: product.hsnCode,
      quantity: quantity,
      rate: rate ?? product.price,
      gstPercent: product.gstPercent,
    );
  }
}
