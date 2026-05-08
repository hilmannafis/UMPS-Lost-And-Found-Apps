import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Placeholder Firebase config. Replace with values from `flutterfire configure`.
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not set for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQRgLHgmd16cieMtCYvDZX1IojCHfEHH4',
    appId: '1:1055678319524:android:7d52045f099cda335ccf31',
    messagingSenderId: '1055678319524',
    projectId: 'lostandfound-c39bd',
    storageBucket: 'lostandfound-c39bd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQRgLHgmd16cieMtCYvDZX1IojCHfEHH4',
    appId: '1:1055678319524:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '1055678319524',
    projectId: 'lostandfound-c39bd',
    storageBucket: 'lostandfound-c39bd.firebasestorage.app',
    iosBundleId: 'com.example.lostandfound',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDQRgLHgmd16cieMtCYvDZX1IojCHfEHH4',
    appId: '1:1055678319524:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '1055678319524',
    projectId: 'lostandfound-c39bd',
    storageBucket: 'lostandfound-c39bd.firebasestorage.app',
  );
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQRgLHgmd16cieMtCYvDZX1IojCHfEHH4',
    appId: '1:1055678319524:web:7d52045f099cda335ccf31',
    messagingSenderId: '1055678319524',
    projectId: 'lostandfound-c39bd',
    storageBucket: 'lostandfound-c39bd.firebasestorage.app',
  );
  
  static const FirebaseOptions windows = android;
  static const FirebaseOptions linux = android;
}

