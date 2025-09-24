import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ApiService {
  static const String baseUrl = "http://15.164.251.104:5000"; // 서버 주소

  // 공통 디코더
  static dynamic _decodeBody(http.Response res) =>
      json.decode(utf8.decode(res.bodyBytes));

  // ======================== 로그인 ========================
  static Future<Map<String, dynamic>> login({
    required String id,
    required String pw,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ID": id, "PW": pw}),
    );
    if (res.statusCode == 200) {
      return _decodeBody(res);
    }
    throw Exception('로그인 실패: ${res.statusCode}');
  }

  // ======================== 아이디 중복 확인 ========================
  static Future<bool> checkDuplicateId({required String id}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/check-id?ID=$id'),
      headers: {"Content-Type": "application/json"},
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return (data["exists"] ?? data["isDuplicate"]) == true;
    }
    throw Exception('ID 중복 확인 실패: ${res.statusCode}');
  }

  // ======================== 닉네임 중복 확인 ========================
  static Future<bool> checkDuplicateNickname({required String nickname}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/check-nickname?nickname=$nickname'),
      headers: {"Content-Type": "application/json"},
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return data["exists"] == true;
    }
    throw Exception('닉네임 중복 확인 실패: ${res.statusCode}');
  }

  // ======================== 회원가입 ========================
  static Future<String> register({
    required String id,
    required String pw,
    required String name,
    required String sex,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ID": id, "PW": pw, "NAME": name, "SEX": sex}),
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return data["message"] ?? "회원가입 성공";
    }
    throw Exception('회원가입 실패: ${res.statusCode}');
  }

  // ======================== 날씨 정보 ========================
  static Future<Map<String, dynamic>> fetchWeather({
    required double lat,
    required double lon,
  }) async {
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m,relative_humidity_2m";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return _decodeBody(res);
    }
    throw Exception("날씨 정보 가져오기 실패: ${res.statusCode}");
  }

  // ======================== 산책 경로 저장 ========================
  static Future<String> saveRoute({
    required String userId,
    required String routeName,
    required List<LatLng> routePath,
    String? regionId,
    String? roadTypeId,
    String? transportId,
    String? category,
  }) async {
    final body = {
      "user_id": userId,
      "route_name": routeName,
      "route_path": routePath.map((p) => [p.latitude, p.longitude]).toList(),
      if (regionId != null) "region_id": regionId,
      if (roadTypeId != null) "road_type_id": roadTypeId,
      if (transportId != null) "transport_id": transportId,
      if (category != null) "category": category,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/add_route'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return data['route_name'] ?? routeName;
    }
    throw Exception("경로 저장 실패: ${res.statusCode}");
  }

  // ======================== 비밀번호 변경 ========================
  static Future<Map<String, dynamic>> changePassword({
    required String id,
    required String currentPw,
    required String newPw,
    required String nickname,
    required int gender,
  }) async {
    final res = await http.post(
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
    if (res.statusCode == 200) {
      return _decodeBody(res);
    }
    throw Exception('비밀번호 변경 실패: ${res.statusCode}');
  }

  // ======================== 사용자 생성 경로 조회 ========================
  static Future<List<dynamic>> fetchUserRoutes({required String userId}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/routes?user_id=$userId'),
      headers: {"Content-Type": "application/json"},
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return (data is Map && data['routes'] is List)
          ? List<dynamic>.from(data['routes'])
          : <dynamic>[];
    }
    if (res.statusCode == 404) return <dynamic>[];
    throw Exception('사용자 경로 조회 실패: ${res.statusCode}');
  }

  // ======================== 즐겨찾기 경로 조회 ========================
  static Future<List<dynamic>> fetchFavorites({required String userId}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/favorites?user_id=$userId'),
      headers: {"Content-Type": "application/json"},
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return (data is Map && data['favorites'] is List)
          ? List<dynamic>.from(data['favorites'])
          : <dynamic>[];
    }
    if (res.statusCode == 404) return <dynamic>[];
    throw Exception('즐겨찾기 조회 실패: ${res.statusCode}');
  }

  // ======================== 즐겨찾기 route_id 집합 조회 ========================
  // → SearchedScreen에서 초기 별 상태 백필용
  static Future<Set<int>> getFavoriteRouteIds({required String userId}) async {
    final favs = await fetchFavorites(userId: userId);
    final ids = <int>{};
    for (final r in favs) {
      final rid = int.tryParse((r['id'] ?? r['route_id']).toString());
      if (rid != null) ids.add(rid);
    }
    return ids;
  }

  // ======================== 경로 삭제 ========================
  static Future<void> deleteRoute({required int routeId}) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/delete_route/$routeId'),
      headers: {"Content-Type": "application/json"},
    );
    if (res.statusCode != 200) {
      throw Exception("경로 삭제 실패: ${res.statusCode}");
    }
  }

  // ======================== 즐겨찾기 토글 ========================
  static Future<Map<String, dynamic>> toggleFavorite({
    required String userId,
    required int routeId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/toggle_favorite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'route_id': routeId}),
    );
    if (res.statusCode == 200) {
      final data = _decodeBody(res);
      return {
        "message": data["message"] ?? "",
        "is_favorite": data["is_favorite"] == true,
        "favorite_count": (data["favorite_count"] is num)
            ? (data["favorite_count"] as num).toInt()
            : int.tryParse("${data["favorite_count"] ?? 0}") ?? 0,
      };
    }
    throw Exception('즐겨찾기 상태 변경 실패: ${res.statusCode}');
  }
}
