import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDuYE8XMgwZXKzd-clza-x4-KOcRndoYsw',
    appId: '1:975098654659:web:7f417f27611343516a1776',
    messagingSenderId: '975098654659',
    projectId: 'emplake-app-d1a50',
    authDomain: 'emplake-app-d1a50.firebaseapp.com',
    storageBucket: 'emplake-app-d1a50.firebasestorage.app',
  );
}