import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;
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

  /// 알람(사운드/진동) 사용 여부 – 지도 우측 상단 버튼으로 토글
  bool _alarmEnabled = true;

  // 쇼카드
  final PageController _pageController = PageController(viewportFraction: 0.84);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _currentRouteName = widget.routeName;
  }

  @override
  void dispose() {
    _stopTracking();
    _audioPlayer.dispose();
    super.dispose();
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

  // ===== 알람 타이머 =====
  void _startAlarmTimer() async {
    final totalSeconds = widget.intervalMinutes * 60 + widget.intervalSeconds;
    if (!_alarmEnabled || totalSeconds <= 0) return;
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(Duration(seconds: totalSeconds), (timer) async {
      if (!_alarmEnabled) return;
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }
      try {
        await _audioPlayer.setAsset('assets/alert_sound.mp3');
        await _audioPlayer.play();
      } catch (_) {}
    });
  }

  void _stopAlarmTimer() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  // ======================

  void _startTracking() {
    setState(() {
      _isRunning = true;
    });

    // 알람
    _startAlarmTimer();

    // 경과 시간
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        calories = _elapsed.inMinutes * 4.0;
      });
    });

    // 위치 추적
    _trackingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
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
    _stopAlarmTimer();
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
      }
    } catch (_) {}
  }

  Future<void> _endTracking() async {
    _stopTracking();

    // 1) 경로명 입력
    final routeNameInput = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            '경로 이름 입력',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '예: 즐거운 산책',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text('경로 명을 입력해주세요!'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pop(context, input);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    // 2) 카테고리 선택
    final category = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String tempCategory = selectedCategory;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            '경로 유형 선택',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in ["짧은 산책로", "긴 산책로", "강변 산책로", "등산로", "공원 산책"])
                  RadioListTile<String>(
                    title: Text(c),
                    value: c,
                    groupValue: tempCategory,
                    onChanged: (v) => setState(() => tempCategory = v!),
                    activeColor: const Color(0xFF577590),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, tempCategory),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF3CAEA3),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );

    if (category != null && category.isNotEmpty) {
      selectedCategory = category;
    }
    if (routeNameInput == null || routeNameInput.isEmpty) return;

    _currentRouteName = routeNameInput;
    await _saveRouteToServer();

    final minutes = _elapsed.inSeconds / 60.0;
    final caloriesVal = (minutes * 4).toStringAsFixed(1);
    final distanceInKmVal = (_totalDistance / 1000).toStringAsFixed(2);
    final averageSpeed =
    minutes > 0 ? (_totalDistance / 1000) / (minutes / 60) : 0.0;
    final estimatedStepsVal = (_totalDistance / 0.75).round();

    // 3) 완료 다이얼로그 (Grid 2x2 + overflow 방지)
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8F4EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        title: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3CAEA3), Color(0xFF577590)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: const [
              CircleAvatar(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF3CAEA3),
                child: Icon(Icons.check_rounded),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '수고했어요! 산책 완료 🎉',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 경로명 + 카테고리 칩
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentRouteName ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2D2D2D),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pillChip(selectedCategory),
                  ],
                ),
                const SizedBox(height: 12),

                // 미니 지도 썸네일 (폭/높이 고정)
                _miniMapPreview(
                  context,
                  path: _walkedPath.isNotEmpty ? _walkedPath : widget.polylinePoints,
                ),

                const SizedBox(height: 12),

                // 2x2 그리드 카드 (고정 높이로 overflow 방지)
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 128, // 필요하면 120~140 사이에서 조정
                  ),
                  children: [
                    _statCardGrid(
                      icon: Icons.timer_outlined,
                      label: '총 시간',
                      value: _formatElapsed(_elapsed),
                      accent: const Color(0xFF577590),
                    ),
                    _statCardGrid(
                      icon: Icons.route_outlined,
                      label: '이동 거리',
                      value: '$distanceInKmVal km',
                      accent: const Color(0xFF3CAEA3),
                    ),
                    _statCardGrid(
                      icon: Icons.directions_run,
                      label: '걸음 수',
                      value: '$estimatedStepsVal 걸음',
                      accent: const Color(0xFF577590),
                    ),
                    _statCardGrid(
                      icon: Icons.local_fire_department_outlined,
                      label: '소모 칼로리',
                      value: '$caloriesVal kcal',
                      accent: const Color(0xFFF76C5E),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 참고 수치 한 줄(평균 속도)
                Row(
                  children: [
                    const Icon(Icons.speed, size: 18, color: Color(0xFF577590)),
                    const SizedBox(width: 6),
                    Text(
                      '평균 속도 ${averageSpeed.toStringAsFixed(2)} km/h',
                      style: const TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, {
                  'walkedPath': _walkedPath,
                  'elapsedTime': _elapsed,
                  'routeName': _currentRouteName,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ───────────────────── 헬퍼 위젯들 ─────────────────────

  Widget _pillChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF3CAEA3)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2D2D2D),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }



// 그리드용 카드 위젯
  Widget _statCardGrid({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF6B6B6B))),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── UI 조각 ─────────────

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // 쇼카드(원래 버전 – 버튼/푸터 없음)
  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required String unit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 6,
        color: const Color(0xFFF8F4EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.78,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF577590)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF577590),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 통계 카드 (다이얼로그 안에서 사용)
  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width * 0.9 - 16 * 2 - 10) / 2, // 2열
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF666666), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 미니맵(다이얼로그 내부) – 폭/높이를 고정해 intrinsic 측정 회피
  Widget _miniMapPreview(BuildContext context, {required List<LatLng> path}) {
    final center = path.isNotEmpty
        ? path.first
        : (_currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(37.5665, 126.9780));

    // 다이얼로그 content의 실제 폭(≈ 화면의 90%)에서 좌우 패딩(16*2)을 고려
    final double dialogWidth = MediaQuery.of(context).size.width * 0.9;
    final double mapWidth = dialogWidth - 32; // contentPadding 좌우 16+16
    const double mapHeight = 140;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: mapWidth,
        height: mapHeight,
        child: FlutterMap(
          options: MapOptions(
            center: center,
            zoom: 14,
            interactiveFlags: InteractiveFlag.none,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            if (path.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(points: path, strokeWidth: 3, color: Colors.blue),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ───────────── 화면 ─────────────

  @override
  Widget build(BuildContext context) {
    final distanceStr = distanceInKm.toStringAsFixed(2);
    final stepsStr = "$estimatedSteps";
    final caloriesStr = calories.toStringAsFixed(0);
    final elapsedStr = _formatElapsed(_elapsed);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
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
          // 상단 지도 (우측 상단에 음량 토글 버튼 오버레이)
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.polylinePoints.first,
                    initialZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.polylinePoints,
                          strokeWidth: 3.0,
                          color: Colors.grey.shade500,
                        ),
                        Polyline(
                          points: _walkedPath,
                          strokeWidth: 5.0,
                          color: Colors.lightBlue,
                        ),
                      ],
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
                            child: const Icon(Icons.my_location,
                                color: Colors.blue, size: 30),
                          ),
                        ],
                      ),
                  ],
                ),

                // ▶ 우측 상단 음량 토글 버튼
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 28,
                      icon: Icon(
                        _alarmEnabled ? Icons.volume_up : Icons.volume_off,
                        color: _alarmEnabled ? Colors.black87 : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _alarmEnabled = !_alarmEnabled);
                        if (_alarmEnabled) {
                          if (_isRunning) _startAlarmTimer();
                        } else {
                          _stopAlarmTimer();
                        }
                      },
                      tooltip: _alarmEnabled ? '알람 ON' : '알람 OFF',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 패널 (쇼카드)
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 170,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _metricCard(
                        title: "경과 시간",
                        value: elapsedStr,
                        icon: Icons.timer,
                        unit: "",
                      ),
                      _metricCard(
                        title: "이동 거리",
                        value: distanceStr,
                        icon: Icons.directions_walk,
                        unit: "km",
                      ),
                      _metricCard(
                        title: "걸음 수",
                        value: stepsStr,
                        icon: Icons.directions_run,
                        unit: "걸음",
                      ),
                      _metricCard(
                        title: "소모 칼로리",
                        value: caloriesStr,
                        icon: Icons.local_fire_department,
                        unit: "kcal",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final selected = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF3CAEA3)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                // 컨트롤 버튼
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
                        backgroundColor: _isRunning
                            ? const Color(0xFFF76C5E)
                            : const Color(0xFF3CAEA3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _endTracking,
                      icon: const Icon(Icons.stop),
                      label: const Text("종료"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
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
