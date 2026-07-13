// Firebase 프로젝트 연결 설정 (thsummervacation)
//
// 웹은 아래 값으로 바로 동작합니다.
// Android/iOS 앱으로 빌드하려면 프로젝트 루트에서
//   flutterfire configure --project=thsummervacation
// 를 실행해 이 파일을 다시 생성하세요 (플랫폼별 앱 등록이 필요합니다).

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
      case TargetPlatform.iOS:
      default:
        throw UnsupportedError(
          '이 플랫폼용 Firebase 설정이 아직 없습니다. '
          'flutterfire configure --project=thsummervacation 를 실행해 주세요.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDbV6TODV12eQInma-8S4Jlpow8NKyvMx4',
    authDomain: 'thsummervacation.firebaseapp.com',
    projectId: 'thsummervacation',
    storageBucket: 'thsummervacation.firebasestorage.app',
    messagingSenderId: '533093343268',
    appId: '1:533093343268:web:9521aec3227c0e01f478b1',
    measurementId: 'G-ZFGTM22KYZ',
  );
}
