import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../home/terms_screen.dart';
import '../home/privacy_policy_screen.dart';
import 'signup_steps_screen.dart';

/// 회원가입 전 약관 동의 화면 (모두 동의, 만14세, 이용약관, 개인정보 수집·이용)
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _agreeAll = false;
  bool _over14 = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  bool get _requiredChecked =>
      _over14 && _agreeTerms && _agreePrivacy;

  void _onAgreeAllChanged(bool? value) {
    final v = value ?? false;
    setState(() {
      _agreeAll = v;
      _over14 = v;
      _agreeTerms = v;
      _agreePrivacy = v;
    });
  }

  void _syncAgreeAll() {
    setState(() {
      _agreeAll = _over14 && _agreeTerms && _agreePrivacy;
    });
  }

  void _onAgree() {
    if (!_requiredChecked) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SignupStepsScreen(),
      ),
    );
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
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 캔버스 캐시 / 약관동의
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '캔버스 캐시',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '약관동의',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // 체크박스 목록
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 모두 동의합니다
                    CheckboxListTile(
                      value: _agreeAll,
                      onChanged: _onAgreeAllChanged,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '모두 동의합니다.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    // 만 14세 이상입니다
                    CheckboxListTile(
                      value: _over14,
                      onChanged: (v) {
                        setState(() => _over14 = v ?? false);
                        _syncAgreeAll();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '만 14세 이상입니다.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // [필수] 이용약관 동의 + > (탭 시 이용약관 화면)
                    CheckboxListTile(
                      value: _agreeTerms,
                      onChanged: (v) {
                        setState(() => _agreeTerms = v ?? false);
                        _syncAgreeAll();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      secondary: IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsScreen(),
                          ),
                        ),
                      ),
                      title: Text(
                        '[필수] 이용약관 동의',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // [필수] 개인정보 수집 및 이용 동의 + > (탭 시 개인정보 화면)
                    CheckboxListTile(
                      value: _agreePrivacy,
                      onChanged: (v) {
                        setState(() => _agreePrivacy = v ?? false);
                        _syncAgreeAll();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      secondary: IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      title: Text(
                        '[필수] 개인정보 수집 및 이용 동의',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 동의하기 버튼
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requiredChecked ? _onAgree : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _requiredChecked
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                    foregroundColor: _requiredChecked
                        ? Colors.white
                        : AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _requiredChecked ? 4 : 0,
                    shadowColor: _requiredChecked
                        ? Colors.black.withOpacity(0.3)
                        : null,
                  ),
                  child: const Text(
                    '동의하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
