// File generated from Firebase Console (Android 앱 com.progstudio3820.canvascash)
// 수동 생성. FlutterFire CLI로 재생성하려면: dart run flutterfire_cli:flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android; // iOS 앱 추가 시 FlutterFire configure로 생성
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCr7Ls0mvfa9HNEexd2qZlxkLBU0MTT8hM',
    appId: '1:807594698988:android:a476df4963d5dbdfd09dc9',
    messagingSenderId: '807594698988',
    projectId: 'community-b19fb',
    storageBucket: 'community-b19fb.firebasestorage.app',
  );

  // 웹/다른 플랫폼 필요 시 FlutterFire configure 실행 후 추가
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyADNSIqYGqtFooPK9MjX4_UrLNoY0hcu4M',
    appId: '1:807594698988:web:3bf482c3e1d88df5d09dc9',
    messagingSenderId: '807594698988',
    projectId: 'community-b19fb',
    authDomain: 'community-b19fb.firebaseapp.com',
    storageBucket: 'community-b19fb.firebasestorage.app',
    measurementId: 'G-3YW94NCEJM',
  );
}
