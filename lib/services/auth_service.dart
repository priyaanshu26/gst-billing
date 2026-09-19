import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;

import '../constants/collections.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/shop_config.dart';
import 'firebase_service.dart';
import 'live_firestore.dart';
import 'session_service.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseService.auth;
  FirebaseFirestore get _db => FirebaseService.firestore;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Collections.users);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get firebaseUser => _auth.currentUser;

  Future<AppUser?> loadCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      SessionService.instance.clear();
      return null;
    }
    final profile = await getUserProfile(user.uid);
    SessionService.instance.setUser(profile);
    return profile;
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final snap = await LiveFirestore.doc(_users.doc(uid));
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromMap(snap.id, snap.data()!);
  }

  Stream<AppUser?> watchSession() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        SessionService.instance.clear();
        yield null;
        continue;
      }
      try {
        final profile = await getUserProfile(user.uid);
        if (profile == null || profile.shopId.isEmpty) {
          await _auth.signOut();
          SessionService.instance.clear();
          yield null;
          continue;
        }
        SessionService.instance.setUser(profile);
        yield profile;
      } catch (_) {
        SessionService.instance.clear();
        yield null;
      }
    }
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) {
      throw StateError('Sign-in failed');
    }
    final profile = await getUserProfile(uid);
    if (profile == null) {
      await _auth.signOut();
      throw StateError(
        'No user profile found. Ask your shop owner to add you as staff, '
        'or register a new shop as owner.',
      );
    }
    SessionService.instance.setUser(profile);
    return profile;
  }

  /// Creates a new shop + OWNER account via Firebase Auth email/password.
  Future<AppUser> registerOwner({
    required String name,
    required String email,
    required String password,
    required String shopName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) {
      throw StateError('Could not create account');
    }

    try {
      await cred.user!.updateDisplayName(name.trim());
    } catch (_) {
      // Display name is optional.
    }

    final shopRef = _db.collection(Collections.shops).doc();
    final shopId = shopRef.id;

    final profile = AppUser(
      uid: uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: UserRole.owner,
      shopId: shopId,
    );

    final batch = _db.batch();
    batch.set(shopRef, {
      'shopId': shopId,
      'shopName': shopName.trim(),
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_users.doc(uid), profile.toMap());
    batch.set(
      shopRef.collection(Collections.settings).doc(Collections.settingsDocId),
      ShopConfig(
        shopName: shopName.trim(),
        address: '',
        state: 'Maharashtra',
        gstin: '',
        email: email.trim().toLowerCase(),
      ).toMap(),
    );
    await batch.commit();

    SessionService.instance.setUser(profile);
    return profile;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    SessionService.instance.clear();
  }

  /// OWNER-only: create a STAFF Firebase Auth user without switching session.
  Future<AppUser> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    final owner = SessionService.instance.requireUser();
    if (!owner.canManageStaff) {
      throw StateError('Only the shop owner can manage staff');
    }

    const secondaryName = 'StaffCreate';
    firebase_core.FirebaseApp secondaryApp;
    try {
      secondaryApp = firebase_core.Firebase.app(secondaryName);
    } catch (_) {
      secondaryApp = await firebase_core.Firebase.initializeApp(
        name: secondaryName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('Could not create staff account');
      }

      final staff = AppUser(
        uid: uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: UserRole.staff,
        shopId: owner.shopId,
      );
      await _users.doc(uid).set(staff.toMap());
      return staff;
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
    }
  }

  Stream<List<AppUser>> watchShopUsers(String shopId) {
    return _users
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snap) => _mapShopUsers(snap.docs));
  }

  Future<List<AppUser>> getShopUsers(String shopId) async {
    final snap = await LiveFirestore.query(
      _users.where('shopId', isEqualTo: shopId),
    );
    return _mapShopUsers(snap.docs);
  }

  List<AppUser> _mapShopUsers(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Future<void> deleteStaff(String uid) async {
    final owner = SessionService.instance.requireUser();
    if (!owner.canManageStaff) {
      throw StateError('Only the shop owner can manage staff');
    }
    if (uid == owner.uid) {
      throw StateError('Cannot remove the signed-in owner');
    }

    final profile = await getUserProfile(uid);
    if (profile == null) return;
    if (profile.shopId != owner.shopId) {
      throw StateError('Staff belongs to another shop');
    }
    if (profile.isOwner) {
      throw StateError('Cannot remove an owner from the app');
    }

    await _users.doc(uid).delete();
  }

  String describeAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password';
        case 'email-already-in-use':
          return 'An account already exists for that email';
        case 'weak-password':
          return 'Password must be at least 6 characters';
        case 'too-many-requests':
          return 'Too many attempts. Try again later';
        case 'network-request-failed':
          return 'Network error. Check your connection';
        default:
          return error.message ?? error.code;
      }
    }
    return error.toString();
  }
}
