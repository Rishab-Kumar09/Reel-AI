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
        throw UnsupportedError(
          'No iOS configuration provided. Add your iOS configuration first.',
        );
      default:
        throw UnsupportedError(
          'Unsupported platform ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA',
    appId: '1:403328203757:web:6111f04409a3b4a97a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    authDomain: 'reel-ai-8132d.firebaseapp.com',
    storageBucket: 'reel-ai-8132d.firebasestorage.app',
    measurementId: 'G-87E1LFSJL2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFRKPYtZCCtMhX_XIWrDaCF4b-WXbQX6U',
    appId: '1:403328203757:android:0ff759a3d8f4138d7a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    storageBucket: 'reel-ai-8132d.firebasestorage.app',
  );
} 