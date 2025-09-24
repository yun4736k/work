// SettingsScreen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'login_screen.dart';
import 'package:wow/services/dialog_helper.dart';
import '../services/api_service.dart';
import 'running_start.dart';

// ─────────────────────────────────────────────────────
// ID 매핑 (사용자 제공 원본)
// ─────────────────────────────────────────────────────
final Map<String, int> regionToId = {
  '중구/광복동': 1, '중구/남포동': 2, '중구/대청동': 3, '중구/동광동': 4, '중구/보수동': 5, '중구/부평동': 6,
  '서구/동대신동': 7, '서구/서대신동': 8, '서구/암남동': 9, '서구/아미동': 10, '서구/토성동': 11,
  '동구/초량동': 12, '동구/수정동': 13, '동구/좌천동': 14, '동구/범일동': 15,
  '영도구/남항동': 16, '영도구/신선동': 17, '영도구/봉래동': 18, '영도구/청학동': 19, '영도구/동삼동': 20,
  '부산진구/부전동': 21, '부산진구/전포동': 22, '부산진구/양정동': 23, '부산진구/범전동': 24, '부산진구/범천동': 25, '부산진구/가야동': 26,
  '동래구/명장동': 27, '동래구/사직동': 28, '동래구/안락동': 29, '동래구/온천동': 30, '동래구/수안동': 31,
  '남구/대연동': 32, '남구/문현동': 33, '남구/감만동': 34, '남구/용호동': 35, '남구/우암동': 36,
  '북구/구포동': 37, '북구/덕천동': 38, '북구/만덕동': 39, '북구/화명동': 40,
  '해운대구/우동': 41, '해운대구/중동': 42, '해운대구/좌동': 43, '해운대구/송정동': 44, '해운대구/재송동': 45,
  '사하구/괴정동': 46, '사하구/당리동': 47, '사하구/하단동': 48, '사하구/장림동': 49, '사하구/다대동': 50,
  '금정구/장전동': 51, '금정구/구서동': 52, '금정구/부곡동': 53, '금정구/서동': 54, '금정구/금사동': 55,
  '강서구/명지동': 56, '강서구/가락동': 57, '강서구/녹산동': 58, '강서구/대저1동': 59, '강서구/대저2동': 60,
  '연제구/연산동': 61,
  '수영구/광안동': 62, '수영구/남천동': 63, '수영구/망미동': 64, '수영구/민락동': 65,
  '사상구/감전동': 66, '사상구/괘법동': 67, '사상구/덕포동': 68, '사상구/모라동': 69,
  '기장군/기장읍': 70, '기장군/정관읍': 71, '기장군/일광읍': 72, '기장군/철마면': 73, '기장군/장안읍': 74,
};

final Map<String, int> roadTypeToId = {
  '포장도로': 101, '비포장도로': 102, '등산로': 103, '짧은 산책로': 104, '긴 산책로': 105, '운동용 산책로': 106,
};

final Map<String, int> transportToId = {
  '걷기': 201, '뜀걸음': 202, '자전거': 203, '휠체어': 204, '유모차': 205,
};

// ─────────────────────────────────────────────────────
// 역매핑 (ID -> 한글 라벨)
// ─────────────────────────────────────────────────────
final Map<int, String> regionIdToName = {
  for (final e in regionToId.entries) e.value: e.key,
};
final Map<int, String> roadTypeIdToName = {
  for (final e in roadTypeToId.entries) e.value: e.key,
};
final Map<int, String> transportIdToName = {
  for (final e in transportToId.entries) e.value: e.key,
};

// ─────────────────────────────────────────────────────
// 화면
// ─────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  final String userId;
  final String nickname;
  const SettingsScreen({super.key, required this.userId, required this.nickname});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController newPwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  late String currentNickname;

  bool _isAccountVerified = false;
  String gender = '2';

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.grey[200],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              if (index == 3) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showLogoutConfirmation();
                });
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.account_circle), label: Text('계정 정보')),
              NavigationRailDestination(icon: Icon(Icons.star), label: Text('즐겨찾기')),
              NavigationRailDestination(icon: Icon(Icons.map), label: Text('경로 목록')),
              NavigationRailDestination(icon: Icon(Icons.logout), label: Text('로그아웃')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildAccountPage();
      case 1:
        return _buildRouteList(type: 'favorites');
      case 2:
        return _buildRouteList(type: 'routes');
      case 3:
        return const Center(child: Text("로그아웃 확인 중..."));
      default:
        return const Center(child: Text("메뉴를 선택하세요."));
    }
  }

  // ─────────────────────────────────────────────────────
  // 계정 정보 탭
  // ─────────────────────────────────────────────────────
  Widget _buildAccountPage() {
    const gap8 = SizedBox(height: 8);
    const gap12 = SizedBox(height: 12);
    const gap24 = SizedBox(height: 24);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildSectionTitle("비밀번호 변경"),
        gap8,
        _buildTextField(pwController, "현재 비밀번호", obscureText: true),
        gap8,
        _buildTextField(newPwController, "새 비밀번호", obscureText: true),
        gap8,
        _buildTextField(confirmPwController, "새 비밀번호 확인", obscureText: true),
        gap12,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3CAEA3),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text("비밀번호 변경", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),

        gap24,

        _buildSectionTitle("닉네임 변경"),
        gap8,
        _buildTextField(nicknameController, "새 닉네임"),
        gap12,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _changeNickname,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF577590),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text("닉네임 변경", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),

        gap24,

        _buildSectionTitle("계정 삭제"),
        gap8,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF76C5E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text("계정 삭제", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String labelText, {
        bool obscureText = false,
      }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // ─────────────────────────────────────────────────────
  // 즐겨찾기 / 경로 목록 공용 리스트
  // ─────────────────────────────────────────────────────
  Widget _buildRouteList({required String type}) {
    Future<List<dynamic>> fetchData() {
      if (type == 'favorites') {
        return ApiService.fetchFavorites(userId: widget.userId);
      }
      return ApiService.fetchUserRoutes(userId: widget.userId);
    }

    final bool isFavoritesMode = type == 'favorites';

    return FutureBuilder<List<dynamic>>(
      future: fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(isFavoritesMode ? "즐겨찾기된 경로가 없습니다." : "생성한 경로가 없습니다."));
        }

        final allRoutes = snapshot.data!;

        return ListView.builder(
          itemCount: allRoutes.length,
          itemBuilder: (context, index) {
            final route = allRoutes[index];

            // 안전한 키 접근
            final dynamic routeIdRaw = route['id'] ?? route['route_id'] ?? route['routeId'];
            final int? routeId = routeIdRaw == null ? null : int.tryParse(routeIdRaw.toString());

            final String routeName = (route['route_name'] ?? route['name'] ?? '이름 없음').toString();
            final dynamic routePathRaw = route['route_path'] ?? route['polyline'] ?? route['path'];

            // ── 여기서부터: 숫자/이름 모두 대응 → 라벨로 변환
            final String? regionRaw =
            _asOptString(route['region_id'] ?? route['regionId'] ?? route['region']);
            final String? roadTypeRaw =
            _asOptString(route['road_type_id'] ?? route['roadTypeId'] ?? route['road_type']);
            final String? transportRaw =
            _asOptString(route['transport_id'] ?? route['transportId'] ?? route['transport']);

            final String? regionLabel    = _labelFromIdOrName(regionRaw,    regionIdToName);
            final String? roadTypeLabel  = _labelFromIdOrName(roadTypeRaw,  roadTypeIdToName);
            final String? transportLabel = _labelFromIdOrName(transportRaw, transportIdToName);

            final bool isFavorite = _asBool(route['is_favorite'])
                || route['favorite_id'] != null
                || route['favorite_route_id'] != null;

            final List<String> tags = [
              if (regionLabel != null && regionLabel.isNotEmpty) '지역: $regionLabel',
              if (roadTypeLabel != null && roadTypeLabel.isNotEmpty) '도로: $roadTypeLabel',
              if (transportLabel != null && transportLabel.isNotEmpty) '이동: $transportLabel',
            ];

            final List<LatLng> routePath = _parseRoutePath(routePathRaw);
            final LatLng startPoint = routePath.isNotEmpty
                ? routePath.first
                : const LatLng(37.5665, 126.9780);

            return InkWell(
              onTap: () async {
                final confirmStart = await DialogHelper.showConfirmation(
                  context,
                  "산책 시작",
                  "'$routeName' 경로로 산책을 시작하시겠습니까?",
                );
                if (confirmStart == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RunningStartScreen(
                        userId: widget.userId,
                        routeName: routeName,
                        polylinePoints: routePath,
                        intervalMinutes: 1,
                        intervalSeconds: 0,
                      ),
                    ),
                  );
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (tags.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags
                                    .map(
                                      (t) => Chip(
                                    label: Text(t, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: const Color(0xFFF1ECF9),
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                )
                                    .toList(),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.star : Icons.star_border,
                                    color: Colors.orange,
                                  ),
                                  onPressed: routeId == null
                                      ? null
                                      : () async {
                                    try {
                                      await ApiService.toggleFavorite(
                                        userId: widget.userId,
                                        routeId: routeId,
                                      );
                                      DialogHelper.showMessage(context, "즐겨찾기 상태 변경 완료");
                                      setState(() {}); // 목록 갱신
                                    } catch (e) {
                                      DialogHelper.showMessage(context, "즐겨찾기 상태 변경 실패: $e");
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                // 삭제 버튼 (즐겨찾기는 토글로 제거, 경로는 실제 삭제)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFFD64C4C)),
                                  onPressed: () async {
                                    final ok = await DialogHelper.showConfirmation(
                                      context,
                                      isFavoritesMode ? "즐겨찾기 삭제" : "경로 삭제",
                                      isFavoritesMode
                                          ? "이 경로를 즐겨찾기에서 제거할까요?"
                                          : "이 경로를 완전히 삭제할까요?",
                                    );
                                    if (ok != true) return;

                                    try {
                                      if (isFavoritesMode) {
                                        if (routeId != null) {
                                          await ApiService.toggleFavorite(
                                            userId: widget.userId,
                                            routeId: routeId,
                                          );
                                        }
                                        DialogHelper.showMessage(context, "즐겨찾기에서 제거했습니다.");
                                      } else {
                                        if (routeId != null) {
                                          await ApiService.deleteRoute(routeId: routeId);
                                        }
                                        DialogHelper.showMessage(context, "경로를 삭제했습니다.");
                                      }
                                      setState(() {}); // 목록 갱신
                                    } catch (e) {
                                      DialogHelper.showMessage(context, "삭제 중 오류가 발생했습니다: $e");
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 90,
                          child: FlutterMap(
                            options: MapOptions(
                              center: startPoint,
                              zoom: 14,
                              interactiveFlags: InteractiveFlag.none,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: startPoint,
                                    width: 30,
                                    height: 30,
                                    child: const Icon(Icons.location_on, color: Color(0xFF3CAEA3), size: 26),
                                  ),
                                ],
                              ),
                              if (routePath.length >= 2)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(points: routePath, strokeWidth: 3, color: Colors.blueAccent),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  // truthy/falsey & 안전한 문자열 변환
  // ─────────────────────────────────────────────────────
  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'y' || s == 'yes';
    }
    return false;
  }

  String? _asOptString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  // ─────────────────────────────────────────────────────
  // 숫자 ID → 라벨 변환 (이미 라벨이면 그대로)
  // ─────────────────────────────────────────────────────
  String? _labelFromIdOrName(String? raw, Map<int, String> idToName) {
    if (raw == null || raw.trim().isEmpty) return null;

    // 이미 문자열 라벨로 오는 경우 그대로 사용
    if (int.tryParse(raw) == null) return raw;

    // 숫자 → 라벨
    final id = int.tryParse(raw);
    if (id == null) return null;
    return idToName[id];
  }

  // ─────────────────────────────────────────────────────
  // 경로 파싱 (route.route_path: JSON 문자열 또는 배열/객체 호환)
  // ─────────────────────────────────────────────────────
  List<LatLng> _parseRoutePath(dynamic raw) {
    dynamic data = raw;
    if (data == null) return const [];

    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return const [];
      }
    }

    if (data is List) {
      final List<LatLng> points = [];
      for (final p in data) {
        if (p is List && p.length >= 2) {
          final lat = (p[0] as num).toDouble();
          final lng = (p[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        } else if (p is Map) {
          final lat = (p['lat'] ?? p['latitude']);
          final lng = (p['lng'] ?? p['lon'] ?? p['longitude']);
          if (lat is num && lng is num) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      return points;
    }

    if (data is Map) {
      final inner = data['points'] ?? data['path'] ?? data['route_path'] ?? data['polyline'];
      return _parseRoutePath(inner);
    }

    return const [];
  }

  // ─────────────────────────────────────────────────────
  // 기타 액션
  // ─────────────────────────────────────────────────────
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDECEA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Color(0xFFD64C4C)),
              ),
              const SizedBox(width: 10),
              const Text(
                "로그아웃",
                style: TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: const Text(
            "정말 로그아웃하시겠습니까?",
            style: TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: const Color(0xFF577590),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("취소", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF76C5E),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text("로그아웃", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final id = widget.userId;
    final newPw = newPwController.text.trim();
    final confirmPw = confirmPwController.text.trim();

    if (pwController.text.trim().isEmpty || newPw.isEmpty || currentNickname.isEmpty) {
      DialogHelper.showMessage(context, "모든 항목을 입력해주세요.");
      return;
    }
    if (newPw != confirmPw) {
      DialogHelper.showMessage(context, "비밀번호가 일치하지 않습니다.");
      return;
    }

    try {
      final result = await ApiService.changePassword(
        id: id,
        currentPw: pwController.text.trim(),
        newPw: newPw,
        nickname: currentNickname,
        gender: int.tryParse(gender) ?? 2,
      );

      DialogHelper.showMessage(context, result["message"] ?? "비밀번호 변경 완료");

      if (result["nickname"] != null) {
        setState(() {
          currentNickname = result["nickname"];
          _isAccountVerified = true;
        });
      }
    } catch (e) {
      DialogHelper.showMessage(context, "오류: $e");
    }
  }

  void _changeNickname() async {
    final newNickname = nicknameController.text.trim();
    if (newNickname.isEmpty) {
      DialogHelper.showMessage(context, "새 닉네임을 입력해주세요.");
      return;
    }

    setState(() {
      currentNickname = newNickname;
    });
    DialogHelper.showMessage(context, "닉네임 변경 완료");
  }

  void _deleteAccount() {
    DialogHelper.showMessage(context, "계정 삭제 기능은 추후 구현 예정");
  }
}
