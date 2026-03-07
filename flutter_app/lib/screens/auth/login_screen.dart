import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../../theme/app_theme.dart';

/// 로그인 전용 화면: 이메일·비밀번호 한 페이지, 흰 배경, 회원가입 단계와 동일 스타일
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialTab = 0});

  /// 호환용. 0만 사용(로그인만 표시)
  final int initialTab;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  /// 입력 필드 안 문구 스타일: 회색, 작고 얇은 텍스트 (회원가입 단계와 동일)
  static const _inputLabelHintStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFF999999),
  );

  /// 기프티콘 구매하기와 동일한 버튼 스타일
  static final _primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryColor,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.3),
    foregroundColor: Colors.white,
  );

  String _getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        case 'user-not-found':
          return '등록되지 않은 이메일입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'too-many-requests':
          return '너무 많은 시도가 있었습니다. 나중에 다시 시도해주세요.';
        case 'network-request-failed':
          return '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        default:
          return '로그인에 실패했습니다: ${error.message ?? error.code}';
      }
    }
    return '로그인에 실패했습니다. 다시 시도해주세요.';
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn(
        _loginEmailController.text.trim(),
        _loginPasswordController.text,
      );

      if (!mounted) return;
      if (authService.user?.uid != null) {
        await AdPopcornSSP.setUserId(authService.user!.uid);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getAuthErrorMessage(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '로그인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Form(
              key: _loginFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _loginEmailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      hintText: '이메일을 입력하세요',
                      labelStyle: _inputLabelHintStyle,
                      hintStyle: _inputLabelHintStyle,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginPasswordController,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      hintText: '비밀번호를 입력하세요',
                      labelStyle: _inputLabelHintStyle,
                      hintStyle: _inputLabelHintStyle,
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: _primaryButtonStyle,
                      child: const Text(
                        '로그인',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
