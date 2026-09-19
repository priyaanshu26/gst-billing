import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/models/product.dart';
import 'package:gst_billing/services/gst_service.dart';

void main() {
  group('GstService.isSameState', () {
    test('matches ignoring case and spaces', () {
      expect(GstService.isSameState('Maharashtra', 'maharashtra'), isTrue);
      expect(GstService.isSameState(' Delhi ', 'Delhi'), isTrue);
      expect(GstService.isSameState('Gujarat', 'Maharashtra'), isFalse);
    });
  });

  group('intra-state CGST + SGST', () {
    test('splits 18% GST equally', () {
      final item = GstService.calculateLineItem(
        productId: 'p1',
        name: 'Widget',
        hsnCode: '1234',
        quantity: 2,
        rate: 100,
        gstPercent: 18,
        isIntraState: true,
      );

      expect(item.taxableAmount, 200);
      expect(item.cgst, 18);
      expect(item.sgst, 18);
      expect(item.igst, 0);
      expect(item.lineTotal, 236);
    });

    test('0% GST produces no tax', () {
      final item = GstService.calculateLineItem(
        productId: 'p1',
        name: 'Exempt',
        quantity: 1,
        rate: 50,
        gstPercent: 0,
        isIntraState: true,
      );

      expect(item.taxableAmount, 50);
      expect(item.cgst, 0);
      expect(item.sgst, 0);
      expect(item.igst, 0);
      expect(item.lineTotal, 50);
    });
  });

  group('inter-state IGST', () {
    test('applies full GST as IGST', () {
      final item = GstService.calculateLineItem(
        productId: 'p1',
        name: 'Widget',
        quantity: 2,
        rate: 100,
        gstPercent: 18,
        isIntraState: false,
      );

      expect(item.taxableAmount, 200);
      expect(item.cgst, 0);
      expect(item.sgst, 0);
      expect(item.igst, 36);
      expect(item.lineTotal, 236);
    });
  });

  group('bill totals', () {
    test('sums subtotal, tax and grand total for same state', () {
      final result = GstService.calculateBill(
        shopState: 'Maharashtra',
        partyState: 'Maharashtra',
        drafts: const [
          BillItemDraft(
            productId: 'a',
            name: 'A',
            quantity: 1,
            rate: 100,
            gstPercent: 18,
          ),
          BillItemDraft(
            productId: 'b',
            name: 'B',
            quantity: 2,
            rate: 50,
            gstPercent: 12,
          ),
        ],
      );

      // Line A: 100 + 9 + 9 = 118
      // Line B: 100 + 6 + 6 = 112
      expect(result.subtotal, 200);
      expect(result.totalCgst, 15);
      expect(result.totalSgst, 15);
      expect(result.totalIgst, 0);
      expect(result.totalTax, 30);
      expect(result.grandTotal, 230);
      expect(result.items.length, 2);
    });

    test('sums IGST for interstate bill', () {
      final result = GstService.calculateBill(
        shopState: 'Maharashtra',
        partyState: 'Karnataka',
        drafts: const [
          BillItemDraft(
            productId: 'a',
            name: 'A',
            quantity: 1,
            rate: 100,
            gstPercent: 18,
          ),
          BillItemDraft(
            productId: 'b',
            name: 'B',
            quantity: 1,
            rate: 200,
            gstPercent: 5,
          ),
        ],
      );

      expect(result.subtotal, 300);
      expect(result.totalCgst, 0);
      expect(result.totalSgst, 0);
      expect(result.totalIgst, 28); // 18 + 10
      expect(result.totalTax, 28);
      expect(result.grandTotal, 328);
    });
  });

  group('product snapshot helpers', () {
    test('calculateLineFromProduct uses product fields', () {
      const product = Product(
        productId: 'prod-1',
        name: 'Cable',
        hsnCode: '8544',
        price: 120,
        gstPercent: 18,
      );

      final item = GstService.calculateLineFromProduct(
        product: product,
        quantity: 3,
        isIntraState: false,
      );

      expect(item.productId, 'prod-1');
      expect(item.name, 'Cable');
      expect(item.hsnCode, '8544');
      expect(item.rate, 120);
      expect(item.taxableAmount, 360);
      expect(item.igst, 64.8);
      expect(item.lineTotal, 424.8);
    });

    test('BillItemDraft.fromProduct builds draft', () {
      const product = Product(
        productId: 'prod-2',
        name: 'Switch',
        hsnCode: '8536',
        price: 80,
        gstPercent: 12,
      );

      final draft = BillItemDraft.fromProduct(product, quantity: 2);
      expect(draft.productId, 'prod-2');
      expect(draft.quantity, 2);
      expect(draft.rate, 80);
      expect(draft.gstPercent, 12);
    });
  });

  group('rounding', () {
    test('rounds money to 2 decimals', () {
      final item = GstService.calculateLineItem(
        productId: 'p1',
        name: 'Odd',
        quantity: 3,
        rate: 33.33,
        gstPercent: 18,
        isIntraState: true,
      );

      expect(item.taxableAmount, 99.99);
      // half of 99.99 * 18% = 8.9991 -> 9.00 each after round
      expect(item.cgst, 9.0);
      expect(item.sgst, 9.0);
      expect(item.lineTotal, 117.99);
    });
  });
}
