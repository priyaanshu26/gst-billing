import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/product.dart';
import 'firebase_service.dart';

class ProductService {
  CollectionReference<Map<String, dynamic>> get _collection {
    return FirebaseService.firestore.collection(Collections.products);
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

  Future<String> addProduct({
    required String name,
    String hsnCode = '',
    required double price,
    required double gstPercent,
  }) async {
    final docRef = _collection.doc();
    final product = Product(
      productId: docRef.id,
      name: name.trim(),
      hsnCode: hsnCode.trim(),
      price: price,
      gstPercent: gstPercent,
    );
    await docRef.set(product.toMap());
    return docRef.id;
  }

  Future<void> updateProduct(Product product) async {
    final updated = product.copyWith(
      name: product.name.trim(),
      hsnCode: product.hsnCode.trim(),
    );
    await _collection.doc(product.productId).update(updated.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _collection.doc(productId).delete();
  }

  List<Product> filterProducts(List<Product> products, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(q) ||
          product.hsnCode.toLowerCase().contains(q) ||
          product.gstPercent.toString().contains(q) ||
          product.price.toString().contains(q);
    }).toList();
  }
}
