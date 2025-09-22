import 'dart:ui';
import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'package:wow/services/dialog_helper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 상태
  String? _selectedGender; // 초기 미선택 허용
  bool _isAgreementChecked = false;
  bool _isIdChecked = false;
  bool _isNicknameChecked = false;
  bool _isPasswordValid = false;

  // 컨트롤러
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // 브랜드 컬러
  static const _brandTeal = Color(0xFF3CAEA3);
  static const _brandTealDark = Color(0xFF2C8C86);
  static const _bgMint = Color(0xFFA8D5BA);

  // SegmentedButton용 값
  static const _genders = <String>{"남성", "여성", "선택 안함"};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F2937), Color(0xFF0F766E)],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: MediaQuery.of(context).size.height * 0.42,
                child: Container(color: _bgMint),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 16),

                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextFieldWithSideButton(
                            label: '아이디',
                            controller: _idController,
                            buttonText: '중복확인',
                            onPressed: _handleDuplicateCheck,
                            icon: Icons.badge_outlined,
                            trailingStatus: _statusPill(
                              checked: _isIdChecked,
                              trueText: '사용 가능',
                              falseText: '미확인',
                            ),
                          ),
                          _buildTextFieldWithSideButton(
                            label: '닉네임',
                            controller: _nameController,
                            buttonText: '중복확인',
                            onPressed: _handleNicknameCheck,
                            icon: Icons.tag_faces_outlined,
                            trailingStatus: _statusPill(
                              checked: _isNicknameChecked,
                              trueText: '사용 가능',
                              falseText: '미확인',
                            ),
                          ),
                          _buildTextField(
                            '비밀번호',
                            controller: _passwordController,
                            obscureText: true,
                            icon: Icons.lock_outline,
                            hint: '영문/숫자/특수문자 포함 8자 이상',
                          ),
                          _buildTextField(
                            '비밀번호 재입력',
                            controller: _confirmPasswordController,
                            obscureText: true,
                            icon: Icons.lock_reset_outlined,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: _handlePasswordCheck,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.white,
                                foregroundColor: _brandTeal,
                              ),
                              child: const Text('비밀번호 확인'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _isPasswordValid
                                ? _inlineInfo(
                              icon: Icons.check_circle_rounded,
                              text: '안전한 비밀번호입니다.',
                              color: Colors.green,
                            )
                                : _passwordController.text.isEmpty &&
                                _confirmPasswordController.text.isEmpty
                                ? const SizedBox.shrink()
                                : _inlineInfo(
                              icon: Icons.error_rounded,
                              text: '비밀번호 형식 또는 일치 여부를 확인하세요.',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ✅ SegmentedButton: 초기 미선택 허용 (emptySelectionAllowed: true)
                          Text('성별', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: _genders
                                .map(
                                  (g) => ButtonSegment<String>(
                                value: g,
                                label: Text(g),
                                icon: Icon(
                                  g == "남성"
                                      ? Icons.male_rounded
                                      : g == "여성"
                                      ? Icons.female_rounded
                                      : Icons.remove_red_eye_outlined,
                                ),
                              ),
                            )
                                .toList(),
                            selected: (_selectedGender == null)
                                ? <String>{}
                                : <String>{_selectedGender!},
                            emptySelectionAllowed: true, // ← 핵심 수정
                            onSelectionChanged: (set) {
                              setState(() => _selectedGender = set.isEmpty ? null : set.first);
                            },
                            style: ButtonStyle(
                              side: WidgetStatePropertyAll(
                                BorderSide(color: _brandTeal.withOpacity(0.4)),
                              ),
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.white.withOpacity(0.6);
                              }),
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildAgreementSection(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    SafeArea(
                      top: false,
                      child: FilledButton(
                        onPressed: _handleSignUp,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        child: const Center(
                          child: Text(
                            '회원가입 완료',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== UI Builder ======

  Widget _buildHero() {
    return const Padding(
      padding: EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Walk Canvas',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '당신의 걸음을 지도로 그려요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, {
        bool obscureText = false,
        TextEditingController? controller,
        IconData? icon,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, color: _brandTealDark),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _brandTeal.withOpacity(0.25), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _brandTeal, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithSideButton({
    required String label,
    required TextEditingController controller,
    required String buttonText,
    required VoidCallback onPressed,
    bool obscureText = false,
    IconData? icon,
    Widget? trailingStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: icon == null ? null : Icon(icon, color: _brandTealDark),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _brandTeal.withOpacity(0.25), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _brandTeal, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 48,
                child: FilledButton.tonal(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: _brandTeal.withOpacity(0.35)),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (trailingStatus != null) trailingStatus,
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill({required bool checked, required String trueText, required String falseText}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: checked ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: checked ? Colors.green.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked ? Icons.check_rounded : Icons.help_outline_rounded,
            size: 16,
            color: checked ? Colors.green.shade700 : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            checked ? trueText : falseText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: checked ? Colors.green.shade800 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineInfo({required IconData icon, required String text, required Color color}) {
    return Row(
      key: ValueKey(text),
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brandTeal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isAgreementChecked,
            activeColor: _brandTeal,
            onChanged: (bool? value) {
              setState(() => _isAgreementChecked = value ?? false);
            },
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              '개인정보 처리방침에 동의합니다.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
              );
              if (result == true) {
                setState(() => _isAgreementChecked = true);
              }
            },
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandTeal,
              side: BorderSide(color: _brandTeal.withOpacity(0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ====== 로직 ======

  void _handleDuplicateCheck() async {
    final inputId = _idController.text.trim();
    if (inputId.isEmpty) {
      DialogHelper.showMessage(context, '아이디를 입력하세요.');
      setState(() => _isIdChecked = false);
      return;
    }
    if (inputId.length < 8) {
      DialogHelper.showMessage(context, '아이디는 8자 이상이어야 합니다.');
      setState(() => _isIdChecked = false);
      return;
    }
    try {
      final isDuplicate = await ApiService.checkDuplicateId(id: inputId);
      if (isDuplicate) {
        DialogHelper.showMessage(context, '중복된 아이디입니다.');
        setState(() => _isIdChecked = false);
      } else {
        DialogHelper.showMessage(context, '사용 가능한 아이디입니다.');
        setState(() => _isIdChecked = true);
      }
    } catch (e) {
      DialogHelper.showMessage(context, '서버 오류: $e');
      setState(() => _isIdChecked = false);
    }
  }

  void _handleNicknameCheck() async {
    final nickname = _nameController.text.trim();
    if (nickname.isEmpty) {
      DialogHelper.showMessage(context, '닉네임을 입력하세요.');
      setState(() => _isNicknameChecked = false);
      return;
    }
    try {
      final isDuplicate = await ApiService.checkDuplicateNickname(nickname: nickname);
      if (isDuplicate) {
        DialogHelper.showMessage(context, '이미 사용 중인 닉네임입니다.');
        setState(() => _isNicknameChecked = false);
      } else {
        DialogHelper.showMessage(context, '사용 가능한 닉네임입니다.');
        setState(() => _isNicknameChecked = true);
      }
    } catch (e) {
      DialogHelper.showMessage(context, '서버 오류: $e');
      setState(() => _isNicknameChecked = false);
    }
  }

  void _handlePasswordCheck() {
    final pw = _passwordController.text;
    final confirmPw = _confirmPasswordController.text;
    final passwordRegex = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#\$%^&*(),.?":{}|<>])[A-Za-z\d!@#\$%^&*(),.?":{}|<>]{8,}$',
    );

    if (!passwordRegex.hasMatch(pw)) {
      DialogHelper.showMessage(context, '비밀번호는 영문, 숫자, 특수문자를 포함한 8자 이상이어야 합니다.');
      setState(() => _isPasswordValid = false);
      return;
    }
    if (pw.isNotEmpty && pw == confirmPw) {
      DialogHelper.showMessage(context, '비밀번호가 똑바로 입력됐습니다.');
      setState(() => _isPasswordValid = true);
    } else {
      DialogHelper.showMessage(context, '비밀번호가 일치하지 않습니다.');
      setState(() => _isPasswordValid = false);
    }
  }

  void _handleSignUp() async {
    final id = _idController.text.trim();
    final pw = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final sex = _selectedGender ?? "";

    if (id.isEmpty || pw.isEmpty || name.isEmpty || sex.isEmpty || !_isAgreementChecked) {
      DialogHelper.showMessage(context, '모든 항목을 입력하고 동의해주세요.');
      return;
    }
    if (!_isIdChecked) {
      DialogHelper.showMessage(context, '아이디 중복 확인을 해주세요.');
      return;
    }
    if (!_isNicknameChecked) {
      DialogHelper.showMessage(context, '닉네임 중복 확인을 해주세요.');
      return;
    }
    if (!_isPasswordValid) {
      DialogHelper.showMessage(context, '비밀번호 확인을 해주세요.');
      return;
    }

    try {
      final result = await ApiService.register(
        id: id,
        pw: pw,
        name: name,
        sex: sex,
      );
      DialogHelper.showMessage(context, result);

      if (result.contains("성공") || result.contains("완료")) {
        final loginResponse = await ApiService.login(
          id: id,
          pw: pw,
        );

        final message = loginResponse['message'].toString().trim();
        final nicknameFromServer = loginResponse['nickname'] ?? name;

        DialogHelper.showMessage(context, message);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userId: id,
              nickname: nicknameFromServer,
            ),
          ),
        );
      }
    } catch (e) {
      DialogHelper.showMessage(context, '서버 오류: $e');
    }
  }
}

/// 글래스모픽 카드
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F4EC).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}
