import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:async'; // Future, Timer 등 비동기 처리를 위해 필요

class ApiService {
  static const String baseUrl = "http://15.164.104.58:5000"; // 서버 주소

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

  /// ======================== 산책 경로 저장 ========================
  static Future<String> saveRoute({
    required String userId,
    required String routeName,
    required List<LatLng> routePath,
    required String category,
  }) async {
    final body = {
      "user_id": userId,
      "route_name": routeName,
      "route_path": routePath.map((p) => [p.latitude, p.longitude]).toList(),
      "category": category,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/add_route'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['route_name'] ?? routeName;
    } else {
      throw Exception("경로 저장 실패: ${response.statusCode}");
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
    final url = Uri.parse('$baseUrl/routes?user_id=$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      // 사용자 경로 목록은 'routes' 키 아래에 담겨 있습니다.
      return data['routes'];
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('사용자 경로 목록을 불러오는 데 실패했습니다: ${response.statusCode}');
    }
  }

  /// ======================== 즐겨찾기 경로 조회 ========================
  static Future<List<dynamic>> fetchFavorites({required String userId}) async {
    final url = Uri.parse('$baseUrl/favorites?user_id=$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      // 즐겨찾기 목록은 'favorites' 키 아래에 담겨 있으므로 해당 리스트를 반환합니다.
      return data['favorites'];
    } else if (response.statusCode == 404) {
      // 즐겨찾기된 경로가 없는 경우 404 응답을 받을 수 있으며, 이때는 빈 리스트를 반환합니다.
      return [];
    } else {
      // 기타 서버 오류의 경우 예외를 발생시킵니다.
      throw Exception('즐겨찾기 목록을 불러오는 데 실패했습니다: ${response.statusCode}');
    }
  }

  static Future<void> deleteRoute({required int routeId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete_route/$routeId'), // ⚠️ 서버의 삭제 엔드포인트
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode != 200) {
      throw Exception("경로 삭제 실패: ${response.statusCode}");
    }
  }

  static Future<void> toggleFavorite(
      {required String userId, required int routeId}) async {
    final url = Uri.parse('http://15.164.104.58:5000/toggle_favorite');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'route_id': routeId}),
    );

    if (response.statusCode != 200) {
      throw Exception('즐겨찾기 상태 변경 실패: ${response.statusCode}');
    }
  }
}


