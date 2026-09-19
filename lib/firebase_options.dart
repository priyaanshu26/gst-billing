// File generated for GST Billing MVP.
// Replace these placeholder values by running:
//   flutterfire configure
// Or paste values from your Firebase console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with real Firebase project values.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD1poklc1YHwitW4TvC7pB5YEV9dCADN68',
    appId: '1:220168322379:web:f3a29229e49076a24cfcce',
    messagingSenderId: '220168322379',
    projectId: 'gst-billing-a8c12',
    authDomain: 'gst-billing-a8c12.firebaseapp.com',
    storageBucket: 'gst-billing-a8c12.firebasestorage.app',
    measurementId: 'G-G2REFQJSQ3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZ4A398xdnUV-D4iUYVAsAWWqFIPyx2RQ',
    appId: '1:220168322379:android:3d915fc4e9d2feda4cfcce',
    messagingSenderId: '220168322379',
    projectId: 'gst-billing-a8c12',
    storageBucket: 'gst-billing-a8c12.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDBnjzCN6eRxIwH9Tq_2iUyVC67pHml9Vk',
    appId: '1:220168322379:ios:1a5ddcd9f3fb930a4cfcce',
    messagingSenderId: '220168322379',
    projectId: 'gst-billing-a8c12',
    storageBucket: 'gst-billing-a8c12.firebasestorage.app',
    iosBundleId: 'com.gstbilling.gstBilling',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'gst-billing-mvp',
    storageBucket: 'gst-billing-mvp.appspot.com',
    iosBundleId: 'com.gstbilling.gstBilling',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD1poklc1YHwitW4TvC7pB5YEV9dCADN68',
    appId: '1:220168322379:web:b1a34fae2e1779724cfcce',
    messagingSenderId: '220168322379',
    projectId: 'gst-billing-a8c12',
    authDomain: 'gst-billing-a8c12.firebaseapp.com',
    storageBucket: 'gst-billing-a8c12.firebasestorage.app',
    measurementId: 'G-1B3Z9K7JPP',
  );
}
