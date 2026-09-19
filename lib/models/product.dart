import 'map_helpers.dart';

class Product {
  final String productId;
  final String name;
  final String hsnCode;
  final double price;
  final double gstPercent;

  /// Scannable product identifier (auto-generated sequential, e.g. 100001).
  /// Independent from [hsnCode], which is GST classification only.
  final String barcode;

  const Product({
    required this.productId,
    required this.name,
    this.hsnCode = '',
    required this.price,
    required this.gstPercent,
    this.barcode = '',
  });

  factory Product.fromMap(String productId, Map<String, dynamic> map) {
    return Product(
      productId: productId,
      name: parseString(map['name']),
      hsnCode: parseString(map['hsnCode']),
      price: parseDouble(map['price']),
      gstPercent: parseDouble(map['gstPercent']),
      barcode: parseString(map['barcode']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'hsnCode': hsnCode,
      'price': price,
      'gstPercent': gstPercent,
      'barcode': barcode,
    };
  }

  Product copyWith({
    String? productId,
    String? name,
    String? hsnCode,
    double? price,
    double? gstPercent,
    String? barcode,
  }) {
    return Product(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      hsnCode: hsnCode ?? this.hsnCode,
      price: price ?? this.price,
      gstPercent: gstPercent ?? this.gstPercent,
      barcode: barcode ?? this.barcode,
    );
  }
}
