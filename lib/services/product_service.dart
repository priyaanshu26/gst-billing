import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/map_helpers.dart';
import '../models/product.dart';
import 'firebase_service.dart';
import 'session_service.dart';

class ProductService {
  String get _shopId => SessionService.instance.requireShopId();

  CollectionReference<Map<String, dynamic>> get _collection {
    return FirebaseService.shopCollection(_shopId, Collections.products);
  }

  DocumentReference<Map<String, dynamic>> get _barcodeCounter {
    return FirebaseService.shopCollection(_shopId, Collections.counters)
        .doc(Collections.productBarcodeCounterDocId);
  }

  Stream<List<Product>> watchProducts() {
    return _collection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<Product>> getProducts() async {
    final snapshot = await _collection.orderBy('name').get();
    return snapshot.docs
        .map((doc) => Product.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Product?> getProduct(String productId) async {
    final doc = await _collection.doc(productId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Product.fromMap(doc.id, doc.data()!);
  }

  /// Looks up a product by exact barcode (trimmed). Returns null if none.
  Future<Product?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    final snapshot =
        await _collection.where('barcode', isEqualTo: code).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Product.fromMap(doc.id, doc.data());
  }

  /// Creates a product and assigns the next sequential barcode (100001…).
  /// Does not accept a manual barcode — HSN remains a separate field.
  Future<Product> addProduct({
    required String name,
    String hsnCode = '',
    required double price,
    required double gstPercent,
  }) async {
    SessionService.instance.requireShopManager();
    return FirebaseService.firestore.runTransaction((transaction) async {
      final nextBarcode = await _nextBarcodeInTransaction(transaction);
      final docRef = _collection.doc();
      final product = Product(
        productId: docRef.id,
        name: name.trim(),
        hsnCode: hsnCode.trim(),
        price: price,
        gstPercent: gstPercent,
        barcode: nextBarcode,
      );
      transaction.set(docRef, product.toMap());
      return product;
    });
  }

  /// Updates name / HSN / price / GST. Never changes an existing barcode.
  Future<void> updateProduct(Product product) async {
    SessionService.instance.requireShopManager();
    final updated = product.copyWith(
      name: product.name.trim(),
      hsnCode: product.hsnCode.trim(),
    );
    await _collection.doc(product.productId).update({
      'name': updated.name,
      'hsnCode': updated.hsnCode,
      'price': updated.price,
      'gstPercent': updated.gstPercent,
      // barcode intentionally omitted — assigned only via counter
    });
  }

  /// Assigns a sequential barcode to a legacy product that has none.
  Future<Product> assignBarcodeIfMissing(Product product) async {
    SessionService.instance.requireShopManager();
    if (product.barcode.trim().isNotEmpty) {
      return product;
    }

    return FirebaseService.firestore.runTransaction((transaction) async {
      final ref = _collection.doc(product.productId);
      final snap = await transaction.get(ref);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Product not found');
      }
      final current = Product.fromMap(snap.id, snap.data()!);
      if (current.barcode.trim().isNotEmpty) {
        return current;
      }

      final nextBarcode = await _nextBarcodeInTransaction(transaction);
      transaction.update(ref, {'barcode': nextBarcode});
      return current.copyWith(barcode: nextBarcode);
    });
  }

  Future<String> _nextBarcodeInTransaction(Transaction transaction) async {
    final counterSnap = await transaction.get(_barcodeCounter);
    var current = Collections.productBarcodeSeed;
    if (counterSnap.exists && counterSnap.data() != null) {
      current = parseInt(
        counterSnap.data()!['currentNumber'],
        Collections.productBarcodeSeed,
      );
    }
    final next = current + 1;
    transaction.set(_barcodeCounter, {'currentNumber': next});
    return next.toString();
  }

  Future<void> deleteProduct(String productId) async {
    SessionService.instance.requireShopManager();
    await _collection.doc(productId).delete();
  }

  List<Product> filterProducts(List<Product> products, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(q) ||
          product.hsnCode.toLowerCase().contains(q) ||
          product.barcode.toLowerCase().contains(q) ||
          product.gstPercent.toString().contains(q) ||
          product.price.toString().contains(q);
    }).toList();
  }
}
