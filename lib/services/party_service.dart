import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';
import '../models/party.dart';
import 'firebase_service.dart';
import 'session_service.dart';

class PartyService {
  CollectionReference<Map<String, dynamic>> get _collection {
    final shopId = SessionService.instance.requireShopId();
    return FirebaseService.shopCollection(shopId, Collections.parties);
  }

  Stream<List<Party>> watchParties() {
    return _collection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Party.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<Party>> getParties() async {
    final snapshot = await _collection.orderBy('name').get();
    return snapshot.docs
        .map((doc) => Party.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Party?> getParty(String partyId) async {
    final doc = await _collection.doc(partyId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Party.fromMap(doc.id, doc.data()!);
  }

  Future<String> addParty({
    required String name,
    String mobile = '',
    String address = '',
    required String state,
    String gstin = '',
    String email = '',
  }) async {
    SessionService.instance.requireShopManager();
    final docRef = _collection.doc();
    final party = Party(
      partyId: docRef.id,
      name: name.trim(),
      mobile: mobile.trim(),
      address: address.trim(),
      state: state.trim(),
      gstin: gstin.trim().toUpperCase(),
      email: email.trim(),
    );
    await docRef.set(party.toMap());
    return docRef.id;
  }

  Future<void> updateParty(Party party) async {
    SessionService.instance.requireShopManager();
    await _collection.doc(party.partyId).update(
          party
              .copyWith(
                name: party.name.trim(),
                mobile: party.mobile.trim(),
                address: party.address.trim(),
                state: party.state.trim(),
                gstin: party.gstin.trim().toUpperCase(),
                email: party.email.trim(),
              )
              .toMap(),
        );
  }

  Future<void> deleteParty(String partyId) async {
    SessionService.instance.requireShopManager();
    await _collection.doc(partyId).delete();
  }

  List<Party> filterParties(List<Party> parties, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return parties;
    return parties.where((party) {
      return party.name.toLowerCase().contains(q) ||
          party.mobile.toLowerCase().contains(q) ||
          party.gstin.toLowerCase().contains(q) ||
          party.state.toLowerCase().contains(q) ||
          party.email.toLowerCase().contains(q);
    }).toList();
  }
}
