import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('parses owner profile', () {
      final user = AppUser.fromMap('u1', {
        'uid': 'u1',
        'name': 'Priya',
        'email': 'owner@shop.com',
        'role': 'owner',
        'shopId': 'shop-1',
      });

      expect(user.isOwner, isTrue);
      expect(user.canManageStaff, isTrue);
      expect(user.canManageShop, isTrue);
      expect(user.shopId, 'shop-1');
    });

    test('staff cannot manage staff', () {
      final user = AppUser.fromMap('u2', {
        'name': 'Ravi',
        'email': 'staff@shop.com',
        'role': 'staff',
        'shopId': 'shop-1',
      });

      expect(user.isStaff, isTrue);
      expect(user.canManageStaff, isFalse);
      expect(user.canManageShop, isFalse);
    });

    test('round-trips toMap', () {
      const user = AppUser(
        uid: 'u3',
        name: 'Asha',
        email: 'a@b.com',
        role: UserRole.owner,
        shopId: 's1',
      );
      final restored = AppUser.fromMap(user.uid, user.toMap());
      expect(restored.email, 'a@b.com');
      expect(restored.role, UserRole.owner);
    });
  });
}
