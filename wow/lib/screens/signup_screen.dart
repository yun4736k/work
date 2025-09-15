import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wow/services/dialog_helper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String? _selectedGender;
  bool _isAgreementChecked = false;
  bool _isIdChecked = false;
  bool _isNicknameChecked = false;
  bool _isPasswordValid = false;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFA8D5BA),
      appBar: AppBar(
        title: Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFFF8F4EC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFieldWithButton(
                label: '아이디',
                controller: _idController,
                buttonText: '아이디 확인',
                onPressed: _handleDuplicateCheck,
              ),
              _buildTextFieldWithButton(
                label: '이름',
                controller: _nameController,
                buttonText: '이름 확인',
                onPressed: _handleNicknameCheck,
              ),
              _buildTextField('비밀번호', obscureText: true, controller: _passwordController),
              _buildTextField('비밀번호 재입력', obscureText: true, controller: _confirmPasswordController),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _handlePasswordCheck,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF3CAEA3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      '비밀번호 확인',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3CAEA3)),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildGenderSelection(),
              SizedBox(height: 16),
              _buildAgreementSection(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3CAEA3),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Center(
                  child: Text(
                    '회원가입 완료',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label,
      {bool obscureText = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTextFieldWithButton({
    required String label,
    required TextEditingController controller,
    required String buttonText,
    required VoidCallback onPressed,
    bool obscureText = false,
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
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 120,
            height: 56,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color(0xFF3CAEA3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                backgroundColor: Colors.white,
              ),
              child: Text(
                buttonText,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3CAEA3)),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('성별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 20,
          children: ['남성', '여성', '비공개']
              .map((gender) => _buildGenderRadio(gender))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGenderRadio(String gender) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio(
          value: gender,
          groupValue: _selectedGender,
          activeColor: Color(0xFF3CAEA3),
          onChanged: (value) {
            setState(() {
              _selectedGender = value.toString();
            });
          },
        ),
        Text(gender),
      ],
    );
  }

  Widget _buildAgreementSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('개인정보 제공에 동의합니다.'),
        Row(
          children: [
            Checkbox(
              value: _isAgreementChecked,
              activeColor: Color(0xFF3CAEA3),
              onChanged: (bool? value) {
                setState(() {
                  _isAgreementChecked = value ?? false;
                });
              },
            ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PrivacyPolicyScreen()),
                );
                if (result == true) {
                  setState(() {
                    _isAgreementChecked = true;
                  });
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF3CAEA3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Color(0xFF3CAEA3), width: 1.5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _handleDuplicateCheck() async {
    final inputId = _idController.text.trim();
    if (inputId.length < 8) {
      DialogHelper.showMessage(context, '아이디는 8자 이상이어야 합니다.');
      return;
    }
    if (inputId.isEmpty) {
      DialogHelper.showMessage(context, '아이디를 입력하세요.');
      return;
    }
    try {
      final isDuplicate = await ApiService.checkDuplicateId(inputId);
      if (isDuplicate) {
        DialogHelper.showMessage(context, '중복된 아이디입니다.');
        _isIdChecked = false;
      } else {
        DialogHelper.showMessage(context, '사용 가능한 아이디입니다.');
        _isIdChecked = true;
      }
    } catch (e) {
      DialogHelper.showMessage(context, '서버 오류: $e');
      _isIdChecked = false;
    }
  }

  void _handleNicknameCheck() async {
    final nickname = _nameController.text.trim();
    if (nickname.isEmpty) {
      DialogHelper.showMessage(context, '닉네임을 입력하세요.');
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://15.164.164.156:5000/check-nickname?nickname=$nickname'),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['exists']) {
          DialogHelper.showMessage(context, '이미 사용 중인 닉네임입니다.');
          _isNicknameChecked = false;
        } else {
          DialogHelper.showMessage(context, '사용 가능한 닉네임입니다.');
          _isNicknameChecked = true;
        }
      } else {
        DialogHelper.showMessage(context, '서버 오류: ${response.statusCode}');
        _isNicknameChecked = false;
      }
    } catch (e) {
      DialogHelper.showMessage(context, '네트워크 오류: $e');
      _isNicknameChecked = false;
    }
  }

  void _handlePasswordCheck() {
    final pw = _passwordController.text;
    final confirmPw = _confirmPasswordController.text;
    final passwordRegex = RegExp(
        r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#\$%^&*(),.?":{}|<>])[A-Za-z\d!@#\$%^&*(),.?":{}|<>]{8,}$'
    );


    if (!passwordRegex.hasMatch(pw)) {
      DialogHelper.showMessage(context, '비밀번호는 영문, 숫자, 특수문자를 포함한 8자 이상이어야 합니다.');
      _isPasswordValid = false;
      return;
    }
    if (pw.isNotEmpty && pw == confirmPw) {
      DialogHelper.showMessage(context, '비밀번호가 똑바로 입력됐습니다.');
      _isPasswordValid = true;
    } else {
      DialogHelper.showMessage(context, '비밀번호가 일치하지 않습니다.');
      _isPasswordValid = false;
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
      final result = await ApiService.register(id, pw, name, sex);
      DialogHelper.showMessage(context, result);

      if (result.contains("성공") || result.contains("완료")) {
        final loginUrl = Uri.parse('http://15.164.164.156:5000/login');
        final loginResponse = await http.post(
          loginUrl,
          body: json.encode({'ID': id, 'PW': pw}),
          headers: {'Content-Type': 'application/json'},
        );

        if (loginResponse.statusCode == 200) {
          final responseData = json.decode(loginResponse.body);
          final status = responseData['status'];
          final message = responseData['message'].toString().trim();
          final nicknameFromServer = responseData['nickname'];

          if (status == 'success') {
            DialogHelper.showMessage(context, message);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  userId: id,
                  nickname: nicknameFromServer ?? name,
                ),
              ),
            );
          } else {
            DialogHelper.showMessage(context, '자동 로그인 실패: $message');
          }
        } else {
          DialogHelper.showMessage(context, '자동 로그인 서버 오류: ${loginResponse.statusCode}');
        }
      }
    } catch (e) {
      DialogHelper.showMessage(context, '서버 오류: $e');
    }
  }
}