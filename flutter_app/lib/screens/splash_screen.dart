import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
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
    // Firebase Auth 복원이 끝날 때까지 대기 (uid_token이 SSP 요청에 들어가도록)
    await Future.delayed(const Duration(milliseconds: 800));
    final User? firebaseUser = await FirebaseAuth.instance.authStateChanges().first
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (firebaseUser?.uid != null && firebaseUser!.uid.isNotEmpty) {
      await AdPopcornSSP.setUserId(firebaseUser.uid);
    }

    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user?.uid != null && authService.user!.uid.isNotEmpty) {
      await AdPopcornSSP.setUserId(authService.user!.uid);
    }
    if (authService.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.palette,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              '그림 커뮤니티',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}



