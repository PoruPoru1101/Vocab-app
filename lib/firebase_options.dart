import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are configured for Web only.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCaQfJ7mC1dlcMxg_rEZfEiKfie2PPSJks',
    appId: '1:357115739002:web:b4ab10113453d62bb6b4c3',
    messagingSenderId: '357115739002',
    projectId: 'vocab-app-e7e88',
    authDomain: 'vocab-app-e7e88.firebaseapp.com',
    storageBucket: 'vocab-app-e7e88.firebasestorage.app',
  );
}
