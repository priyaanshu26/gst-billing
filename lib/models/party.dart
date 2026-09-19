import 'map_helpers.dart';

class Party {
  final String partyId;
  final String name;
  final String mobile;
  final String address;
  final String state;
  final String gstin;
  final String email;

  const Party({
    required this.partyId,
    required this.name,
    this.mobile = '',
    this.address = '',
    required this.state,
    this.gstin = '',
    this.email = '',
  });

  factory Party.fromMap(String partyId, Map<String, dynamic> map) {
    return Party(
      partyId: partyId,
      name: parseString(map['name']),
      mobile: parseString(map['mobile']),
      address: parseString(map['address']),
      state: parseString(map['state']),
      gstin: parseString(map['gstin']),
      email: parseString(map['email']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partyId': partyId,
      'name': name,
      'mobile': mobile,
      'address': address,
      'state': state,
      'gstin': gstin,
      'email': email,
    };
  }

  Party copyWith({
    String? partyId,
    String? name,
    String? mobile,
    String? address,
    String? state,
    String? gstin,
    String? email,
  }) {
    return Party(
      partyId: partyId ?? this.partyId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      state: state ?? this.state,
      gstin: gstin ?? this.gstin,
      email: email ?? this.email,
    );
  }
}
