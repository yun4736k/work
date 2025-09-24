import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'running_start.dart';
import 'package:wow/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'search_screen.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

Future<String> getPlaceNameFromLatLng(double lat, double lng) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lng);
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

  const HomeScreen({super.key, required this.userId, required this.nickname});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  final List<LatLng> _polylinePoints = [];
  final MapController _mapController = MapController();

  String? _currentRouteName;
  String? _currentNickname;
  bool _isFavorited = false;
  List<String> _lastSelectedCategories = [];

  // 날씨
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
      await _fetchWeather();
    }
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _lastSelectedCategories = saved;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showPermissionDialog("위치 서비스가 비활성화되어 있습니다. 설정에서 활성화하세요.");
      return;
    }

    var permission = await Geolocator.checkPermission();
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

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
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
        title: const Text("위치 권한 필요"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          ),
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text("설정으로 이동"),
          ),
        ],
      ),
    );
  }

  // ApiService 이용한 날씨 불러오기
  Future<void> _fetchWeather() async {
    if (_currentPosition == null) return;

    try {
      final data = await ApiService.fetchWeather(
        lat: _currentPosition!.latitude,
        lon: _currentPosition!.longitude,
      );

      if (!mounted) return;
      setState(() {
        _temperature = (data['current_weather']?['temperature'] as num?)?.toDouble();
        _humidity = data['hourly']?['relative_humidity_2m'] != null
            ? (data['hourly']['relative_humidity_2m'][0] as num?)?.toDouble()
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
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.settings),
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
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // 지도
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 18.0,
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
                    width: 40,
                    height: 40,
                    point: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 4.0,
                      color: const Color(0xFF577590),
                    ),
                  ],
                ),
            ],
          ),

          // 상단 날씨 바 (그라디언트 스타일)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.blue[50]!.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white70,
                  width: 1,
                ),
              ),
              child: _isLoadingWeather
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF3CAEA3)),
                  SizedBox(width: 12),
                  Text(
                    "날씨 불러오는 중...",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny,
                          color: Color(0xFFF76C5E), size: 28),
                      const SizedBox(width: 12),
                      Text(
                        "${_temperature != null ? _temperature!.toStringAsFixed(1) : '-'} °C",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Icon(Icons.opacity,
                          color: Color(0xFF577590), size: 24),
                      const SizedBox(width: 6),
                      Text(
                        "${_humidity != null ? _humidity!.toStringAsFixed(1) : '-'} %",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 가로 스크롤: 12시간 날씨 (데모)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(12, (i) {
                        final time =
                        DateTime.now().add(Duration(hours: i));
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Column(
                            children: [
                              Text(
                                DateFormat.Hm().format(time),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(Icons.wb_cloudy,
                                  color: Colors.grey[600], size: 18),
                              const SizedBox(height: 4),
                              Text(
                                "${((_temperature ?? 0) + i).toStringAsFixed(0)}°",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
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
                          builder: (context) => SearchScreen(
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "검색",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_currentPosition == null) return;

                      // 1) 경로 이름: 역지오코딩 시도 → 실패 시 기본값
                      String routeName;
                      try {
                        routeName = await getPlaceNameFromLatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        );
                        if (routeName.isEmpty ||
                            routeName == "주소 변환 실패" ||
                            routeName == "위치 정보 없음") {
                          routeName =
                          '산책 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
                        }
                      } catch (_) {
                        routeName =
                        '산책 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
                      }

                      // 2) 폴리라인: 비어 있으면 현재 위치 한 점으로 보장
                      final List<LatLng> defaultPolyline =
                      _polylinePoints.isNotEmpty
                          ? _polylinePoints
                          : [
                        LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                      ];

                      // 3) 러닝 화면으로 이동
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RunningStartScreen(
                            userId: widget.userId,
                            routeName:
                            routeName.isNotEmpty ? routeName : '새 산책',
                            polylinePoints: defaultPolyline,
                            intervalMinutes: 0,
                            intervalSeconds: 30,
                            // ✅ 홈에서만 시작 시 이름/카테고리 다이얼로그
                            promptNameOnStart: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "산책 시작",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
