import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:wow/services/dialog_helper.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;
  final String nickname;
  const SettingsScreen({super.key, required this.userId, required this.nickname});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  TextEditingController nicknameController = TextEditingController();
  TextEditingController pwController = TextEditingController();
  TextEditingController newPwController = TextEditingController();
  TextEditingController confirmPwController = TextEditingController();
  TextEditingController routeNameController = TextEditingController();

  late String currentNickname;

  final MapController _routeMapController = MapController();
  final List<LatLng> _routeMarkers = [];
  final List<LatLng> _routeLinePoints = [];
  String selectedCategory = '짧은 산책로';

  Position? _currentPosition;
  bool _isAccountVerified = false;
  String gender = '2';

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("위치 정보를 가져올 수 없습니다: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D),
        title: Text('설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.grey[200],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              if (index == 4) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showLogoutConfirmation();
                });
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.account_circle), label: Text('계정 정보')),
              NavigationRailDestination(icon: Icon(Icons.star), label: Text('즐겨찾기')),
              NavigationRailDestination(icon: Icon(Icons.add_location_alt), label: Text('경로 생성')),
              NavigationRailDestination(icon: Icon(Icons.map), label: Text('경로 목록')),
              NavigationRailDestination(icon: Icon(Icons.logout), label: Text('로그아웃')),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
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
        return _buildRouteSettings();
      case 3:
        return _buildRouteList(type: 'routes');
      case 4:
        return Center(child: Text("로그아웃 확인 중..."));
      default:
        return Center(child: Text("메뉴를 선택하세요."));
    }
  }

  Widget _buildAccountPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("비밀번호 변경"),
          _buildTextField(pwController, "현재 비밀번호", obscureText: true),
          SizedBox(height: 8),
          _buildTextField(newPwController, "새 비밀번호", obscureText: true),
          SizedBox(height: 8),
          _buildTextField(confirmPwController, "새 비밀번호 확인", obscureText: true),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3CAEA3), foregroundColor: Colors.white),
            child: Text("비밀번호 변경"),
          ),
          SizedBox(height: 24),
          _buildSectionTitle("닉네임 변경"),
          _buildTextField(nicknameController, "새 닉네임"),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: _changeNickname,
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF577590), foregroundColor: Colors.white),
            child: Text("닉네임 변경"),
          ),
          SizedBox(height: 24),
          _buildSectionTitle("계정 삭제"),
          ElevatedButton(
            onPressed: _deleteAccount,
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF76C5E), foregroundColor: Colors.white),
            child: Text("계정 삭제"),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText, {bool obscureText = false}) {
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // ==================== 통합 경로 목록 (사용자 필터링 + 디자인 개선) ====================
  Widget _buildRouteList({required String type}) {
    Future<List<dynamic>> fetchData() {
      if (type == 'favorites') return ApiService.fetchFavorites(userId: widget.userId);
      return ApiService.fetchUserRoutes(userId: widget.userId);
    }

    bool isUserRoute = type == 'routes';

    return FutureBuilder<List<dynamic>>(
      future: fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(type == 'favorites'
                  ? "즐겨찾기된 경로가 없습니다."
                  : "생성한 경로가 없습니다."));
        }

        final allRoutes = snapshot.data!;

        // 경로 목록에서 사용자 ID 필터링
        final routes = allRoutes.where((route) => route['user_id'] == widget.userId).toList();

        if (routes.isEmpty) {
          return Center(child: Text("사용자가 생성한 경로가 없습니다."));
        }

        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final routeName = route['route_name'] ?? "이름 없음";
            final category = route['category'] ?? '';
            List<LatLng> routePath = [];

            if (route['route_path'] != null && (route['route_path'] as List).isNotEmpty) {
              routePath = (route['route_path'] as List)
                  .map<LatLng>((pair) => LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble()))
                  .toList();
            } else {
              routePath = [LatLng(37.5665, 126.9780)];
            }

            final startPoint = routePath.first;

            return Card(
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                          Text(routeName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D))),
                          SizedBox(height: 6),
                          Text(category,
                              style: TextStyle(color: Colors.grey[700], fontSize: 14, fontStyle: FontStyle.italic)),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              if (isUserRoute)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    DialogHelper.showMessage(context, "삭제 기능 호출됨");
                                    // 서버 삭제 API 호출 후 목록 새로고침 필요
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                    type == 'favorites' ? Icons.star : Icons.star_border,
                                    color: Colors.orange),
                                onPressed: () async {
                                  DialogHelper.showMessage(
                                      context, type == 'favorites' ? "즐겨찾기 해제" : "즐겨찾기 추가/제거");
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 120,
                        height: 90,
                        child: FlutterMap(
                          options: MapOptions(
                              center: startPoint,
                              zoom: 14,
                              interactiveFlags: InteractiveFlag.none),
                          children: [
                            TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: ['a', 'b', 'c']),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: startPoint,
                                  width: 30,
                                  height: 30,
                                  child: Icon(Icons.location_on, color: Color(0xFF3CAEA3), size: 26),
                                )
                              ],
                            ),
                            if (routePath.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(points: routePath, strokeWidth: 3, color: Colors.blueAccent)
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("로그아웃"),
          content: Text("정말 로그아웃하시겠습니까?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("취소")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              },
              child: Text("로그아웃"),
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

  Widget _buildRouteSettings() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(child: _buildTextField(routeNameController, "경로 이름")),
              SizedBox(width: 12),
              DropdownButton<String>(
                value: selectedCategory,
                items: ['짧은 산책로', '긴 산책로', '운동용 산책로']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedCategory = val);
                },
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _routeMapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : LatLng(35.2171, 129.0190),
              initialZoom: 19,
              onTap: (tapPos, point) {
                setState(() {
                  _routeMarkers.add(point);
                  _routeLinePoints.add(point);
                });
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a','b','c']),
              MarkerLayer(
                markers: _routeMarkers.map((point) => Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on, color: Color(0xFFF76C5E)),
                )).toList(),
              ),
              if (_routeLinePoints.length >= 2)
                PolylineLayer(
                  polylines: [Polyline(points: _routeLinePoints, strokeWidth: 4, color: Color(0xFF577590))],
                ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _saveRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3CAEA3),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('생성', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  if (_routeMarkers.isNotEmpty && _routeLinePoints.isNotEmpty) {
                    setState(() {
                      _routeMarkers.removeLast();
                      _routeLinePoints.removeLast();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF577590),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('취소', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _routeMarkers.clear();
                    _routeLinePoints.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF76C5E),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveRoute() async {
    final routeName = routeNameController.text.trim();
    if (routeName.isEmpty || _routeLinePoints.isEmpty) {
      DialogHelper.showMessage(context, "경로 이름과 위치를 모두 입력해주세요.");
      return;
    }

    try {
      await ApiService.saveRoute(
        userId: widget.userId,
        routeName: routeName,
        routePath: _routeLinePoints,
        category: selectedCategory,
      );

      setState(() {
        _routeMarkers.clear();
        _routeLinePoints.clear();
        routeNameController.clear();
      });

      DialogHelper.showMessage(context, "경로 저장 완료");
    } catch (e) {
      DialogHelper.showMessage(context, "경로 저장 실패: $e");
    }
  }
}
