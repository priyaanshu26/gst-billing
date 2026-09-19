import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/shop_config.dart';
import 'firebase_service.dart';

class ShopConfigService {
  DocumentReference<Map<String, dynamic>> get _doc {
    return FirebaseService.firestore
        .collection(Collections.shopConfig)
        .doc(Collections.shopConfigDocId);
  }

  Future<ShopConfig?> getShopConfig() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data() == null) return null;
    return ShopConfig.fromMap(snap.data()!);
  }

  /// Returns existing config, or seeds a default for MVP if missing.
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
    await _doc.set(seeded.toMap(), SetOptions(merge: true));
    return seeded;
  }

  Future<void> saveShopConfig(ShopConfig config) async {
    await _doc.set(config.toMap(), SetOptions(merge: true));
  }
}
