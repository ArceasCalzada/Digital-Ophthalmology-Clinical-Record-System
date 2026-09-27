import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with Firebase.initializeApp.
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
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOCRS-WebApiKeyPlaceholder',
    appId: '1:1234567890:web:docrs123456',
    messagingSenderId: '1234567890',
    projectId: 'docrs-clinical-system',
    authDomain: 'docrs-clinical-system.firebaseapp.com',
    storageBucket: 'docrs-clinical-system.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDOCRS-AndroidApiKeyPlaceholder',
    appId: '1:1234567890:android:docrs123456',
    messagingSenderId: '1234567890',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDOCRS-IosApiKeyPlaceholder',
    appId: '1:1234567890:ios:docrs123456',
    messagingSenderId: '1234567890',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.appspot.com',
    iosBundleId: 'com.docrs.ophthalmologyClinicalRecordSystem',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDOCRS-MacosApiKeyPlaceholder',
    appId: '1:1234567890:ios:docrs123456',
    messagingSenderId: '1234567890',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.appspot.com',
    iosBundleId: 'com.docrs.ophthalmologyClinicalRecordSystem',
  );
}
