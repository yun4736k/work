import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  Widget _buildAccountPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("비밀번호 변경"),
          _buildTextField(pwController, "현재 비밀번호", obscureText: true),
          const SizedBox(height: 8),
          _buildTextField(newPwController, "새 비밀번호", obscureText: true),
          const SizedBox(height: 8),
          _buildTextField(confirmPwController, "새 비밀번호 확인", obscureText: true),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3CAEA3),
              foregroundColor: Colors.white,
            ),
            child: const Text("비밀번호 변경"),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("닉네임 변경"),
          _buildTextField(nicknameController, "새 닉네임"),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _changeNickname,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF577590),
              foregroundColor: Colors.white,
            ),
            child: const Text("닉네임 변경"),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("계정 삭제"),
          ElevatedButton(
            onPressed: _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF76C5E),
              foregroundColor: Colors.white,
            ),
            child: const Text("계정 삭제"),
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
        labelText: labelText, // <-- const 제거로 변수 사용 가능
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // ==================== 경로 목록 / 즐겨찾기 공용 리스트 ====================
  Widget _buildRouteList({required String type}) {
    Future<List<dynamic>> fetchData() {
      if (type == 'favorites') {
        return ApiService.fetchFavorites(userId: widget.userId);
      }
      return ApiService.fetchUserRoutes(userId: widget.userId);
    }

    final bool isUserRoute = type == 'routes';

    return FutureBuilder<List<dynamic>>(
      future: fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(type == 'favorites' ? "즐겨찾기된 경로가 없습니다." : "생성한 경로가 없습니다."));
        }

        final allRoutes = snapshot.data!;

        return ListView.builder(
          itemCount: allRoutes.length,
          itemBuilder: (context, index) {
            final route = allRoutes[index];
            final routeName = route['route_name'] ?? "이름 없음";
            final category = route['category'] ?? '';
            List<LatLng> routePath = [];

            if (route['route_path'] != null && (route['route_path'] as List).isNotEmpty) {
              routePath = (route['route_path'] as List)
                  .map<LatLng>((pair) => LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble()))
                  .toList();
            } else {
              routePath = const [LatLng(37.5665, 126.9780)];
            }

            final startPoint = routePath.first;

            return Card
              (
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (isUserRoute)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirmDelete = await DialogHelper.showConfirmation(
                                      context,
                                      "경로 삭제",
                                      "'$routeName' 경로를 삭제하시겠습니까?",
                                    );
                                    if (confirmDelete == true) {
                                      try {
                                        await ApiService.deleteRoute(routeId: route['id']);
                                        DialogHelper.showMessage(context, "경로 삭제 완료");
                                        setState(() {});
                                      } catch (e) {
                                        DialogHelper.showMessage(context, "경로 삭제 실패: $e");
                                      }
                                    }
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  route['is_favorite'] == true ? Icons.star : Icons.star_border,
                                  color: Colors.orange,
                                ),
                                onPressed: () async {
                                  try {
                                    await ApiService.toggleFavorite(
                                      userId: widget.userId,
                                      routeId: route['id'],
                                    );
                                    DialogHelper.showMessage(context, "즐겨찾기 상태 변경 완료");
                                    setState(() {});
                                  } catch (e) {
                                    DialogHelper.showMessage(context, "즐겨찾기 상태 변경 실패: $e");
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
          title: const Text("로그아웃"),
          content: const Text("정말 로그아웃하시겠습니까?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              },
              child: const Text("로그아웃"),
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
