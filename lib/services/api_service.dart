import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://13.209.19.58:5000"; // 서버 주소로 교체

  // ✅ 아이디 중복 확인
  static Future<bool> checkDuplicateId(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/check-id'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ID": id}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["isDuplicate"];
    } else {
      throw Exception('ID 중복 확인 실패');
    }
  }

  // ✅ 회원가입 요청
  static Future<String> register(String id, String pw, String name, String sex) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ID": id,
        "PW": pw,
        "NAME": name,
        "SEX": sex,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["message"];
    } else {
      throw Exception('회원가입 실패');
    }
  }
}
