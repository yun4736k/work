import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'running_start.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow/services/dialog_helper.dart';
import 'package:geocoding/geocoding.dart';
import 'search_screen.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

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

  // 날씨 관련 변수
  bool _isLoadingWeather = true;
  double? _temperature;
  double? _humidity;

  @override
  void initState() {
    super.initState();
    _initLocationAndWeather();
    _loadSavedCategories();
  }

  Future<void> _initLocationAndWeather() async {
    await _getCurrentLocation();
    if (_currentPosition != null) {
      await _fetchWeather(); // ApiService 호출
    }
    setState(() {
      _isLoadingWeather = false;
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
      _showPermissionDialog(
          "위치 권한이 영구적으로 거부되었습니다. 설정에서 직접 변경해주세요.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("위치 가져오기 실패: $e");
    }
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
                child: Text("닫기")),
            TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: Text("설정으로 이동")),
          ],
        ));
  }

  // ApiService 이용한 날씨 불러오기
  Future<void> _fetchWeather() async {
    if (_currentPosition == null) return;

    try {
      final data = await ApiService.fetchWeather(
        lat: _currentPosition!.latitude,
        lon: _currentPosition!.longitude,
      );

      setState(() {
        _temperature = data['current_weather']['temperature']?.toDouble();
        _humidity = data['hourly']['relative_humidity_2m'] != null
            ? (data['hourly']['relative_humidity_2m'][0] as num).toDouble()
            : null;
      });
    } catch (e) {
      print("날씨 정보 가져오기 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
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
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // 지도
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(_currentPosition!.latitude,
                  _currentPosition!.longitude),
              zoom: 18.0,
            ),
            children: [
              TileLayer(
                  urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c']),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    child: Icon(Icons.location_pin,
                        color: Colors.red, size: 40),
                  )
                ],
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: _polylinePoints,
                        strokeWidth: 4.0,
                        color: Color(0xFF577590)),
                  ],
                ),
            ],
          ),

          // 상단 날씨 바
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: _isLoadingWeather
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: Color(0xFF3CAEA3)),
                  SizedBox(width: 12),
                  Text(
                    "날씨 불러오는 중...",
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny,
                          color: Color(0xFFF76C5E), size: 28),
                      SizedBox(width: 12),
                      Text(
                        "${_temperature != null ? _temperature!.toStringAsFixed(1) : '-'} °C",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D)),
                      ),
                      SizedBox(width: 24),
                      Icon(Icons.opacity,
                          color: Color(0xFF577590), size: 24),
                      SizedBox(width: 6),
                      Text(
                        "${_humidity != null ? _humidity!.toStringAsFixed(1) : '-'} %",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // 가로 스크롤: 12시간 날씨
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(12, (i) {
                        final time = DateTime.now()
                            .add(Duration(hours: i));
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Text(DateFormat.Hm().format(time),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87)),
                              SizedBox(height: 4),
                              Icon(Icons.wb_cloudy,
                                  color: Colors.grey[600], size: 18),
                              SizedBox(height: 4),
                              Text(
                                "${((_temperature ?? 0) + i).toStringAsFixed(0)}°",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 버튼 2개
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SearchScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("검색",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RunningStartScreen()),
                    );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("산책 시작",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
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
