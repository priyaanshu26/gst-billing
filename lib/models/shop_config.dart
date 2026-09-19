import 'map_helpers.dart';

class ShopConfig {
  final String shopName;
  final String address;
  final String state;
  final String gstin;
  final String mobile;
  final String email;

  const ShopConfig({
    required this.shopName,
    required this.address,
    required this.state,
    required this.gstin,
    this.mobile = '',
    this.email = '',
  });

  factory ShopConfig.fromMap(Map<String, dynamic> map) {
    return ShopConfig(
      shopName: parseString(map['shopName']),
      address: parseString(map['address']),
      state: parseString(map['state']),
      gstin: parseString(map['gstin']),
      mobile: parseString(map['mobile']),
      email: parseString(map['email']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'address': address,
      'state': state,
      'gstin': gstin,
      'mobile': mobile,
      'email': email,
    };
  }

  ShopConfig copyWith({
    String? shopName,
    String? address,
    String? state,
    String? gstin,
    String? mobile,
    String? email,
  }) {
    return ShopConfig(
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      state: state ?? this.state,
      gstin: gstin ?? this.gstin,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
    );
  }
}
