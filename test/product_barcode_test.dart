import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/constants/collections.dart';
import 'package:gst_billing/models/product.dart';
import 'package:gst_billing/services/product_service.dart';

void main() {
  group('Product barcode field', () {
    test('round-trips barcode through toMap/fromMap', () {
      const product = Product(
        productId: 'p1',
        name: 'Laptop',
        hsnCode: '8471',
        price: 50000,
        gstPercent: 18,
        barcode: '100001',
      );

      final restored = Product.fromMap(product.productId, product.toMap());
      expect(restored.barcode, '100001');
      expect(restored.hsnCode, '8471');
      expect(restored.name, 'Laptop');
    });

    test('legacy products without barcode default to empty', () {
      final restored = Product.fromMap('legacy', {
        'name': 'Old Item',
        'hsnCode': '8471',
        'price': 50,
        'gstPercent': 12,
      });
      expect(restored.barcode, '');
      expect(restored.hsnCode, '8471');
    });

    test('HSN and barcode are independent fields', () {
      const laptop = Product(
        productId: '1',
        name: 'Laptop',
        hsnCode: '8471',
        price: 50000,
        gstPercent: 18,
        barcode: '100001',
      );
      const mouse = Product(
        productId: '2',
        name: 'Mouse',
        hsnCode: '8471',
        price: 800,
        gstPercent: 18,
        barcode: '100002',
      );

      expect(laptop.hsnCode, mouse.hsnCode);
      expect(laptop.barcode, isNot(mouse.barcode));
    });
  });

  group('Product barcode counter seed', () {
    test('first barcode after seed is 100001', () {
      expect(Collections.productBarcodeSeed, 100000);
      expect((Collections.productBarcodeSeed + 1).toString(), '100001');
    });
  });

  group('ProductService.filterProducts', () {
    final service = ProductService();
    final products = [
      const Product(
        productId: '1',
        name: 'Laptop',
        hsnCode: '8471',
        price: 50000,
        gstPercent: 18,
        barcode: '100001',
      ),
      const Product(
        productId: '2',
        name: 'Mouse',
        hsnCode: '8471',
        price: 800,
        gstPercent: 18,
        barcode: '100002',
      ),
    ];

    test('matches barcode in search', () {
      final result = service.filterProducts(products, '100002');
      expect(result.length, 1);
      expect(result.first.name, 'Mouse');
    });

    test('HSN search can match multiple products', () {
      final result = service.filterProducts(products, '8471');
      expect(result.length, 2);
    });
  });
}
