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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA',
    appId: '1:403328203757:web:6111f04409a3b4a97a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    authDomain: 'reel-ai-8132d.firebaseapp.com',
    storageBucket: 'reel-ai-8132d.appspot.com',
    measurementId: 'G-87E1LFSJL2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA',
    appId: '1:403328203757:android:6111f04409a3b4a97a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    storageBucket: 'reel-ai-8132d.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA',
    appId: '1:403328203757:ios:6111f04409a3b4a97a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    storageBucket: 'reel-ai-8132d.appspot.com',
    iosClientId: '403328203757-xxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.example.reelAi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA',
    appId: '1:403328203757:macos:6111f04409a3b4a97a85e4',
    messagingSenderId: '403328203757',
    projectId: 'reel-ai-8132d',
    storageBucket: 'reel-ai-8132d.appspot.com',
    iosClientId: '403328203757-xxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.example.reelAi',
  );
} 