import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';

class RunningStartScreen extends StatefulWidget {
  final String userId;
  final String routeName;
  final List<LatLng> polylinePoints;
  final int intervalMinutes;
  final int intervalSeconds;

  const RunningStartScreen({
    super.key,
    required this.userId,
    required this.routeName,
    required this.polylinePoints,
    required this.intervalMinutes,
    required this.intervalSeconds,
  });

  @override
  _RunningStartScreenState createState() => _RunningStartScreenState();
}

class _RunningStartScreenState extends State<RunningStartScreen> {
  String selectedCategory = '짧은 산책로';
  String? _currentRouteName;
  Position? _currentPosition;
  final List<LatLng> _walkedPath = [];
  Timer? _trackingTimer;
  Timer? _elapsedTimer;
  Timer? _alarmTimer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  final MapController _mapController = MapController();
  double _totalDistance = 0.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double distanceInKm = 0.0;
  int estimatedSteps = 0;
  double calories = 0.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _currentRouteName = widget.routeName;
  }

  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });

    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapController.camera.zoom,
    );
  }

  void _startTracking() {
    setState(() {
      _isRunning = true;
    });

    final totalSeconds =
        widget.intervalMinutes * 60 + widget.intervalSeconds;
    if (totalSeconds > 0) {
      _alarmTimer =
          Timer.periodic(Duration(seconds: totalSeconds), (timer) async {
            print("🔔 알림 울림!");
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 500);
            }
            try {
              await _audioPlayer.setAsset('assets/alert_sound.mp3');
              await _audioPlayer.play();
            } catch (e) {
              print("오디오 재사용 오류: $e");
            }
          });
    }

    _elapsedTimer ??= Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += Duration(seconds: 1);
      });
    });

    _trackingTimer ??= Timer.periodic(Duration(seconds: 1), (_) async {
      await _getCurrentLocation();

      if (_currentPosition != null) {
        final newPoint =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

        if (_walkedPath.isNotEmpty) {
          final lastPoint = _walkedPath.last;
          final distance = Geolocator.distanceBetween(
            lastPoint.latitude,
            lastPoint.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );
          _totalDistance += distance;
        }

        setState(() {
          _walkedPath.add(newPoint);
          distanceInKm = _totalDistance / 1000;
          estimatedSteps = (_totalDistance / 0.75).round();
          calories = _elapsed.inMinutes * 4.0;
        });
      }
    });
  }

  void _stopTracking() {
    setState(() {
      _isRunning = false;
    });
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  String _formatElapsed(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0");
  }

  Future<void> _saveRouteToServer() async {
    final body = {
      'user_id': widget.userId,
      'route_name': _currentRouteName ?? widget.routeName,
      'route_path': _walkedPath.map((p) => [p.latitude, p.longitude]).toList(),
      'category': selectedCategory,
    };

    try {
      final response = await http.post(
        Uri.parse('http://15.164.164.156:5000/add_route'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverRouteName = data['route_name'];
        setState(() {
          _currentRouteName = serverRouteName;
        });
        print("서버에서 받은 유니크 경로명: $serverRouteName");
      } else {
        print("서버 저장 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("네트워크 오류: $e");
    }
  }

  Future<void> _endTracking() async {
    _stopTracking();

    final routeNameInput = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Text(
            '경로 이름 입력',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '예: 즐거운 산책',
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final input = controller.text.trim();
                      if (input.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFFF8F4EC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              '알림',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            content: const Text(
                              '경로 명을 입력해주세요!',
                              style: TextStyle(color: Colors.black87),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  '확인',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3CAEA3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        Navigator.pop(context, input);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3CAEA3),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      shadowColor: Colors.black45,
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ],
        );
      },
    );

    Widget _buildCategoryOption(String label, String groupValue, void Function(void Function()) setState) {
      return RadioListTile<String>(
        title: Text(
          label,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        activeColor: Color(0xFF577590),
        value: label,
        groupValue: groupValue,
        onChanged: (value) => setState(() => groupValue = value!),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
      );
    }

    final category = await showDialog<String>(
      context: context,
      barrierDismissible: false,
        builder: (context) {
          String tempCategory = selectedCategory;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            title: Text(
              '경로 유형 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            content: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text("짧은 산책로"),
                    value: "짧은 산책로",
                    groupValue: tempCategory,
                    onChanged: (value) => setState(() => tempCategory = value!),
                    activeColor: Color(0xFF577590),
                  ),
                  RadioListTile<String>(
                    title: Text("긴 산책로"),
                    value: "긴 산책로",
                    groupValue: tempCategory,
                    onChanged: (value) => setState(() => tempCategory = value!),
                    activeColor: Color(0xFF577590),
                  ),
                  RadioListTile<String>(
                    title: Text("강변 산책로"),
                    value: "강변 산책로",
                    groupValue: tempCategory,
                    onChanged: (value) => setState(() => tempCategory = value!),
                    activeColor: Color(0xFF577590),
                  ),
                  RadioListTile<String>(
                    title: Text("등산로"),
                    value: "등산로",
                    groupValue: tempCategory,
                    onChanged: (value) => setState(() => tempCategory = value!),
                    activeColor: Color(0xFF577590),
                  ),
                  RadioListTile<String>(
                    title: Text("공원 산책"),
                    value: "공원 산책",
                    groupValue: tempCategory,
                    onChanged: (value) => setState(() => tempCategory = value!),
                    activeColor: Color(0xFF577590),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, tempCategory),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Color(0xFF3CAEA3),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('확인', style: TextStyle(fontSize: 16)),
              ),
            ],
          );
        }
    );

    Widget _buildInfoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                "$label:",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Expanded(
              flex: 6,
              child: Text(
                value,
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

// 사용자가 선택하면 selectedCategory에 저장
    if (category != null && category.isNotEmpty) {
      selectedCategory = category;
    }

    if (routeNameInput == null || routeNameInput.isEmpty) return;

    _currentRouteName = routeNameInput;
    await _saveRouteToServer();

    final minutes = _elapsed.inSeconds / 60.0;
    final calories = (minutes * 4).toStringAsFixed(1);
    final distanceInKm = (_totalDistance / 1000).toStringAsFixed(2);
    final averageSpeed =
    minutes > 0 ? (_totalDistance / 1000) / (minutes / 60) : 0.0;
    final estimatedSteps = (_totalDistance / 0.75).round();

    showDialog(
      context: context,
      barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Text(
            '산책이 종료되었습니다.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow("경로명", _currentRouteName ?? "-"),
              _buildInfoRow("총 시간", _formatElapsed(_elapsed)),
              _buildInfoRow("이동 거리", "$distanceInKm km"),
              _buildInfoRow("평균 속도", "${averageSpeed.toStringAsFixed(2)} km/h"),
              _buildInfoRow("걸음 수 추정", "$estimatedSteps 걸음"),
              _buildInfoRow("소모 칼로리", "$calories kcal"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'walkedPath': _walkedPath,
                  'elapsedTime': _elapsed,
                  'routeName': _currentRouteName,
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('확인', style: TextStyle(fontSize: 16)),
            ),
          ],
        )
    );
  }

  @override
  void dispose() {
    _stopTracking();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildStatRow(IconData icon, String label, String value, {Color iconColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          SizedBox(width: 8),
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D), // Ink Black 배경
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white), // 뒤로가기 화살표 흰색
        title: Text(
          "🏞️ 산책 중",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.polylinePoints.first,
                initialZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: widget.polylinePoints,
                        strokeWidth: 4.0,
                        color: Colors.grey),
                    Polyline(
                        points: _walkedPath,
                        strokeWidth: 4.0,
                        color: Colors.lightBlue),
                  ],
                ),
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude),
                        child: Icon(Icons.my_location,
                            color: Colors.blue, size: 30),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade100,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Text(
                    _isRunning
                        ? "지금 상태: 🏃 산책 중"
                        : _elapsed.inSeconds == 0
                        ? "지금 상태: ⏸ 대기 중"
                        : "지금 상태: 😌 쉬는 중",
                    style: TextStyle(fontSize: 18, color: Color(0xFF2D2D2D)), // Ink Black
                  ),
                  SizedBox(height: 12),
                  Card(
                    color: Color(0xFFF8F4EC), // Canvas Beige
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildStatRow(Icons.timer, "경과 시간", _formatElapsed(_elapsed), iconColor: Color(0xFF577590)),
                          _buildStatRow(Icons.directions_walk, "이동 거리", "${distanceInKm.toStringAsFixed(2)} km", iconColor: Color(0xFF577590)),
                          _buildStatRow(Icons.directions_run, "걸음 수 추정", "$estimatedSteps 걸음", iconColor: Color(0xFF577590)),
                          _buildStatRow(Icons.local_fire_department, "소모 칼로리", "${calories.toStringAsFixed(0)} kcal", iconColor: Color(0xFF577590)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_isRunning) {
                            _stopTracking();
                          } else {
                            _startTracking();
                          }
                        },
                        icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(_isRunning ? "중지" : "시작"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Color(0xFFF76C5E) : Color(0xFF3CAEA3), // 빨강 or 민트
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _endTracking,
                        icon: Icon(Icons.stop),
                        label: Text("종료"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D2D2D), // Ink Black
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              )

          ),
        ],
      ),
    );
  }
}