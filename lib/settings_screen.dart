import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wow/services/dialog_helper.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;
  final String nickname;
  const SettingsScreen({super.key, required this.userId, required this.nickname});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedOption = '개인 경로 설정';
  TextEditingController nicknameController = TextEditingController();
  TextEditingController idController = TextEditingController();
  TextEditingController pwController = TextEditingController();
  TextEditingController newPwController = TextEditingController();
  TextEditingController confirmPwController = TextEditingController();

  late String currentNickname;

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
  }

  String gender = '2';

  final MapController _routeMapController = MapController();
  final List<LatLng> _routeMarkers = [];
  final List<LatLng> _routeLinePoints = [];
  bool _isAccountVerified = false;
  bool _isSidebarVisible = true;

  String selectedCategory = '짧은 산책로'; // 기본값 설정

  Widget _buildPrivacySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isAccountVerified) ...[
          _buildSectionTitle('아이디, 비밀번호 입력'),
          _buildTextField(idController, '아이디 입력'),
          SizedBox(height: 8),
          _buildTextField(pwController, '비밀번호 입력', obscureText: true),
          SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _checkAccountValid,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3CAEA3), // Highlight Teal
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        if (_isAccountVerified) ...[
          _buildSectionTitle('비밀번호 재설정'),
          _buildTextField(newPwController, '비밀번호 입력', obscureText: true),
          SizedBox(height: 8),
          _buildTextField(confirmPwController, '비밀번호 재입력', obscureText: true),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  final pw1 = newPwController.text.trim();
                  final pw2 = confirmPwController.text.trim();
                  final msg = (pw1 == pw2) ? "비밀번호 일치" : "비밀번호 불일치";
                  DialogHelper.showMessage(context, msg);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF577590), // Line Blue
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF76C5E), // Waypoint Red
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ]
      ],
    );
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
      body: Column(
        children: [
          Container(
            color: Color(0xFF3CAEA3).withOpacity(0.2),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTopMenuButton('개인정보 설정'),
                SizedBox(width: 16),
                _buildTopMenuButton('개인 경로 설정'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: selectedOption == '개인정보 설정'
                  ? _buildPrivacySettings()
                  : selectedOption == '개인 경로 설정'
                  ? _buildRouteSettings()
                  : Center(child: Text('설정을 선택하세요.', style: TextStyle(fontSize: 16))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMenuButton(String title) {
    return ElevatedButton(
      onPressed: () => setState(() => selectedOption = title),
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedOption == title ? Color(0xFF3CAEA3) : Colors.grey[300],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: Colors.black,
      ),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRouteSettings() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _routeMapController,
            options: MapOptions(
              initialCenter: LatLng(35.2171, 129.0190),
              initialZoom: 19.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (tapPosition, point) {
                setState(() {
                  _routeMarkers.add(point);
                  _routeLinePoints.add(point);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _routeMarkers
                    .map((point) => Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on, color: Color(0xFFF76C5E)),
                ))
                    .toList(),
              ),
              if (_routeLinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routeLinePoints, strokeWidth: 4.0, color: Color(0xFF577590)),
                  ],
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
                onPressed: () async {
                  final result = await _askRouteInfo();
                  if (result != null) {
                    final routeName = result['route'] ?? '';
                    final nickname = result['nickname'] ?? '';
                    final category = result['category'] ?? '기타';

                    if (routeName.isNotEmpty && nickname.isNotEmpty) {
                      setState(() {
                        selectedCategory = category; // ✅ 여기서 category 저장
                      });
                      await _sendRouteToServer(routeName, nickname);
                    } else {
                      DialogHelper.showMessage(context, '경로 이름과 사용자 아이디를 모두 입력하세요.');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3CAEA3), // Highlight Teal
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
                  backgroundColor: Color(0xFF577590), // Line Blue
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
                  backgroundColor: Color(0xFFF76C5E), // Waypoint Red
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
  Future<Map<String, String>?> _askRouteInfo() async {
    String routeName = '';
    String userNickname = '';
    String selectedCategory = '짧은 산책로'; // 기본값

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Text(
            '경로 정보 입력',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: '경로 이름',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) => routeName = value,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: '사용자 아이디',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) => userNickname = value,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: '경로 유형',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  '짧은 산책로',
                  '긴 산책로',
                  '강변 산책로',
                  '등산로',
                  '공원 산책'
                ]
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => Navigator.pop(context, {
                'route': routeName,
                'nickname': userNickname,
                'category': selectedCategory,
              }),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _sendRouteToServer(String routeName, String nickname) async {
    if (_routeLinePoints.isEmpty) return;

    final uri = Uri.parse('http://15.164.164.156:5000/add_route');
    final body = {
      'route_name': routeName,
      'route_path': _routeLinePoints.map((p) => [p.latitude, p.longitude]).toList(),
      'user_id': widget.userId,
      'category': selectedCategory,
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        DialogHelper.showMessage(context, '경로 전송 완료');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userId: widget.userId, nickname: currentNickname)),
        );
      } else {
        DialogHelper.showMessage(context, '서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      DialogHelper.showMessage(context, '전송 실패: $e');
    }
  }

  Future<void> _checkAccountValid() async {
    final id = idController.text.trim();
    final pw = pwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      DialogHelper.showMessage(context, "아이디와 비밀번호를 모두 입력해주세요.");
      return;
    }

    final uri = Uri.parse('http://13.209.17.39:5000/login');
    final body = jsonEncode({"ID": id, "PW": pw});

    try {
      final response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);
      final data = jsonDecode(response.body);

      DialogHelper.showMessage(context, data["message"]);

      if (data["message"].toString().contains("환영합니다")) {
        setState(() {
          _isAccountVerified = true;
        });
      }
    } catch (e) {
      DialogHelper.showMessage(context, "오류: $e");
    }
  }

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

    final uri = Uri.parse('http://13.209.17.39:5000/change');
    final body = jsonEncode({
      "ID": id,
      "PW": pwController.text.trim(),
      "NEW_PW": newPw,
      "NAME": currentNickname,
      "SEX": int.tryParse(gender) ?? 2
    });

    try {
      final response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);
      final data = jsonDecode(response.body);
      DialogHelper.showMessage(context, data["message"]);

      if (data["nickname"] != null) {
        setState(() {
          currentNickname = data["nickname"];
          _isAccountVerified = true;
        });
      }
      if (data["message"] == "계정 정보가 변경되었습니다.") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userId: widget.userId, nickname: currentNickname)),
        );
      }
    } catch (e) {
      DialogHelper.showMessage(context, "오류: $e");
    }
  }

  Widget _buildGenderSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _genderButton('남자', '0'),
        _genderButton('여자', '1'),
        _genderButton('비공개', '비공개'),
      ],
    );
  }

  Widget _genderButton(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => setState(() => gender = value),
        style: ElevatedButton.styleFrom(
          backgroundColor: gender == value ? Colors.blue : Colors.grey,
        ),
        child: Text(label, style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
