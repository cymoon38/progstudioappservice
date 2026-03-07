import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

/// 약관 동의 후 단계별 회원가입: 이메일 → 비밀번호/확인 → 닉네임 → 회원가입 처리
class SignupStepsScreen extends StatefulWidget {
  const SignupStepsScreen({super.key});

  @override
  State<SignupStepsScreen> createState() => _SignupStepsScreenState();
}

class _SignupStepsScreenState extends State<SignupStepsScreen> {
  int _step = 0; // 0: 이메일, 1: 비밀번호, 2: 닉네임
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isCheckingUsername = false;
  String? _usernameError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _getSignupErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'weak-password':
          return '비밀번호가 너무 약합니다. 더 강한 비밀번호를 사용해주세요.';
        case 'invalid-email':
          return '올바른 이메일 형식이 아닙니다.';
        case 'operation-not-allowed':
          return '이메일/비밀번호 가입이 허용되지 않았습니다.';
        case 'network-request-failed':
          return '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        default:
          return '회원가입에 실패했습니다: ${error.message ?? error.code}';
      }
    }
    return '회원가입에 실패했습니다. 다시 시도해주세요.';
  }

  /// 입력 필드 안 문구 스타일: 회색, 작고 얇은 텍스트
  static const _inputLabelHintStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFF999999),
  );

  /// 기기당 회원가입 수 제한 알림 (앱 알림 디자인: 제목 + 확인 버튼)
  static Future<void> _showDeviceLimitDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '더 이상 회원가입을 할 수 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '생성 가능한 최대 계정 수에 도달했습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9FA4B3),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 기프티콘 구매하기와 동일한 버튼 스타일
  ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        foregroundColor: Colors.white,
      );

  Future<void> _onEmailConfirm() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일을 입력해주세요.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 이메일 형식이 아닙니다.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.checkEmailExists(email);
      if (!mounted) return;
      setState(() => _step = 1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPasswordConfirm() {
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호를 입력해주세요.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 6자 이상이어야 합니다.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _checkUsername(String value) async {
    if (value.isEmpty) {
      setState(() => _usernameError = null);
      return;
    }
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.checkUsernameExists(value);
      if (mounted) setState(() => _usernameError = null);
    } catch (e) {
      if (mounted) {
        setState(() => _usernameError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  Future<void> _onSignup() async {
    FocusScope.of(context).unfocus(); // 키보드 내리기
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임을 입력해주세요.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_usernameError!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signUp(
        name,
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (authService.user?.uid != null) {
        await AdPopcornSSP.setUserId(authService.user!.uid);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('한 기기에서는 최대 2개') || msg.contains('최대 2개의 계정')) {
        await _showDeviceLimitDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getSignupErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _step == 0 ? '이메일 입력' : _step == 1 ? '비밀번호 입력' : '닉네임 입력',
          style: const TextStyle(
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
            child: _step == 0 ? _buildEmailStep() : _step == 1 ? _buildPasswordStep() : _buildNicknameStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: '이메일',
            hintText: '이메일을 입력하세요',
            labelStyle: _inputLabelHintStyle,
            hintStyle: _inputLabelHintStyle,
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onEmailConfirm,
            style: _primaryButtonStyle,
            child: const Text('확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            hintText: '비밀번호를 입력하세요 (최소 6자)',
            labelStyle: _inputLabelHintStyle,
            hintStyle: _inputLabelHintStyle,
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordConfirmController,
          decoration: const InputDecoration(
            labelText: '비밀번호 확인',
            hintText: '비밀번호를 다시 입력하세요',
            labelStyle: _inputLabelHintStyle,
            hintStyle: _inputLabelHintStyle,
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onPasswordConfirm,
            style: _primaryButtonStyle,
            child: const Text('확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '닉네임',
            hintText: '닉네임을 입력하세요',
            labelStyle: _inputLabelHintStyle,
            hintStyle: _inputLabelHintStyle,
            errorText: _usernameError,
            suffixIcon: _isCheckingUsername
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          onChanged: (value) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _nameController.text == value) {
                _checkUsername(value);
              }
            });
          },
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onSignup,
            style: _primaryButtonStyle,
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('회원가입', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
