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
  TextEditingController idController = TextEditingController();
  TextEditingController pwController = TextEditingController();
  TextEditingController newPwController = TextEditingController();
  TextEditingController confirmPwController = TextEditingController();

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
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
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
              NavigationRailDestination(
                  icon: Icon(Icons.account_circle), label: Text('계정 정보')),
              NavigationRailDestination(
                  icon: Icon(Icons.star), label: Text('즐겨찾기')),
              NavigationRailDestination(
                  icon: Icon(Icons.add_location_alt), label: Text('경로 생성')),
              NavigationRailDestination(
                  icon: Icon(Icons.map), label: Text('경로 목록')),
              NavigationRailDestination(
                  icon: Icon(Icons.logout), label: Text('로그아웃')),
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
        return _buildFavoriteRoutes();
      case 2:
        return _buildRouteSettings();
      case 3:
        return _buildUserRoutes();
      case 4:
        return Center(child: Text("로그아웃 확인 중..."));
      default:
        return Center(child: Text("메뉴를 선택하세요."));
    }
  }

  // ==================== 계정 정보 ====================
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3CAEA3), foregroundColor: Colors.white,
            ),
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

  // ==================== 즐겨찾기 목록 ====================
  Widget _buildFavoriteRoutes() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.fetchFavorites(userId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("즐겨찾기된 경로가 없습니다."));
        final favorites = snapshot.data!;
        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final fav = favorites[index];
            final routeName = fav['route_name'];
            final category = fav['category'] ?? '';
            final routePath = (fav['route_path'] as List).map<LatLng>((pair) =>
                LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble())
            ).toList();
            final startPoint = routePath.first;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(routeName, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                        SizedBox(height: 4),
                        Text(category, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                      ]),
                    ),
                    SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 100,
                        height: 80,
                        child: FlutterMap(
                          options: MapOptions(center: startPoint, zoom: 14, interactiveFlags: InteractiveFlag.none),
                          children: [
                            TileLayer(urlTemplate:'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a','b','c']),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: startPoint,
                                  width: 30,
                                  height: 30,
                                  child: Icon(Icons.location_on, color: Color(0xFF3CAEA3), size: 24),
                                )
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

  // ==================== 사용자 경로 목록 ====================
  Widget _buildUserRoutes() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.fetchUserRoutes(userId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("생성한 경로가 없습니다."));
        final routes = snapshot.data!;
        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final routeName = route['route_name'];
            final category = route['category'] ?? '';
            final routePath = (route['route_path'] as List).map<LatLng>((pair) =>
                LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble())
            ).toList();
            final startPoint = routePath.first;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(routeName, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                        SizedBox(height: 4),
                        Text(category, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                      ]),
                    ),
                    SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 100,
                        height: 80,
                        child: FlutterMap(
                          options: MapOptions(center: startPoint, zoom: 14, interactiveFlags: InteractiveFlag.none),
                          children: [
                            TileLayer(urlTemplate:'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a','b','c']),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: startPoint,
                                  width: 30,
                                  height: 30,
                                  child: Icon(Icons.location_on, color: Color(0xFF3CAEA3), size: 24),
                                )
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

  // ==================== 로그아웃 다이얼로그 ====================
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("로그아웃"),
          content: Text("정말 로그아웃하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("취소"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: Text("로그아웃"),
            ),
          ],
        );
      },
    );
  }

  // ==================== 비밀번호 변경 ====================
  Future<void> _changePassword() async {
    final id = idController.text.trim();
    final newPw = newPwController.text.trim();
    final confirmPw = confirmPwController.text.trim();

    if (id.isEmpty || pwController.text.trim().isEmpty || newPw.isEmpty || currentNickname.isEmpty) {
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

  void _deleteAccount() {
    DialogHelper.showMessage(context, "계정 삭제 기능은 추후 구현 예정");
  }

  // ==================== 경로 생성 ====================
  Widget _buildRouteSettings() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _routeMapController,
            options: MapOptions(
              initialCenter: LatLng(35.2171, 129.0190),
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
                onPressed: () async {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3CAEA3),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
