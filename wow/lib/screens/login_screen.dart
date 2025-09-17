import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'package:wow/services/dialog_helper.dart';
import '../services/api_service.dart';

/// 브랜드 컬러
const _brandTeal = Color(0xFF3CAEA3);
const _brandTealDark = Color(0xFF2C8C86);
const _brandOrange = Color(0xFFF27A2A);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      DialogHelper.showMessage(context, '위치 권한이 거부되었습니다.');
    } else if (permission == LocationPermission.deniedForever) {
      DialogHelper.showMessage(context, '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경하세요.');
    }
  }

  Future<void> login(String username, String password) async {
    try {
      final responseData = await ApiService.login(id: username, pw: password);
      final message = responseData['message'].toString().trim();
      final nickname = responseData['nickname']?.toString() ?? 'TestAccount';

      if (message.contains('환영')) {
        DialogHelper.showMessage(context, message);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(userId: username, nickname: nickname),
          ),
        );
      } else {
        DialogHelper.showMessage(context, message);
      }
    } catch (e) {
      DialogHelper.showMessage(context, '네트워크 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 전체 화면 그라데이션
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brandTeal, _brandOrange],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // 콘텐츠가 화면보다 작을 때도 세로 중앙 배치되도록 minHeight 부여
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 로고
                    SizedBox(
                      height: 400,
                      child: Image.asset(
                        'assets/canvus4.png', // 투명 배경 로고 사용
                        fit: BoxFit.contain,
                        semanticLabel: 'Walk Canvas 로고',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Walk Canvas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                        color: Colors.white.withOpacity(0.96),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '당신의 걸음을 도화지 위에',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.black12, width: 0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _usernameController,
                            labelText: '아이디',
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _passwordController,
                            labelText: '비밀번호',
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                          ),
                          const SizedBox(height: 16),

                          // 로그인 버튼
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => login(
                                _usernameController.text.trim(),
                                _passwordController.text,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2.5,
                              ),
                              child: const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 회원가입 버튼
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _brandTeal, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                foregroundColor: _brandTeal,
                                backgroundColor: Colors.white,
                              ),
                              child: const Text(
                                '회원 가입',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 공통 텍스트필드
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: obscureText ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _brandTealDark) : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandTeal, width: 1.8),
        ),
      ),
    );
  }
}
