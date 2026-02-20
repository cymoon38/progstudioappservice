import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/home/upload_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/viewed_posts_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyADNSIqYGqtFooPK9MjX4_UrLNoY0hcu4M",
      authDomain: "community-b19fb.firebaseapp.com",
      projectId: "community-b19fb",
      storageBucket: "community-b19fb.firebasestorage.app",
      messagingSenderId: "807594698988",
      appId: "1:807594698988:web:3bf482c3e1d88df5d09dc9",
      measurementId: "G-3YW94NCEJM",
    ),
  );
  
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


