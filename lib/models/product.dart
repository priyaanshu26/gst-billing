import 'map_helpers.dart';

class Product {
  final String productId;
  final String name;
  final String hsnCode;
  final double price;
  final double gstPercent;

  const Product({
    required this.productId,
    required this.name,
    this.hsnCode = '',
    required this.price,
    required this.gstPercent,
  });

  factory Product.fromMap(String productId, Map<String, dynamic> map) {
    return Product(
      productId: productId,
      name: parseString(map['name']),
      hsnCode: parseString(map['hsnCode']),
      price: parseDouble(map['price']),
      gstPercent: parseDouble(map['gstPercent']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'hsnCode': hsnCode,
      'price': price,
      'gstPercent': gstPercent,
    };
  }

  Product copyWith({
    String? productId,
    String? name,
    String? hsnCode,
    double? price,
    double? gstPercent,
  }) {
    return Product(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      hsnCode: hsnCode ?? this.hsnCode,
      price: price ?? this.price,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}
