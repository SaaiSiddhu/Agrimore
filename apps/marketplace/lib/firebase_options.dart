// Firebase options for Agrimore project
// Project: agrimore-66a4e

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not supported');
      default:
        throw UnsupportedError('Unknown platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc',
    appId: '1:1082819024270:web:fa2a015928e81bf1e640df',
    messagingSenderId: '1082819024270',
    projectId: 'agrimore-66a4e',
    authDomain: 'agrimore-66a4e.firebaseapp.com',
    databaseURL: 'https://agrimore-66a4e-default-rtdb.firebaseio.com',
    storageBucket: 'agrimore-66a4e.firebasestorage.app',
    measurementId: 'G-73B1F06XC3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlbhaEl3Hz60iYVL7qtSBPx3Clx6SV7gg',
    appId: '1:1082819024270:android:5d471e0e9d336cb2e640df',
    messagingSenderId: '1082819024270',
    projectId: 'agrimore-66a4e',
    databaseURL: 'https://agrimore-66a4e-default-rtdb.firebaseio.com',
    storageBucket: 'agrimore-66a4e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCk7FG8B7JjccxCUHe_2j35r9pk-lh08Gc',
    appId: '1:1082819024270:ios:6dc2b8726e003004e640df',
    messagingSenderId: '1082819024270',
    projectId: 'agrimore-66a4e',
    databaseURL: 'https://agrimore-66a4e-default-rtdb.firebaseio.com',
    storageBucket: 'agrimore-66a4e.firebasestorage.app',
    iosBundleId: 'com.customer.agrimore',
    iosClientId:
        '1082819024270-cvqkdm8b6olss06q8qfphv1jiqidjti7.apps.googleusercontent.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc',
    appId: '1:1082819024270:web:fa2a015928e81bf1e640df',
    messagingSenderId: '1082819024270',
    projectId: 'agrimore-66a4e',
    databaseURL: 'https://agrimore-66a4e-default-rtdb.firebaseio.com',
    storageBucket: 'agrimore-66a4e.firebasestorage.app',
    iosBundleId: 'com.agrimore.agrimore',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc',
    appId: '1:1082819024270:web:fa2a015928e81bf1e640df',
    messagingSenderId: '1082819024270',
    projectId: 'agrimore-66a4e',
    authDomain: 'agrimore-66a4e.firebaseapp.com',
    databaseURL: 'https://agrimore-66a4e-default-rtdb.firebaseio.com',
    storageBucket: 'agrimore-66a4e.firebasestorage.app',
    measurementId: 'G-73B1F06XC3',
  );
}
