import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'running_start.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow/services/dialog_helper.dart';
import 'package:geocoding/geocoding.dart';
import 'region_screen.dart' show RegionFilter, RegionFilterCriteria;

Future<String> getPlaceNameFromLatLng(double lat, double lng) async {
try {
List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
if (placemarks.isNotEmpty) {
final p = placemarks.first;
return "${p.administrativeArea ?? ''} ${p.locality ?? ''} ${p.street ?? ''}".trim();
} else {
return "위치 정보 없음";
}
} catch (e) {
print("역지오코딩 실패: $e");
return "주소 변환 실패";
}
}

class HomeScreen extends StatefulWidget {
final String userId;
final String nickname;

HomeScreen({required this.userId, required this.nickname});

@override
_HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
Position? _currentPosition;
List<LatLng> _polylinePoints = [];
final MapController _mapController = MapController();

String? _currentRouteName;
String? _currentNickname;
bool _isFavorited = false;
List<String> _lastSelectedCategories = [];

@override
void initState() {
  super.initState();
  _getCurrentLocation();
  _loadSavedCategories();

// 예: widget.userId가 로그인 아이디라면
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await RegionFilter.ensureSelected(context, widget.userId);
  });

}

Future<void> _saveSelectedCategories(List<String> categories) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setStringList('last_categories', categories);
}


Future<void> _loadSavedCategories() async {
final prefs = await SharedPreferences.getInstance();
final saved = prefs.getStringList('last_categories');
if (saved != null && saved.isNotEmpty) {
setState(() {
_lastSelectedCategories = saved;
});
}
}

Future<void> _showCategoryDialog(Function(List<String>) onConfirm) async {
final List<String> allCategories = [
'전체',
'짧은 산책로',
'긴 산책로',
'강변 산책로',
'등산로',
'공원 산책',
];
List<String> selected = List.from(_lastSelectedCategories);

await showDialog(
context: context,
builder: (context) {
return AlertDialog(
backgroundColor: Color(0xFFF8F4EC), // Canvas Beige 배경
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16), // 둥근 모서리
),
title: Text(
"카테고리 선택",
style: TextStyle(
color: Color(0xFF2D2D2D), // Ink Black
fontWeight: FontWeight.bold,
fontSize: 18,
),
),
content: StatefulBuilder(
builder: (context, setState) {
return SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: allCategories.map((category) {
return Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
),
margin: EdgeInsets.symmetric(vertical: 4),
child: CheckboxListTile(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
title: Text(
category,
style: TextStyle(
color: Color(0xFF2D2D2D),
fontSize: 15,
),
),
activeColor: Color(0xFF3CAEA3), // Highlight Teal 체크박스 색상
value: selected.contains(category),
onChanged: (checked) {
setState(() {
if (category == '전체') {
if (checked == true) {
selected = List.from(allCategories);
} else {
selected.clear();
}
} else {
if (checked == true) {
selected.add(category);
if (allCategories.every((cat) => selected.contains(cat))) {
if (!selected.contains('전체')) {
selected.add('전체');
}
}
} else {
selected.remove(category);
selected.remove('전체');
}
}
});
},
controlAffinity: ListTileControlAffinity.leading,
contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
),
);
}).toList(),
),
);
},
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
style: TextButton.styleFrom(
foregroundColor: Color(0xFF2D2D2D),
),
child: Text(
"취소",
style: TextStyle(fontWeight: FontWeight.bold),
),
),
ElevatedButton(
onPressed: () {
Navigator.pop(context);
onConfirm(selected);
},
style: ElevatedButton.styleFrom(
backgroundColor: Color(0xFF3CAEA3), // Highlight Teal
foregroundColor: Colors.white,
padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),
child: Text(
"확인",
style: TextStyle(fontWeight: FontWeight.bold),
),
),
],
);
}

);
}

Future<void> _fetchUserRecommendedRoute(List<String> categories) async {
  final categoryQuery = categories.join(',');
  final url = Uri.parse('http://15.164.164.156:5000/all_user_routes?category=$categoryQuery');

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) {
        DialogHelper.showMessage(context, "해당 카테고리의 경로가 없습니다.");
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8F4EC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "유저 추천 경로 선택",
              style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final routeData = data[index];
                  final String routeName = routeData['route_name'];
                  final String nickname = routeData['nickname'];
                  final List<LatLng> route = (routeData['route_path'] as List)
                      .map<LatLng>((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
                      .toList();

                  final LatLng startPoint = route.first;
                  String distanceText = "거리 정보 없음";
                  if (_currentPosition != null) {
                    final distanceInMeters = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      startPoint.latitude,
                      startPoint.longitude,
                    );
                    distanceText = "거리: ${(distanceInMeters / 1000).toStringAsFixed(2)} km";
                  }

                  return FutureBuilder<String>(
                    future: getPlaceNameFromLatLng(startPoint.latitude, startPoint.longitude),
                    builder: (context, snapshot) {
                      final locationName = snapshot.data ?? "주소 변환 중...";

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _polylinePoints = route;
                              _currentRouteName = routeName;
                              _currentNickname = nickname;
                            });
                            _checkIfFavorited();
                            if (route.isNotEmpty) {
                              _mapController.move(route.first, 18.0);
                            }
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(routeName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                                      const SizedBox(height: 4),
                                      Text("작성자: $nickname",
                                          style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                      Text("주소: $locationName",
                                          style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                      Text(distanceText,
                                          style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 100,
                                    height: 80,
                                    child: FlutterMap(
                                      options: MapOptions(
                                        center: route.first,
                                        zoom: 14,
                                        interactiveFlags: InteractiveFlag.none,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          subdomains: const ['a', 'b', 'c'],
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              width: 30,
                                              height: 30,
                                              point: route.first,
                                              child: const Icon(Icons.location_on,
                                                  color: Color(0xFF3CAEA3), size: 24),
                                            ),
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
              ),
            ),
          );
        },
      );
    } else {
      DialogHelper.showMessage(context, "서버 오류: ${response.statusCode}");
    }
  } catch (e) {
    DialogHelper.showMessage(context, "네트워크 오류: $e");
  }
}

Widget _buildStyledListTile(String title, IconData icon) {
return InkWell(
onTap: () async {
if (title == '최근 경로') {
final userId = widget.userId;
final url = Uri.parse('http://15.164.164.156:5000/recent_route?user_id=$userId');
try {
final response = await http.get(url);
if (response.statusCode == 200) {
final data = jsonDecode(response.body);
final List<dynamic> coords = data['route_path'];
final route = coords.map<LatLng>((pair) => LatLng(pair[0], pair[1])).toList();

setState(() {
_polylinePoints = route;
_currentRouteName = data['route_name'];
_currentNickname = data['nickname'];
});

_checkIfFavorited();

if (route.isNotEmpty) {
_mapController.move(route.first, 18.0);
}
} else {
DialogHelper.showMessage(context, "서버 응답 오류: ${response.statusCode}");
;
}
} catch (e) {
DialogHelper.showMessage(context, "네트워크 오류: $e");
;
}
Navigator.pop(context);

} else if (title == '공식 추천 경로') {
final route = [
LatLng(35.2183256, 129.0191574),
LatLng(35.2182421, 129.0196179),
LatLng(35.2180183, 129.0200183),
LatLng(35.2177006, 129.0202927),
LatLng(35.2173256, 129.0203927),
LatLng(35.2169506, 129.0202927),
LatLng(35.2166329, 129.0200183),
LatLng(35.2164091, 129.0196179),
LatLng(35.2163256, 129.0191574),
LatLng(35.2164091, 129.0186969),
LatLng(35.2166329, 129.0182965),
LatLng(35.2169506, 129.0180221),
LatLng(35.2173256, 129.0179221),
LatLng(35.2177006, 129.0180221),
LatLng(35.2180183, 129.0182965),
LatLng(35.2182421, 129.0186969),
LatLng(35.2183256, 129.0191574),
];

setState(() {
_polylinePoints = route;
_currentRouteName = null;
_currentNickname = null;
});
_checkIfFavorited();
_mapController.move(route.first, 18.0);
Navigator.pop(context);

} else if (title == '유저 추천 경로') {
// ✅ 카테고리 선택 후 추천 요청
await _showCategoryDialog((selectedCategories) async {
if (selectedCategories.isEmpty) {
DialogHelper.showMessage(context, '카테고리를 선택해주세요.');
;
return;
}

_lastSelectedCategories = selectedCategories;
await _fetchUserRecommendedRoute(_lastSelectedCategories);
await _saveSelectedCategories(_lastSelectedCategories);
});
Navigator.pop(context);

} else if (title == '즐겨찾기 경로') {
await _fetchFavoriteRoutesAndShowList();
}
},
child: Container(
padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
child: Row(
children: [
Icon(icon, color: Color(0xFF577590)),
SizedBox(width: 12),
Text(
title,
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
),
],
),
),
);
}

Future<void> _fetchFavoriteRoutesAndShowList() async {
  final url = Uri.parse('http://15.164.164.156:5000/all_favorites?user_id=${widget.userId}');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List favorites = data['favorites'];

      if (favorites.isEmpty) {
        DialogHelper.showMessage(context, "즐겨찾기된 경로가 없습니다.");
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8F4EC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "즐겨찾기 경로 선택",
              style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final fav = favorites[index];
                  final routeName = fav['route_name'];
                  final List<LatLng> route = (fav['route_path'] as List)
                      .map<LatLng>((pair) => LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble()))
                      .toList();

                  final LatLng startPoint = route.first;

                  String distanceText = "거리 정보 없음";
                  if (_currentPosition != null) {
                    final distanceInMeters = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      startPoint.latitude,
                      startPoint.longitude,
                    );
                    distanceText = "거리: ${(distanceInMeters / 1000).toStringAsFixed(2)} km";
                  }

                  return FutureBuilder<String>(
                    future: getPlaceNameFromLatLng(startPoint.latitude, startPoint.longitude),
                    builder: (context, snapshot) {
                      final locationName = snapshot.data ?? "주소 변환 중...";

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _polylinePoints = [...route];
                              _currentRouteName = routeName;
                              _currentNickname = widget.userId;
                            });
                            _checkIfFavorited();
                            if (route.isNotEmpty) {
                              _mapController.move(route.first, 18.0);
                            }
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(routeName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                                      const SizedBox(height: 4),
                                      Text("주소: $locationName",
                                          style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                      Text(distanceText,
                                          style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 100,
                                    height: 80,
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
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              width: 30,
                                              height: 30,
                                              point: startPoint,
                                              child: const Icon(Icons.location_on,
                                                  color: Color(0xFF3CAEA3), size: 24),
                                            ),
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
              ),
            ),
          );
        },
      );
    } else {
      DialogHelper.showMessage(context, "서버 오류: ${response.statusCode}");
    }
  } catch (e) {
    DialogHelper.showMessage(context, "네트워크 오류: $e");
  }
}

Future<void> _getCurrentLocation() async {
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
_showPermissionDialog("위치 서비스가 비활성화되어 있습니다. 설정에서 활성화하세요.");
return;
}

LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied) {
_showPermissionDialog("위치 권한이 필요합니다.");
return;
}
}
if (permission == LocationPermission.deniedForever) {
_showPermissionDialog("위치 권한이 영구적으로 거부되었습니다. 설정에서 직접 변경해주세요.");
return;
}

Position position = await Geolocator.getCurrentPosition();
setState(() {
_currentPosition = position;
});
}
void _showRunSetupDialog() {
String selectedIntensity = '보통';
final minuteController = TextEditingController();
final secondController = TextEditingController();

showDialog(
context: context,
builder: (context) {
return AlertDialog(
backgroundColor: Color(0xFFF8F4EC), // Canvas Beige
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Text(
"산책 시작 전 설정",
style: TextStyle(
fontWeight: FontWeight.bold,
color: Color(0xFF2D2D2D), // Ink Black
),
),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextField(
controller: minuteController,
keyboardType: TextInputType.number,
decoration: InputDecoration(
labelText: "분 간격",
labelStyle: TextStyle(color: Color(0xFF2D2D2D)),
border: OutlineInputBorder(
borderSide: BorderSide(color: Color(0xFF3CAEA3)), // Highlight Teal
borderRadius: BorderRadius.circular(10),
),
filled: true,
fillColor: Colors.white,
),
),
SizedBox(height: 12),
TextField(
controller: secondController,
keyboardType: TextInputType.number,
decoration: InputDecoration(
labelText: "초 간격",
labelStyle: TextStyle(color: Color(0xFF2D2D2D)),
border: OutlineInputBorder(
borderSide: BorderSide(color: Color(0xFF3CAEA3)),
borderRadius: BorderRadius.circular(10),
),
filled: true,
fillColor: Colors.white,
),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
style: TextButton.styleFrom(
foregroundColor: Color(0xFF2D2D2D), // Ink Black
),
child: Text(
"취소",
style: TextStyle(fontWeight: FontWeight.bold),
),
),
TextButton(
onPressed: () async {
final minutes = int.tryParse(minuteController.text) ?? 0;
final seconds = int.tryParse(secondController.text) ?? 0;

Navigator.pop(context);
final result = await Navigator.push(
context,
MaterialPageRoute(
builder: (context) => RunningStartScreen(
userId: widget.userId,
routeName: _currentRouteName ?? '이름 없는 경로',
polylinePoints: _polylinePoints.isNotEmpty
? _polylinePoints
    : (_currentPosition != null
? [LatLng(_currentPosition!.latitude, _currentPosition!.longitude)]
    : []),
intervalMinutes: minutes,
intervalSeconds: seconds,
),
),
);

if (result != null) {
setState(() {
_polylinePoints = List<LatLng>.from(result['walkedPath']);
_currentRouteName = result['routeName'];
_currentNickname = widget.userId;
});
}
_checkIfFavorited();
if (_polylinePoints.isNotEmpty) {
_mapController.move(_polylinePoints.first, 18.0);
}
},
style: TextButton.styleFrom(
foregroundColor: Colors.white,
backgroundColor: Color(0xFF3CAEA3), // Highlight Teal
padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
child: Text(
"시작",
style: TextStyle(fontWeight: FontWeight.bold),
),
),
],
);


},
);
}

void _showPermissionDialog(String message) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Text("위치 권한 필요"),
content: Text(message),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: Text("닫기"),
),
TextButton(
onPressed: () => Geolocator.openAppSettings(),
child: Text("설정으로 이동"),
),
],
),
);
}

Future<void> _checkIfFavorited() async {
if (_polylinePoints.isEmpty) return;

final uri = Uri.parse('http://15.164.164.156:5000/is_favorite');
final body = {
'user_id': widget.userId,
'route_name': _currentRouteName ?? '즐겨찾기_${DateTime.now().millisecondsSinceEpoch}',
'route_path': _polylinePoints.map((p) => [p.latitude, p.longitude]).toList(),
};

try {
final response = await http.post(uri,
headers: {"Content-Type": "application/json"},
body: jsonEncode(body));

if (response.statusCode == 200) {
final result = jsonDecode(response.body);
setState(() {
_isFavorited = result['is_favorite'] == true;
});
}
} catch (e) {
print("즐겨찾기 확인 오류: $e");
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
backgroundColor: Colors.black,   // ✅ 배경색 검정
iconTheme: IconThemeData(color: Colors.white), // ✅ 아이콘도 흰색으로
leading: IconButton(
icon: Icon(Icons.settings),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => SettingsScreen(
userId: widget.userId,
nickname: widget.nickname,
),
),
);
},
),
actions: [
IconButton(
icon: Icon(Icons.logout),
onPressed: () {
Navigator.pushReplacement(
context,
MaterialPageRoute(builder: (context) => LoginPage()),
);
},
),
],
),

body: Column(
children: [
Expanded(
flex: 5,
child: _currentPosition == null
? Center(child: CircularProgressIndicator())
    : Stack(
children: [
FlutterMap(
mapController: _mapController,
options: MapOptions(
initialCenter: LatLng(
_currentPosition!.latitude,
_currentPosition!.longitude,
),
initialZoom: 19.0,
),
children: [
TileLayer(
urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
subdomains: ['a', 'b', 'c'],
),
MarkerLayer(
markers: [
Marker(
point: LatLng(
_currentPosition!.latitude,
_currentPosition!.longitude,
),
width: 40,
height: 40,
child: Icon(Icons.location_pin, color: Colors.red, size: 40),
),
],
),
if (_polylinePoints.isNotEmpty)
PolylineLayer(
polylines: [
Polyline(points: _polylinePoints, strokeWidth: 4.0, color: Color(0xFF577590)),
],
),
],
),
if (_currentRouteName != null && _currentNickname != null)
Positioned(
top: 12,
left: 12,
child: Container(
padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: Colors.black54,
borderRadius: BorderRadius.circular(8),
),
child: Text(
'경로명: $_currentRouteName\n작성자: $_currentNickname',
style: TextStyle(color: Colors.white, fontSize: 14),
),
),
),
Positioned(
top: 12,
right: 12,
child: Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(8),
boxShadow: [
BoxShadow(
color: Colors.black26,
blurRadius: 4,
offset: Offset(2, 2),
),
],
),
child: IconButton(
icon: Icon(Icons.star, color: _isFavorited ? Colors.orange : Colors.grey),
iconSize: 28,
onPressed: () async {
if (_polylinePoints.isEmpty) {
DialogHelper.showMessage(context, "경로가 없습니다.");
return;
}

String routeName = '';
await showDialog(
context: context,
builder: (context) {
TextEditingController controller = TextEditingController();
return AlertDialog(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
backgroundColor: Colors.white,
title: Text(
"경로 이름 입력",
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: Colors.black87,
),
),
content: TextField(
controller: controller,
decoration: InputDecoration(
hintText: "예: 나의 산책로",
hintStyle: TextStyle(color: Colors.grey),
filled: true,
fillColor: Colors.grey[100],
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide.none,
),
contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
style: TextStyle(fontSize: 16),
),
actions: [
Padding(
padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
child: ElevatedButton(
onPressed: () {
routeName = controller.text.trim();
Navigator.pop(context);
},
style: ElevatedButton.styleFrom(
backgroundColor: Color(0xFF3CAEA3),
foregroundColor: Colors.white,
padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),
child: Text(
"저장",
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
),
),
],
);

},
);

if (routeName.isEmpty) return;

final uri = Uri.parse('http://15.164.164.156:5000/add_favorite');
final body = {
'user_id': widget.userId,
'route_name': routeName,
'route_path': _polylinePoints.map((p) => [p.latitude, p.longitude]).toList(),
};

try {
final response = await http.post(uri,
headers: {"Content-Type": "application/json"},
body: jsonEncode(body));

if (response.statusCode == 200) {
setState(() {
_isFavorited = true;
_currentRouteName = routeName;
});
DialogHelper.showMessage(context, "즐겨찾기에 추가됨");
} else {
DialogHelper.showMessage(context, "서버 오류");
}
} catch (e) {
DialogHelper.showMessage(context, "네트워크 오류: $e");
}
},
),
),
),

Positioned(
bottom: 12,
left: 0,
right: 0,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
// 경로 목록 열기 버튼
ElevatedButton(
onPressed: () {
showModalBottomSheet(
context: context,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
),
builder: (BuildContext context) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
_buildStyledListTile('최근 경로', Icons.history),
Divider(height: 1),
_buildStyledListTile('공식 추천 경로', Icons.verified),
Divider(height: 1),
_buildStyledListTile('유저 추천 경로', Icons.thumb_up),
Divider(height: 1),
_buildStyledListTile('즐겨찾기 경로', Icons.favorite),
],
);

},
);
},
style: ElevatedButton.styleFrom(
backgroundColor: Color(0xFF3CAEA3), // 진한 민트
foregroundColor: Colors.white,
padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 3,
),
child: Text(
'경로 목록 열기',
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
),
SizedBox(width: 16),
// 경로 시작 버튼
ElevatedButton(
onPressed: _showRunSetupDialog,
style: ElevatedButton.styleFrom(
backgroundColor: Color(0xFF577590), // 파랑톤
foregroundColor: Colors.white,
padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 3,
),
child: Text(
'경로 시작',
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
);
}
}