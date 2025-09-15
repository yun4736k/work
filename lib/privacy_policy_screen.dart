import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D), // Ink Black
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('개인정보 처리 방침',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
      ),
      backgroundColor: Color(0xFFF8F4EC), // Canvas Beige
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                  '1. 개인정보 수집 항목',
                  '본 앱은 회원 가입 및 로그인 과정에서 사용자의 아이디, 비밀번호 등 개인정보를 수집합니다.'),
              _buildSection(
                  '2. 개인정보의 수집 및 이용 목적',
                  '수집된 개인정보는 로그인 및 서비스 제공을 위해 사용되며, 서비스 개선과 관련된 피드백을 받기 위해 사용될 수 있습니다.'),
              _buildSection(
                  '3. 개인정보의 보유 및 이용 기간',
                  '회원 탈퇴 시까지 개인정보는 보유되며, 탈퇴 요청이 있을 경우 지체 없이 삭제됩니다.'),
              _buildSection(
                  '4. 개인정보의 제3자 제공',
                  '본 앱은 사용자의 동의 없이 개인정보를 제3자에게 제공하지 않습니다.'),
              _buildSection(
                  '5. 개인정보 보호를 위한 노력',
                  '본 앱은 개인정보 보호를 위해 최선의 노력을 다하며, 관련 법령을 준수하여 개인정보를 안전하게 처리합니다.'),
              _buildSection(
                  '6. 개인정보 관련 문의',
                  '개인정보 관련 문의는 고객센터 또는 앱 내 문의 기능을 통해 처리하실 수 있습니다.'),
              SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3CAEA3), // 민트
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))), // Ink Black
          SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
