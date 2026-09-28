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
        return windows;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyByRsK25Z3A-QXqxKxqGaN4nEeyMGpwMC4',
    appId: '1:805661697613:web:5f2a1919e41deeaa62de04',
    messagingSenderId: '805661697613',
    projectId: 'docrs-clinical-system',
    authDomain: 'docrs-clinical-system.firebaseapp.com',
    storageBucket: 'docrs-clinical-system.firebasestorage.app',
    measurementId: 'G-6WY5NWKBRC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCeGYPfb2dC_kxxRaOoMiMCVRSmu_730Gw',
    appId: '1:805661697613:android:5e301e553a89fbb362de04',
    messagingSenderId: '805661697613',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBbOuuelOwePreg49rqFvna63CC9UKdkWs',
    appId: '1:805661697613:ios:8587921af2e0d09e62de04',
    messagingSenderId: '805661697613',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.firebasestorage.app',
    iosBundleId: 'com.example.ophthalmologyClinicalRecordSystem',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBbOuuelOwePreg49rqFvna63CC9UKdkWs',
    appId: '1:805661697613:ios:8587921af2e0d09e62de04',
    messagingSenderId: '805661697613',
    projectId: 'docrs-clinical-system',
    storageBucket: 'docrs-clinical-system.firebasestorage.app',
    iosBundleId: 'com.example.ophthalmologyClinicalRecordSystem',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyByRsK25Z3A-QXqxKxqGaN4nEeyMGpwMC4',
    appId: '1:805661697613:web:111b9262da8a9d6562de04',
    messagingSenderId: '805661697613',
    projectId: 'docrs-clinical-system',
    authDomain: 'docrs-clinical-system.firebaseapp.com',
    storageBucket: 'docrs-clinical-system.firebasestorage.app',
    measurementId: 'G-YZ5MGTH6Z4',
  );
}
