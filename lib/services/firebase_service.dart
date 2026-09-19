import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;
  static String? initError;

  static bool get isInitialized => _initialized;

  static FirebaseFirestore get firestore {
    _ensureReady();
    return FirebaseFirestore.instance;
  }

  static FirebaseAuth get auth {
    _ensureReady();
    return FirebaseAuth.instance;
  }

  static void _ensureReady() {
    if (!_initialized) {
      throw StateError(
        'Firebase is not initialized. Configure firebase_options.dart '
        'or run flutterfire configure.',
      );
    }
  }

  /// shops/{shopId}
  static DocumentReference<Map<String, dynamic>> shopDoc(String shopId) {
    return firestore.collection('shops').doc(shopId);
  }

  /// shops/{shopId}/{collection}
  static CollectionReference<Map<String, dynamic>> shopCollection(
    String shopId,
    String collection,
  ) {
    return shopDoc(shopId).collection(collection);
  }

  /// Initializes Firebase. Returns true on success.
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      initError = null;
      return true;
    } catch (error, stackTrace) {
      initError = error.toString();
      debugPrint('Firebase init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
      return false;
    }
  }
}
