import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/shop_config.dart';
import 'firebase_service.dart';
import 'live_firestore.dart';
import 'session_service.dart';

class ShopConfigService {
  DocumentReference<Map<String, dynamic>> get _doc {
    final shopId = SessionService.instance.requireShopId();
    return FirebaseService.shopCollection(shopId, Collections.settings)
        .doc(Collections.settingsDocId);
  }

  Future<ShopConfig?> getShopConfig() async {
    final snap = await LiveFirestore.doc(_doc);
    if (!snap.exists || snap.data() == null) return null;
    return ShopConfig.fromMap(snap.data()!);
  }

  /// Returns existing config, or seeds a default for MVP if missing.
  /// Staff can read the default without writing — only the owner may seed.
  Future<ShopConfig> getOrCreateDefault() async {
    final existing = await getShopConfig();
    if (existing != null && existing.state.trim().isNotEmpty) {
      return existing;
    }

    const seeded = ShopConfig(
      shopName: 'My Shop',
      address: '',
      state: 'Maharashtra',
      gstin: '',
    );
    if (SessionService.instance.canManageShop) {
      await _doc.set(seeded.toMap(), SetOptions(merge: true));
    }
    return existing ?? seeded;
  }

  Future<void> saveShopConfig(ShopConfig config) async {
    SessionService.instance.requireShopManager();
    await _doc.set(config.toMap(), SetOptions(merge: true));
  }
}
