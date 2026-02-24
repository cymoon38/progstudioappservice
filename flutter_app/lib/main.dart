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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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


