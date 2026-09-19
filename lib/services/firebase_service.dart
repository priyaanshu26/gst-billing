import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;
  static String? initError;

  static bool get isInitialized => _initialized;

  static FirebaseFirestore get firestore {
    if (!_initialized) {
      throw StateError(
        'Firebase is not initialized. Configure firebase_options.dart '
        'or run flutterfire configure.',
      );
    }
    return FirebaseFirestore.instance;
  }

  /// Initializes Firebase. Returns true on success.
  /// App can still launch if init fails (placeholder config).
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
