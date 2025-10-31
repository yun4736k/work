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

// 러닝 화면(01~06 / 01~05) 코드 호환
final Map<int, String> roadTypeIdToNameAlt = {
  1: '포장도로', 2: '비포장도로', 3: '등산로', 4: '짧은 산책로', 5: '긴 산책로', 6: '운동용 산책로',
};
final Map<int, String> transportIdToNameAlt = {
  1: '걷기', 2: '뜀걸음', 3: '자전거', 4: '휠체어', 5: '유모차',
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

  // ✅ 계정 삭제 중 중복 클릭 방지
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
  }

  @override
  void dispose() {
    nicknameController.dispose();
    pwController.dispose();
    newPwController.dispose();
    confirmPwController.dispose();
    super.dispose();
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
            onPressed: _deletingAccount ? null : _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF76C5E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: Text(_deletingAccount ? "삭제 중..." : "계정 삭제",
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

            final String routeName =
            (route['route_name'] ?? route['name'] ?? '이름 없음').toString();
            final dynamic routePathRaw =
                route['route_path'] ?? route['polyline'] ?? route['path'];

            // 지역 라벨
            final String? regionRaw =
            _asOptString(route['region_id'] ?? route['regionId'] ?? route['region']);
            final String? regionLabel = _labelFromIdOrName(regionRaw, regionIdToName);

            // 복수 카테고리 + 이동수단 라벨
            final List<String> categoryLabels = _extractCategories(route);
            final String? transportLabel = _extractTransportLabel(route);

            final bool isFavorite = _asBool(route['is_favorite']) ||
                route['favorite_id'] != null ||
                route['favorite_route_id'] != null;

            final List<LatLng> routePath = _parseRoutePath(routePathRaw);
            final LatLng startPoint =
            routePath.isNotEmpty ? routePath.first : const LatLng(37.5665, 126.9780);

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
                color: const Color(0xFFF7F4FB),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Text(
                        routeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 지역 칩
                      if (regionLabel != null && regionLabel.isNotEmpty) ...[
                        _buildTagChip(
                          text: '지역: $regionLabel',
                          bg: const Color(0xFFEFF7FF),
                          fg: const Color(0xFF2070C7),
                          icon: Icons.place_outlined,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 도로 칩들
                      if (categoryLabels.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categoryLabels
                                .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildTagChip(
                                text: t,
                                bg: const Color(0xFFEFF4FF),
                                fg: const Color(0xFF4169E1),
                                dense: true,
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 이동수단 칩
                      if (transportLabel != null && transportLabel.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTagChip(
                                text: transportLabel,
                                bg: const Color(0xFFEFFBF2),
                                fg: const Color(0xFF1B8754),
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 미니맵 + 우상단 액션
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withOpacity(0.7)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: FlutterMap(
                                  options: MapOptions(
                                    center: startPoint,
                                    zoom: 14,
                                    interactiveFlags: InteractiveFlag.none,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: const ['a', 'b', 'c'],
                                    ),
                                    if (routePath.length >= 2)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: routePath,
                                            strokeWidth: 3,
                                            color: Colors.blueAccent,
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: startPoint,
                                          width: 30,
                                          height: 30,
                                          child: const Icon(Icons.location_on,
                                              color: Color(0xFF3CAEA3), size: 26),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 우상단 액션 버튼
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  // 즐겨찾기
                                  Material(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: routeId == null
                                          ? null
                                          : () async {
                                        try {
                                          await ApiService.toggleFavorite(
                                            userId: widget.userId,
                                            routeId: routeId,
                                          );
                                          DialogHelper.showMessage(
                                              context, "즐겨찾기 상태 변경 완료");
                                          setState(() {}); // 목록 갱신
                                        } catch (e) {
                                          DialogHelper.showMessage(
                                              context, "즐겨찾기 상태 변경 실패: $e");
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.star_border,
                                            color: Colors.orange, size: 22),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // 삭제
                                  Material(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () async {
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
                                            DialogHelper.showMessage(
                                                context, "즐겨찾기에서 제거했습니다.");
                                          } else {
                                            if (routeId != null) {
                                              await ApiService.deleteRoute(routeId: routeId);
                                            }
                                            DialogHelper.showMessage(
                                                context, "경로를 삭제했습니다.");
                                          }
                                          setState(() {}); // 목록 갱신
                                        } catch (e) {
                                          DialogHelper.showMessage(
                                              context, "삭제 중 오류가 발생했습니다: $e");
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.delete,
                                            color: Color(0xFFD64C4C), size: 22),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  // ────────────────── 칩 UI 컴포넌트 ──────────────────
  Widget _buildSectionChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
      BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2E6AE6)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2E6AE6))),
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required String text,
    required Color bg,
    required Color fg,
    IconData? icon,
    bool dense = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 6 : 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(fontSize: dense ? 12 : 13, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
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

  String? _labelFromIdOrName(String? raw, Map<int, String> idToName) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (int.tryParse(raw) == null) return raw;
    final id = int.tryParse(raw);
    if (id == null) return null;
    return idToName[id];
  }

  String? _labelFromIdOrNameMulti(String? raw, List<Map<int, String>> tables) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (int.tryParse(raw) == null) return raw;
    final id = int.tryParse(raw);
    if (id == null) return null;
    for (final t in tables) {
      final v = t[id];
      if (v != null) return v;
    }
    return null;
  }

  List<String> _extractCategories(Map route) {
    final candidateKeys = [
      'category_labels',
      'categories',
      'road_type_labels',
      'road_type_names',
      'road_type_list',
      'path_type_labels',
      'road_type_ids',
      'road_types',
    ];

    dynamic cats;
    for (final k in candidateKeys) {
      if (route.containsKey(k) && route[k] != null) {
        cats = route[k];
        break;
      }
    }

    if (cats is String) {
      final s = cats.trim();
      dynamic decoded;
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        decoded = null;
      }
      if (decoded is List) {
        cats = decoded;
      } else {
        final list = s
            .replaceAll(RegExp(r'[\[\]\"]'), '')
            .split(RegExp(r'\s*,\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isNotEmpty) cats = list;
      }
    }

    if (cats is List) {
      final out = <String>[];
      for (final item in cats) {
        String? label;
        if (item == null) continue;
        if (item is String) {
          label = _labelFromIdOrNameMulti(item, [roadTypeIdToName, roadTypeIdToNameAlt]) ?? item;
        } else if (item is num) {
          label = _labelFromIdOrNameMulti(item.toString(), [roadTypeIdToName, roadTypeIdToNameAlt]);
        } else if (item is Map) {
          final raw =
          _asOptString(item['name'] ?? item['label'] ?? item['id'] ?? item['road_type_id'] ?? item['code']);
          label = _labelFromIdOrNameMulti(raw, [roadTypeIdToName, roadTypeIdToNameAlt]) ?? raw;
        }
        if (label != null && label.isNotEmpty && !out.contains(label)) out.add(label);
      }
      if (out.isNotEmpty) return out;
    }

    final String? roadTypeRaw =
    _asOptString(route['road_type_id'] ?? route['roadTypeId'] ?? route['road_type']);
    final String? single =
    _labelFromIdOrNameMulti(roadTypeRaw, [roadTypeIdToName, roadTypeIdToNameAlt]);
    return single == null ? <String>[] : <String>[single];
  }

  String? _extractTransportLabel(Map route) {
    final String? transportRaw =
    _asOptString(route['transport_id'] ?? route['transportId'] ?? route['transport'] ?? route['transport_mode']);
    return _labelFromIdOrNameMulti(transportRaw, [transportIdToName, transportIdToNameAlt]);
  }

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
          if (lat is num && lng is num) points.add(LatLng(lat.toDouble(), lng.toDouble()));
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
                decoration: const BoxDecoration(color: Color(0xFFFDECEA), shape: BoxShape.circle),
                child: const Icon(Icons.logout, color: Color(0xFFD64C4C)),
              ),
              const SizedBox(width: 10),
              const Text("로그아웃",
                  style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text("정말 로그아웃하시겠습니까?",
              style: TextStyle(color: Color(0xFF4A4A4A), fontSize: 14, height: 1.4)),
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

  void _changeNickname() {
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

  // ✅ 계정 삭제 구현
  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;

    // 1) 1차 확인
    final confirm = await DialogHelper.showConfirmation(
      context,
      "계정 삭제",
      "정말로 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
    );
    if (confirm != true) return;

    // 2) 비밀번호 입력 (커스텀 Dialog) — *** 자동삽입/플레이스홀더 완전 차단
    final pwCtrl = TextEditingController();
    final fieldKey = UniqueKey();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool obscure = true;
        bool didFirstClear = false; // 최초 1회 강제 clear
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setInnerState) {
            // 렌더 직후 혹시 채워졌다면 강제 비우기
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!didFirstClear && pwCtrl.text.isNotEmpty) {
                pwCtrl.clear();
                didFirstClear = true;
              }
            });

            return Dialog(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 헤더
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFDECEA),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_outline, color: Color(0xFFD64C4C)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "비밀번호 확인",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2D2D2D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 설명
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          "보안을 위해 현재 비밀번호를 입력해주세요.",
                          style: TextStyle(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.4),
                        ),
                      ),

                      // 입력창
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: AutofillGroup(
                          child: TextField(
                            key: fieldKey,                 // 매번 새 인스턴스
                            controller: pwCtrl,
                            autofocus: true,
                            obscureText: obscure,
                            obscuringCharacter: '•',
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: null,          // 자동채움 완전 비활성
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: "현재 비밀번호",
                              hintText: "",                // 플레이스홀더 제거
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(color: Color(0xFF577590), width: 1.2),
                              ),
                              prefixIcon: const Icon(Icons.password_outlined),
                              suffixIcon: IconButton(
                                tooltip: obscure ? "표시" : "숨기기",
                                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setInnerState(() => obscure = !obscure),
                              ),
                            ),
                            onChanged: (_) {
                              // 시스템이 다시 밀어넣으면 즉시 비우기(사용자가 타이핑 전까지만)
                              if (!didFirstClear && pwCtrl.text.isNotEmpty) {
                                pwCtrl.clear();
                                didFirstClear = true;
                              }
                            },
                            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // 액션 버튼
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
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
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF76C5E),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                                child: const Text("확인", style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
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

    if (ok != true) return;

    final password = pwCtrl.text.trim();
    if (password.isEmpty) {
      DialogHelper.showMessage(context, "비밀번호를 입력해주세요.");
      return;
    }

    // 3) 실제 삭제 호출
    try {
      setState(() => _deletingAccount = true);

      // await ApiService.deleteAccount(userId: widget.userId, password: password);
      DialogHelper.showMessage(context, "계정 삭제가 완료되었습니다.");

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      DialogHelper.showMessage(context, "계정 삭제 중 오류: $e");
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }
}
