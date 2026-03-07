import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/adpopcorn_config.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/home/upload_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/viewed_posts_service.dart';
import 'theme/app_theme.dart';

import 'package:adpopcornreward/adpopcornreward.dart';
import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'services/adpopcorn_ssp_state.dart';
import 'services/offerwall_reward_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (플랫폼별 설정 사용)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 애드팝콘 오퍼월 SDK 초기화 (앱 키·해시키는 AdPopcornConfig에 설정)
  if (AdPopcornConfig.isConfigured) {
    AdPopcornReward.setAppKeyAndHashKey(AdPopcornConfig.appKey, AdPopcornConfig.hashKey);
    AdPopcornReward.setLogEnable(kDebugMode);
  }
  // 개인정보 동의 무조건 동의로 설정 (가이드 개인정보 동의 처리 API)
  OfferwallRewardService.setAgreePrivacy(true);

  // 애드팝콘 SSP SDK 초기화 (상용: AppKey 123870086)
  // 앱 중단 원인 확인용: true로 두면 SSP 초기화 생략 (테스트 후 반드시 false로 복구)
  const bool _skipSspInitForDebug = false;
  // ignore: dead_code
  if (!_skipSspInitForDebug) {
    if (Platform.isAndroid) {
      AdPopcornSSP.init('123870086');
    } else if (Platform.isIOS) {
      AdPopcornSSP.init('123870086');
    }
    if (kDebugMode) {
      AdPopcornSSP.setLogLevel('Trace');
      print('[AdPopcornSSP] 초기화 완료 (상용), 로그레벨=Trace');
    }
    // ignore: dead_code
  } else if (kDebugMode) {
    print('[AdPopcornSSP] 디버그: SSP 초기화 생략됨 (_skipSspInitForDebug=true)');
  }
  
  runApp(const MyApp());
}

/// 문서: MethodChannel('adpopcornssp/{placement_id}') + setMethodCallHandler 로 네이티브 이벤트 수신
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _nativePlacementId = 'RMArXdt3NJV48Ph';
  static const MethodChannel _nativeChannel = MethodChannel('adpopcornssp/$_nativePlacementId');

  @override
  void initState() {
    super.initState();
    _nativeChannel.setMethodCallHandler(_eventHandleMethod);
    if (kDebugMode) {
      print('[AdPopcornSSP] MethodChannel 등록: adpopcornssp/$_nativePlacementId');
    }
  }

  static Future<dynamic> _eventHandleMethod(MethodCall call) async {
    try {
      final arguments = call.arguments is Map ? Map.from(call.arguments as Map) : <String, dynamic>{};
      final String placementId = arguments['placementId']?.toString() ?? _nativePlacementId;

      if (call.method == 'APSSPNativeAdLoadSuccess') {
        print('[AdPopcornSSP] 네이티브 광고 로드 성공: $placementId');
      } else if (call.method == 'APSSPNativeAdLoadFail') {
        final errorCode = arguments['errorCode'];
        print('[AdPopcornSSP] 네이티브 광고 로드 실패: $placementId, errorCode=$errorCode');
        adPopcornNativeAdLoadFailed.value = true;
      } else if (call.method == 'APSSPNativeAdImpression') {
        print('[AdPopcornSSP] 네이티브 광고 노출: $placementId');
      } else if (call.method == 'APSSPNativeAdClicked') {
        print('[AdPopcornSSP] 네이티브 광고 클릭: $placementId');
      } else {
        print('[AdPopcornSSP] 이벤트: ${call.method}');
      }
      return Future<dynamic>.value(null);
    } catch (e, stack) {
      // 네이티브 예외가 앱 중단으로 이어지지 않도록 처리
      debugPrint('[AdPopcornSSP] 채널 핸들러 예외: $e\n$stack');
      adPopcornNativeAdLoadFailed.value = true;
      return Future<dynamic>.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DataService()),
        ChangeNotifierProvider(create: (_) => ViewedPostsService()),
      ],
      child: MaterialApp(
        title: '그림 커뮤니티',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/profile': (context) => const ProfileScreen(),
          '/search': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final query = args is String ? args : null;
            return SearchScreen(initialQuery: query);
          },
          '/upload': (context) => const UploadScreen(),
        },
      ),
    );
  }
}


