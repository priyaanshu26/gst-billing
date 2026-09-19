import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// Holds the signed-in shop user for shop-scoped Firestore access.
class SessionService extends ChangeNotifier {
  SessionService._();
  static final SessionService instance = SessionService._();

  AppUser? _user;

  AppUser? get currentUser => _user;
  String? get shopId => _user?.shopId;
  bool get isSignedIn => _user != null;
  bool get isOwner => _user?.isOwner ?? false;
  bool get canManageStaff => _user?.canManageStaff ?? false;
  bool get canManageShop => _user?.canManageShop ?? false;

  void requireShopManager() {
    if (!canManageShop) {
      throw StateError(
        'Only the shop owner can change parties, products, or shop settings.',
      );
    }
  }

  String requireShopId() {
    final id = shopId;
    if (id == null || id.isEmpty) {
      throw StateError('No shop is associated with the current user.');
    }
    return id;
  }

  AppUser requireUser() {
    final user = _user;
    if (user == null) {
      throw StateError('Not signed in.');
    }
    return user;
  }

  void setUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  void clear() => setUser(null);
}
