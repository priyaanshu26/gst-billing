import 'package:cloud_firestore/cloud_firestore.dart';

/// Server-first Firestore reads so navigation always shows live data.
/// Falls back to the default source (cache / server) if the shop is offline.
class LiveFirestore {
  LiveFirestore._();

  static const _server = GetOptions(source: Source.server);

  static Future<QuerySnapshot<Map<String, dynamic>>> query(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get(_server);
    } catch (_) {
      return await query.get();
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> doc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get(_server);
    } catch (_) {
      return await ref.get();
    }
  }
}
