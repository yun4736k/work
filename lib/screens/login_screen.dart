import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'signup_screen.dart';
import 'home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wow/services/dialog_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
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
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      DialogHelper.showMessage(context, '위치 권한이 거부되었습니다.');
    } else if (permission == LocationPermission.deniedForever) {
      DialogHelper.showMessage(context, '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경하세요.');
    }
  }

  Future<void> login(String username, String password) async {
    final url = Uri.parse('http://13.209.19.58:5000/login');

    try {
      final response = await http.post(
        url,
        body: json.encode({'ID': username, 'PW': password}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final message = responseData['message'].toString().trim();
        final nickname = responseData['nickname']?.toString() ?? 'TestAccount';

        if (message.contains('환영')) {
          DialogHelper.showMessage(context, message);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userId: username,
                nickname: nickname,
              ),
            ),
          );
        } else {
          DialogHelper.showMessage(context, message);
        }
      } else {
        DialogHelper.showMessage(context, '서버 오류: ${response.statusCode}');
      }
    } catch (error) {
      DialogHelper.showMessage(context, '네트워크 오류: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Walk Canvas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Roboto',
          ),
        ),
        backgroundColor: Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFFF8F4EC),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, size: 80, color: Color(0xFF3CAEA3)),
                  SizedBox(height: 16),
                  _buildTextField(_usernameController, '아이디'),
                  SizedBox(height: 12),
                  _buildTextField(_passwordController, '비밀번호', obscureText: true),
                  SizedBox(height: 24),

                  // 👉 버튼 두 개 수평 정렬
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            login(_usernameController.text, _passwordController.text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3CAEA3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SignUpScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Color(0xFF3CAEA3)),
                          ),
                          child: Text(
                            '회원 가입',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF3CAEA3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            ),
          ),
        ),
      ),
      backgroundColor: Color(0xFFA8D5BA),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
