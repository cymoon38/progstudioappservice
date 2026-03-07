import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';
import 'auth/welcome_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Firebase Auth 영속 복원 대기 (자동 로그인: 마지막 로그인 계정 복원)
    await Future.delayed(const Duration(milliseconds: 500));
    // authStateChanges().first = 복원된 첫 상태 (로그인 유지 시 user, 비로그인 시 null)
    User? firebaseUser = await FirebaseAuth.instance.authStateChanges().first
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    // 일부 환경에서 첫 emission이 null일 수 있어, 한 번 더 currentUser 확인
    if (firebaseUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      firebaseUser = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    if (firebaseUser?.uid != null && firebaseUser!.uid.isNotEmpty) {
      await AdPopcornSSP.setUserId(firebaseUser.uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF667eea),
      body: Center(
        child: Image.asset(
          'assets/icons/loding_logo.png',
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.palette,
            size: 100,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}



