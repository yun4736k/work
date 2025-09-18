import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://13.125.177.95:5000"; // 서버 주소

  /// ======================== 로그인 ========================
  static Future<Map<String, dynamic>> login({
    required String id,
    required String pw,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ID": id, "PW": pw}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('로그인 실패: ${response.statusCode}');
    }
  }

  /// ======================== 아이디 중복 확인 ========================
  static Future<bool> checkDuplicateId({required String id}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/check-id?ID=$id'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["exists"] ?? false;
    } else {
      throw Exception('ID 중복 확인 실패: ${response.statusCode}');
    }
  }

  /// ======================== 닉네임 중복 확인 ========================
  static Future<bool> checkDuplicateNickname({required String nickname}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/check-nickname?nickname=$nickname'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["exists"] ?? false;
    } else {
      throw Exception('닉네임 중복 확인 실패: ${response.statusCode}');
    }
  }

  /// ======================== 회원가입 ========================
  static Future<String> register({
    required String id,
    required String pw,
    required String name,
    required String sex,
  }) async {
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
      return data["message"] ?? "회원가입 성공";
    } else {
      throw Exception('회원가입 실패: ${response.statusCode}');
    }
  }

  /// ======================== 날씨 정보 ========================
  static Future<Map<String, dynamic>> fetchWeather({
    required double lat,
    required double lon,
  }) async {
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m,relative_humidity_2m";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("날씨 정보 가져오기 실패: ${response.statusCode}");
    }
  }

  /// ======================== 비밀번호 변경 ========================
  static Future<Map<String, dynamic>> changePassword({
    required String id,
    required String currentPw,
    required String newPw,
    required String nickname,
    required int gender,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ID": id,
        "PW": currentPw,
        "NEW_PW": newPw,
        "NAME": nickname,
        "SEX": gender,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('비밀번호 변경 실패: ${response.statusCode}');
    }
  }

  /// ======================== 사용자 생성 경로 조회 ========================
  static Future<List<dynamic>> fetchUserRoutes({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/all_user_routes'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      // 서버 전체 경로를 받아와서 클라이언트에서 userId 필터링
      final userRoutes = data.where((route) => route['nickname'] == userId).toList();
      return userRoutes;
    } else {
      throw Exception('사용자 경로 조회 실패: ${response.statusCode}');
    }
  }

  /// ======================== 즐겨찾기 경로 조회 ========================
  static Future<List<dynamic>> fetchFavorites({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/all_favorites?user_id=$userId'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['favorites'] ?? [];
    } else {
      throw Exception('즐겨찾기 조회 실패: ${response.statusCode}');
    }
  }
}
