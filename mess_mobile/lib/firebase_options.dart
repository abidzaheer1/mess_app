// Firebase project: 301 MESS (mess-df58f)
// Generated from Firebase CLI + existing web app config.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyApkF-oW8Mrua84LEpZ02cGZ6vF9eEvjQc',
    appId: '1:588825672161:web:8fcff6b0aa7c5b445ebaa0',
    messagingSenderId: '588825672161',
    projectId: 'mess-df58f',
    authDomain: 'mess-df58f.firebaseapp.com',
    storageBucket: 'mess-df58f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgWaiaak_V7cPJlZs3pwPb0qf7KII8p2M',
    appId: '1:588825672161:android:2b009367cdaa18a85ebaa0',
    messagingSenderId: '588825672161',
    projectId: 'mess-df58f',
    storageBucket: 'mess-df58f.firebasestorage.app',
  );

  // Register iOS in Firebase Console, then run:
  // firebase apps:sdkconfig IOS <app-id> --project=mess-df58f
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyApkF-oW8Mrua84LEpZ02cGZ6vF9eEvjQc',
    appId: '1:588825672161:web:8fcff6b0aa7c5b445ebaa0',
    messagingSenderId: '588825672161',
    projectId: 'mess-df58f',
    storageBucket: 'mess-df58f.firebasestorage.app',
    iosBundleId: 'com.alphamess.mess_mobile',
  );
}
