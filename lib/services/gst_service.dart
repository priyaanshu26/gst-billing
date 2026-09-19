import '../models/bill_item.dart';
import '../models/product.dart';
import '../utils/currency_utils.dart';

/// Result of summing calculated bill lines.
class GstBillCalculation {
  final List<BillItem> items;
  final double totalGross;
  final double totalDiscount;
  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalTax;
  final double grandTotal;

  const GstBillCalculation({
    required this.items,
    required this.totalGross,
    required this.totalDiscount,
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

  /// grossAmount = rate × quantity
  static double grossAmount(double rate, double quantity) {
    return roundMoney(rate * quantity);
  }

  /// Returns an error message if discount is invalid, otherwise null.
  static String? validateDiscount(double discount, double grossAmount) {
    if (discount < 0) {
      return 'Discount cannot be negative';
    }
    if (discount > grossAmount) {
      return 'Discount cannot exceed item amount';
    }
    return null;
  }

  /// Builds one line with CGST/SGST or IGST based on [isIntraState].
  ///
  /// GST is always calculated on (grossAmount − discount), never on gross alone.
  static BillItem calculateLineItem({
    required String productId,
    required String name,
    String hsnCode = '',
    required double quantity,
    required double rate,
    required double gstPercent,
    required bool isIntraState,
    double discount = 0,
  }) {
    final gross = grossAmount(rate, quantity);
    final disc = roundMoney(discount);

    final validationError = validateDiscount(disc, gross);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final taxable = roundMoney(gross - disc);

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
      grossAmount: gross,
      discount: disc,
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
    double discount = 0,
  }) {
    return calculateLineItem(
      productId: product.productId,
      name: product.name,
      hsnCode: product.hsnCode,
      quantity: quantity,
      rate: rate ?? product.price,
      gstPercent: product.gstPercent,
      isIntraState: isIntraState,
      discount: discount,
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
            discount: draft.discount,
          ),
        )
        .toList();
  }

  /// subtotal (= sum of taxable after discount), totalTax, grandTotal.
  static GstBillCalculation summarize(List<BillItem> items) {
    var totalGross = 0.0;
    var totalDiscount = 0.0;
    var subtotal = 0.0;
    var totalCgst = 0.0;
    var totalSgst = 0.0;
    var totalIgst = 0.0;

    for (final item in items) {
      totalGross += item.grossAmount;
      totalDiscount += item.discount;
      subtotal += item.taxableAmount;
      totalCgst += item.cgst;
      totalSgst += item.sgst;
      totalIgst += item.igst;
    }

    totalGross = roundMoney(totalGross);
    totalDiscount = roundMoney(totalDiscount);
    subtotal = roundMoney(subtotal);
    totalCgst = roundMoney(totalCgst);
    totalSgst = roundMoney(totalSgst);
    totalIgst = roundMoney(totalIgst);
    final totalTax = roundMoney(totalCgst + totalSgst + totalIgst);
    final grandTotal = roundMoney(subtotal + totalTax);

    return GstBillCalculation(
      items: List.unmodifiable(items),
      totalGross: totalGross,
      totalDiscount: totalDiscount,
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

/// Input line before GST is applied (product snapshot + qty/rate/discount).
class BillItemDraft {
  final String productId;
  final String name;
  final String hsnCode;
  final double quantity;
  final double rate;
  final double gstPercent;
  final double discount;

  const BillItemDraft({
    required this.productId,
    required this.name,
    this.hsnCode = '',
    required this.quantity,
    required this.rate,
    required this.gstPercent,
    this.discount = 0,
  });

  factory BillItemDraft.fromProduct(
    Product product, {
    required double quantity,
    double? rate,
    double discount = 0,
  }) {
    return BillItemDraft(
      productId: product.productId,
      name: product.name,
      hsnCode: product.hsnCode,
      quantity: quantity,
      rate: rate ?? product.price,
      gstPercent: product.gstPercent,
      discount: discount,
    );
  }
}
