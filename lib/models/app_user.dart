import 'map_helpers.dart';

class UserRole {
  static const owner = 'owner';
  static const staff = 'staff';

  static const List<String> values = [owner, staff];

  static String label(String role) {
    switch (role) {
      case owner:
        return 'Owner';
      case staff:
        return 'Staff';
      default:
        return role;
    }
  }

  static bool isValid(String role) => values.contains(role);
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String shopId;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.shopId,
  });

  bool get isOwner => role == UserRole.owner;
  bool get isStaff => role == UserRole.staff;
  bool get canManageStaff => isOwner;

  /// Owner can add/edit parties, products, barcodes, and shop settings.
  /// Staff may only view those and create / download / print invoices.
  bool get canManageShop => isOwner;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final role = parseString(map['role'], UserRole.staff);
    return AppUser(
      uid: uid,
      name: parseString(map['name']),
      email: parseString(map['email']),
      role: UserRole.isValid(role) ? role : UserRole.staff,
      shopId: parseString(map['shopId']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'shopId': shopId,
    };
  }
}
