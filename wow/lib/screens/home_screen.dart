import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

// LoginPage import
import 'login_screen.dart';

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

  const HomeScreen({Key? key, required this.userId, required this.nickname}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  double? _temperature;
  double? _humidity;
  bool _isLoading = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initLocationAndWeather();
  }

  Future<void> _initLocationAndWeather() async {
    await _getCurrentLocation();
    await _fetchWeather();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          print("위치 권한 거부됨");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("위치 가져오기 실패: $e");
    }
  }

  Future<void> _fetchWeather() async {
    if (_currentPosition == null) return;

    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;

    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=temperature_2m,relative_humidity_2m";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temperature = data['hourly']['temperature_2m'][0].toDouble();
          _humidity = data['hourly']['relative_humidity_2m'][0].toDouble();
        });
      } else {
        print("날씨 정보 가져오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("날씨 정보 가져오기 실패: $e");
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()), // const 제거
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("메인 페이지"),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능 추가 예정
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('메뉴', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            const ListTile(title: Text("계정 정보")),
            const ListTile(title: Text("즐겨찾기 목록")),
            const ListTile(title: Text("경로 생성")),
            const ListTile(title: Text("생성한 경로 목록")),
            ListTile(
              title: const Text("로그 아웃"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(
                  _currentPosition?.latitude ?? 37.5665,
                  _currentPosition?.longitude ?? 126.9780,
                ),
                zoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_currentPosition != null)
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
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: const [
                    Icon(Icons.wb_sunny, size: 30),
                    Text("날씨"),
                  ],
                ),
                Column(
                  children: [
                    Text(
                        "온도: ${_temperature != null ? _temperature!.toStringAsFixed(1) : '-'} °C"),
                    Text(
                        "습도: ${_humidity != null ? _humidity!.toStringAsFixed(1) : '-'} %"),
                  ],
                ),
                Column(
                  children: const [
                    Icon(Icons.access_time, size: 30),
                    Text("시간별 예측"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
