import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';
import 'package:geocoding/geocoding.dart'; // ★ 지역 역지오코딩

class RunningStartScreen extends StatefulWidget {
  final String userId;
  final String routeName;
  final List<LatLng> polylinePoints;
  final int intervalMinutes;
  final int intervalSeconds;

  // ✅ 홈에서만 시작 직후 이름/길유형/이동수단 다이얼로그를 띄울 때 사용
  final bool promptNameOnStart;   // 기본 false
  // ✅ 종료 시 요약 전에 이름/길유형/이동수단 받기 원하면 사용
  final bool promptNameOnFinish;  // 기본 false

  const RunningStartScreen({
    Key? key,
    required this.userId,
    required this.routeName,
    required this.polylinePoints,
    required this.intervalMinutes,
    required this.intervalSeconds,
    this.promptNameOnStart = false,
    this.promptNameOnFinish = false,
  }) : super(key: key);

  @override
  State<RunningStartScreen> createState() => _RunningStartScreenState();
}

class _RunningStartScreenState extends State<RunningStartScreen>
    with TickerProviderStateMixin {
  // ========== 상수 정의 ==========
  static const double _caloriesPerMinute = 4.0;
  static const double _stepsPerMeter = 1.33; // 0.75m당 1걸음 → 1m당 1.33걸음
  static const int _locationUpdateInterval = 1; // 초

  // ✅ 길 유형 & 이동수단 목록(표시용 라벨)
  static const List<String> _pathTypes = [
    "포장도로",
    "비포장도로",
    "등산로",
    "짧은 산책로",
    "긴 산책로",
    "운동용 산책로",
  ];
  static const List<String> _transportModes = [
    "걷기",
    "뜀걸음",
    "자전거",
    "휠체어",
    "유모차",
  ];

  // ✅ DB 스키마 맞춘 매핑 (라벨 → *_id 코드)
  static const Map<String, String> _roadTypeCode = {
    "포장도로": "01",
    "비포장도로": "02",
    "등산로": "03",
    "짧은 산책로": "04",
    "긴 산책로": "05",
    "운동용 산책로": "06",
  };
  static const Map<String, String> _transportCode = {
    "걷기": "01",
    "뜀걸음": "02",
    "자전거": "03",
    "휠체어": "04",
    "유모차": "05",
  };

  // ★ 지역 라벨 → ID 매핑 (부산)
  static const Map<String, int> _regionToId = {
    '중구/광복동': 1, '중구/남포동': 2, '중구/대청동': 3, '중구/동광동': 4, '중구/보수동': 5, '중구/부평동': 6,
    '서구/동대신동': 7, '서구/서대신동': 8, '서구/암남동': 9, '서구/아미동': 10, '서구/토성동': 11,
    '동구/초량동': 12, '동구/수정동': 13, '동구/좌천동': 14, '동구/범일동': 15,
    '영도구/남항동': 16, '영도구/신선동': 17, '영도구/봉래동': 18, '영도구/청학동': 19, '영도구/동삼동': 20,
    '부산진구/부전동': 21, '부산진구/전포동': 22, '부산진구/양정동': 23, '부산진구/범전동': 24, '부산진구/범천동': 25, '부산진구/가야동': 26,
    '동래구/명장동': 27, '동래구/사직동': 28, '동래구/안락동': 29, '동래구/온천동': 30, '동래구/수안동': 31,
    '남구/대연동': 32, '남구/문현동': 33, '남구/감만동': 34, '남구/용호동': 35, '남구/우암동': 36,
    '북구/구포동': 37, '북구/덕천동': 38, '북구/만덕동': 39, '북구/화명동': 40,
    '해운대구/우동': 41, '해운대구/중동': 42, '해운대구/좌동': 43, '해운대구/송정동': 44, '해운대구/재송동': 45,
    '사하구/괴정동': 46, '사하구/당리동': 47, '사하구/하단동': 48, '사하구/장림동': 49, '사하구/다대동': 50,
    '금정구/장전동': 51, '금정구/구서동': 52, '금정구/부곡동': 53, '금정구/서동': 54, '금정구/금사동': 55,
    '강서구/명지동': 56, '강서구/가락동': 57, '강서구/녹산동': 58, '강서구/대저1동': 59, '강서구/대저2동': 60,
    '연제구/연산동': 61,
    '수영구/광안동': 62, '수영구/남천동': 63, '수영구/망미동': 64, '수영구/민락동': 65,
    '사상구/감전동': 66, '사상구/괘법동': 67, '사상구/덕포동': 68, '사상구/모라동': 69,
    '기장군/기장읍': 70, '기장군/정관읍': 71, '기장군/일광읍': 72, '기장군/철마면': 73, '기장군/장안읍': 74,
  };

  // ========== 상태 변수 ==========
  // (변경) 복수 선택: 기본값은 한 개 선택된 상태로 시작
  List<String> _selectedCategories = ['포장도로'];   // 표시용 라벨(길 유형, 복수)
  String _selectedTransport = '걷기';               // 표시용 라벨(이동수단)
  String? _currentRouteName;
  Position? _currentPosition;
  final List<LatLng> _walkedPath = [];

  // 타이머들
  Timer? _trackingTimer;
  Timer? _elapsedTimer;
  Timer? _alarmTimer;

  // 운동 데이터
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  double _totalDistance = 0.0;
  bool _alarmEnabled = true;

  // UI 컨트롤러들
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.88);
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 애니메이션 컨트롤러들
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  int _currentPage = 0;

  // ========== 계산된 값들 (getter) ==========
  double get distanceInKm => _totalDistance / 1000;
  int get estimatedSteps => (_totalDistance * _stepsPerMeter).round();
  double get calories => _elapsed.inMinutes * _caloriesPerMinute;
  double get averageSpeed => _elapsed.inMinutes > 0
      ? (distanceInKm) / (_elapsed.inMinutes / 60)
      : 0.0;

  // (추가) 다중 카테고리 문자열 표시용
  String get categoriesText => _selectedCategories.join(', ');

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeScreen();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  void _initializeScreen() {
    _currentRouteName = widget.routeName;
    _getCurrentLocation();

    // 시작 시 입력(옵션)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.promptNameOnStart) {
        final rn = await _showRouteNameDialog();
        if (!mounted) return;

        final pathTypes = await _showCategoryMultiDialog(); // ★ 복수 선택
        if (!mounted) return;

        final transport = await _showTransportDialog(); // 단일 선택
        if (!mounted) return;

        setState(() {
          if (rn != null && rn.isNotEmpty) _currentRouteName = rn;
          if (pathTypes != null && pathTypes.isNotEmpty) _selectedCategories = pathTypes;
          if (transport != null && transport.isNotEmpty) _selectedTransport = transport;
        });
      }
    });
  }

  @override
  void dispose() {
    _stopAllTracking();
    _pulseController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ========== 위치 관련 ==========
  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          _showPermissionDialog();
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() => _currentPosition = position);
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
      }
    } catch (e) {
      _showErrorSnackBar('위치 정보를 가져올 수 없습니다');
    }
  }

  // ========== 추적 ==========
  void _startTracking() async {
    if (_isRunning) return;

    // ✅ 현재 위치 확보 & 경로 시드 1점 추가
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }
    if (_walkedPath.isEmpty && _currentPosition != null) {
      _walkedPath.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }

    setState(() => _isRunning = true);
    _pulseController.repeat(reverse: true);
    HapticFeedback.mediumImpact();

    _startElapsedTimer();
    _startLocationTracking();
    _startAlarmTimer();
  }

  void _stopTracking() {
    if (!_isRunning) return;

    setState(() => _isRunning = false);
    _pulseController.stop();
    HapticFeedback.lightImpact();

    _stopAllTimers();
  }

  void _stopAllTracking() {
    _isRunning = false;
    _stopAllTimers();
    _pulseController.stop();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  void _startLocationTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(
      const Duration(seconds: _locationUpdateInterval),
          (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    if (!_isRunning) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted || !_isRunning) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      // 거리 계산 및 업데이트
      if (_walkedPath.isNotEmpty) {
        final lastPoint = _walkedPath.last;
        final distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );

        // 최소 거리 필터링 (GPS 오차 방지)
        if (distance > 2) {
          _totalDistance += distance;
        }
      }

      setState(() {
        _currentPosition = position;
        _walkedPath.add(newPoint);
      });

      // 지도 중심 업데이트
      _mapController.move(newPoint, _mapController.camera.zoom);
    } catch (e) {
      // ignore
    }
  }

  void _startAlarmTimer() {
    if (!_alarmEnabled) return;

    final totalSeconds = widget.intervalMinutes * 60 + widget.intervalSeconds;
    if (totalSeconds <= 0) return;

    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(Duration(seconds: totalSeconds), (_) {
      if (_alarmEnabled && _isRunning) {
        _playAlarm();
      }
    });
  }

  Future<void> _playAlarm() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500, amplitude: 128);
      }
      await _audioPlayer.setAsset('assets/alert_sound.mp3');
      await _audioPlayer.play();
    } catch (_) {
      // ignore
    }
  }

  void _stopAllTimers() {
    _trackingTimer?.cancel();
    _elapsedTimer?.cancel();
    _alarmTimer?.cancel();
    _trackingTimer = null;
    _elapsedTimer = null;
    _alarmTimer = null;
  }

  // ========== 지역 태그/ID 해석 ==========
  /// 현재 위치(또는 지정 좌표)를 역지오코딩해 "구/동" 라벨과 region_id를 찾는다.
  Future<Map<String, String>?> _resolveRegionTag({LatLng? base}) async {
    // ✅ 기준 좌표 우선순위: 인자 → walkedPath.last → currentPosition → polylinePoints.first
    LatLng? target = base;
    target ??= _walkedPath.isNotEmpty ? _walkedPath.last : null;
    target ??= (_currentPosition != null)
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;
    target ??= widget.polylinePoints.isNotEmpty ? widget.polylinePoints.first : null;

    if (target == null) return null;

    try {
      final placemarks = await placemarkFromCoordinates(target.latitude, target.longitude);
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;

      // ⚠️ 기기/OS마다 필드가 다를 수 있으니 안전한 fallback
      // 보통: locality(구), subLocality(동) / 간혹 subAdministrativeArea(구), thoroughfare(도로명) 등이 섞임
      final guRaw   = (p.locality ?? p.subAdministrativeArea ?? '').trim();
      final dongRaw = (p.subLocality ?? p.thoroughfare ?? '').trim();

      final gu   = guRaw.replaceAll(' ', '');
      final dong = dongRaw.replaceAll(' ', '');

      if (gu.isEmpty || dong.isEmpty) return null;

      final label = '$gu/$dong';
      final id = _regionToId[label];
      if (id == null) return null;

      return {'region_label': label, 'region_id': id.toString()};
    } catch (_) {
      return null;
    }
  }

  // ========== 서버 통신 ==========
  Future<bool> _saveRouteToServer() async {
    // ✅ 저장용 경로 확보(우선순위: walkedPath → 현재위치 → 계획경로 첫점)
    List<LatLng> path = _walkedPath;
    if (path.isEmpty) {
      if (_currentPosition != null) {
        path = [LatLng(_currentPosition!.latitude, _currentPosition!.longitude)];
      } else if (widget.polylinePoints.isNotEmpty) {
        path = [widget.polylinePoints.first];
      }
    }

    if (path.isEmpty) {
      _showErrorSnackBar('저장할 좌표가 없습니다');
      return false;
    }

    // 대표 road_type_id는 첫 번째 선택값
    final primaryCategory = _selectedCategories.isNotEmpty
        ? _selectedCategories.first
        : '포장도로';

    final roadTypeId = _roadTypeCode[primaryCategory] ?? "01";
    final transportId = _transportCode[_selectedTransport] ?? "01";

    // ✅ 지역 태그는 "저장 기준 좌표(path.last)"로 역지오코딩
    final regionInfo = await _resolveRegionTag(base: path.last);
    final regionId = regionInfo?['region_id'] ?? "00";       // 못 찾으면 미지정
    final regionLabel = regionInfo?['region_label'];         // 참고용

    final body = {
      'user_id': widget.userId,
      'route_name': _currentRouteName ?? widget.routeName,
      'route_path': path.map((p) => [p.latitude, p.longitude]).toList(),

      // ★ 지역 정보
      'region_id': regionId,
      if (regionLabel != null) 'region_label': regionLabel,

      'road_type_id': roadTypeId,        // 대표 1개
      'roadTypeLabel': primaryCategory,
      'transport_id': transportId,
      'transportLabel': _selectedTransport,

      // 참고(서버가 무시해도 OK): 전체 선택 라벨 배열
      'category_labels': _selectedCategories,

      'distance_km': distanceInKm,
      'duration_minutes': _elapsed.inMinutes,
      'calories': calories,
      'steps': estimatedSteps,
    };

    try {
      final response = await http
          .post(
        Uri.parse('http://3.39.231.226:5000/add_route'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentRouteName = data['route_name'] ?? _currentRouteName;
        return true;
      }
    } catch (e) {
      _showErrorSnackBar('서버 저장에 실패했습니다');
    }
    return false;
  }

  // ========== UI 이벤트 ==========
  Future<void> _endTracking() async {
    _stopAllTracking();

    // 종료 전 입력(옵션)
    if (widget.promptNameOnFinish) {
      final routeName = await _showRouteNameDialog();
      if (routeName == null || routeName.isEmpty) return;

      final pathTypes = await _showCategoryMultiDialog(); // ★ 복수 선택
      if (pathTypes == null || pathTypes.isEmpty) return;

      final transport = await _showTransportDialog();
      if (transport == null || transport.isEmpty) return;

      _currentRouteName = routeName;
      _selectedCategories = pathTypes;
      _selectedTransport = transport;
    }

    _saveRouteToServer();          // 비동기 저장 시도
    await _showCompletionDialog(); // 완료 요약
  }

  void _toggleAlarm() {
    setState(() => _alarmEnabled = !_alarmEnabled);
    HapticFeedback.selectionClick();

    if (!_alarmEnabled) {
      _alarmTimer?.cancel();
    } else if (_isRunning) {
      _startAlarmTimer();
    }
  }

  // ========== 다이얼로그 ==========
  Future<String?> _showRouteNameDialog() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RouteNameDialog(),
    );
  }

  // (신규) 길 유형 복수 선택
  Future<List<String>?> _showCategoryMultiDialog() async {
    return await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MultiSelectDialog(
        titleText: '길 유형을 선택해주세요',
        options: _pathTypes,
        initialSelected: _selectedCategories,
        confirmText: '선택 완료',
      ),
    );
  }

  // 이동수단(단일 선택 유지)
  Future<String?> _showTransportDialog() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SingleSelectDialog(
        titleText: '이동 수단을 선택해주세요',
        initialValue: _selectedTransport,
        options: _transportModes,
        confirmText: '선택 완료',
      ),
    );
  }

  Future<void> _showCompletionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompletionDialog(
        routeName: _currentRouteName ?? '',
        category: categoriesText,              // ★ join된 문자열
        transportMode: _selectedTransport,     // 단일 라벨
        elapsed: _elapsed,
        distance: distanceInKm,
        steps: estimatedSteps,
        calories: calories,
        averageSpeed: averageSpeed,
        walkedPath:
        _walkedPath.isNotEmpty ? _walkedPath : widget.polylinePoints,
        onConfirm: () {
          Navigator.pop(context);
          Navigator.pop(context, {
            'walkedPath': _walkedPath,
            'elapsedTime': _elapsed,
            'routeName': _currentRouteName,
            'distance': distanceInKm,
            'calories': calories,
            'steps': estimatedSteps,
            // 호환성 + 확장성: 문자열과 배열 모두 제공
            'category': categoriesText,          // 기존 호환(문자열)
            'categories': _selectedCategories,   // 신규(리스트)
            'transport_mode': _selectedTransport,
          });
        },
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 서비스 필요'),
        content: const Text('위치 서비스를 활성화해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('앱에서 위치 정보를 사용할 수 있도록 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ========== 유틸 ==========
  String _formatElapsed(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  // ========== UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("🏃‍♂️", style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              "러닝 트래커",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
          ),
          child: IconButton(
            icon: Icon(
              _alarmEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _toggleAlarm,
            tooltip: _alarmEnabled ? '알람 켜짐' : '알람 꺼짐',
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Expanded(
            flex: 63,
            child: _buildMap(),
          ),
          Expanded(
            flex: 37,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.polylinePoints.isNotEmpty
              ? widget.polylinePoints.first
              : (_currentPosition != null
              ? LatLng(
              _currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(37.5665, 126.9780)),
          initialZoom: 17.0,
          maxZoom: 20.0,
          minZoom: 10.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          // 계획된 경로
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.polylinePoints,
                strokeWidth: 4.0,
                color: Colors.grey.shade400,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white,
              ),
            ],
          ),
          // 실제 걸은 경로
          PolylineLayer(
            polylines: [
              if (_walkedPath.isNotEmpty)
                Polyline(
                  points: _walkedPath,
                  strokeWidth: 6.0,
                  color: const Color(0xFF00BCD4),
                  borderStrokeWidth: 2.0,
                  borderColor: Colors.white,
                ),
            ],
          ),
          // 현재 위치 마커
          if (_currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 60,
                  height: 60,
                  point: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRunning ? _pulseAnimation.value : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                const Color(0xFF00BCD4).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFF8FAFB),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: _buildMetricsCarousel()),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildMetricsCarousel() {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildMetricCard(
                icon: Icons.timer_outlined,
                title: "경과 시간",
                value: _formatElapsed(_elapsed),
                unit: "",
                color: const Color(0xFF6C5CE7),
              ),
              _buildMetricCard(
                icon: Icons.route_outlined,
                title: "이동 거리",
                value: distanceInKm.toStringAsFixed(2),
                unit: "km",
                color: const Color(0xFF00BCD4),
              ),
              _buildMetricCard(
                icon: Icons.directions_run,
                title: "걸음 수",
                value: estimatedSteps.toString(),
                unit: "걸음",
                color: const Color(0xFF4CAF50),
              ),
              _buildMetricCard(
                icon: Icons.local_fire_department_outlined,
                title: "칼로리",
                value: calories.toStringAsFixed(0),
                unit: "kcal",
                color: const Color(0xFFFF7043),
              ),
            ],
          ),
        ),
        // 페이지 인디케이터
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFF00BCD4)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRunning ? Colors.green : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isRunning ? "실행 중" : "정지",
                  style: TextStyle(
                    color: _isRunning ? Colors.white : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                onPressed: _isRunning ? _stopTracking : _startTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isRunning ? const Color(0xFFFF7043) : const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: (_isRunning
                      ? const Color(0xFFFF7043)
                      : const Color(0xFF4CAF50))
                      .withOpacity(0.3),
                ),
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 24),
                label: Text(
                  _isRunning ? "일시정지" : "시작",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _endTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.stop, size: 24),
            label: const Text(
              "완료",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 단일 선택 다이얼로그 (이동수단에 사용) ==========
class _SingleSelectDialog extends StatefulWidget {
  final String titleText;
  final String initialValue;
  final List<String> options;
  final String confirmText;

  const _SingleSelectDialog({
    required this.titleText,
    required this.initialValue,
    required this.options,
    required this.confirmText,
  });

  @override
  State<_SingleSelectDialog> createState() => _SingleSelectDialogState();
}

class _SingleSelectDialogState extends State<_SingleSelectDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(
        widget.titleText,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.options.map((opt) {
          final isSelected = opt == _selected;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selected = opt),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00BCD4).withOpacity(0.1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00BCD4)
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? const Color(0xFF00BCD4)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt,
                        style: TextStyle(
                          fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF00BCD4)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              widget.confirmText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ========== 복수 선택 다이얼로그 (길 유형에 사용) ==========
class _MultiSelectDialog extends StatefulWidget {
  final String titleText;
  final List<String> options;
  final List<String> initialSelected;
  final String confirmText;

  const _MultiSelectDialog({
    required this.titleText,
    required this.options,
    required this.initialSelected,
    this.confirmText = '선택 완료',
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(
        widget.titleText,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.options.map((opt) {
            final checked = _selected.contains(opt);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (checked) {
                        _selected.remove(opt);
                      } else {
                        _selected.add(opt);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: checked ? const Color(0xFF00BCD4).withOpacity(0.08) : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: checked ? const Color(0xFF00BCD4) : Colors.grey.shade300,
                        width: checked ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: (_) {
                            setState(() {
                              if (checked) {
                                _selected.remove(opt);
                              } else {
                                _selected.add(opt);
                              }
                            });
                          },
                          activeColor: const Color(0xFF00BCD4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                              color: checked ? const Color(0xFF00BCD4) : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final result = _selected.toList();
                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '선택 완료',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ========== 이름 입력 다이얼로그 ==========
class _RouteNameDialog extends StatefulWidget {
  @override
  State<_RouteNameDialog> createState() => _RouteNameDialogState();
}

class _RouteNameDialogState extends State<_RouteNameDialog> {
  final _controller = TextEditingController();
  bool _isEmpty = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Text(
        '경로 이름을 입력해주세요',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '예: 아침 조깅',
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: Color(0xFF00BCD4), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
              errorText: _isEmpty ? '경로 이름을 입력해주세요' : null,
            ),
            onChanged: (value) {
              if (_isEmpty && value.isNotEmpty) {
                setState(() => _isEmpty = false);
              }
            },
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final input = _controller.text.trim();
                  if (input.isEmpty) {
                    setState(() => _isEmpty = true);
                  } else {
                    Navigator.pop(context, input);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ========== 완료 요약 다이얼로그 ==========
class _CompletionDialog extends StatelessWidget {
  final String routeName;
  final String category;       // 길 유형(라벨, 조인된 문자열)
  final String transportMode;  // 이동수단(라벨)
  final Duration elapsed;
  final double distance;
  final int steps;
  final double calories;
  final double averageSpeed;
  final List<LatLng> walkedPath;
  final VoidCallback onConfirm;

  const _CompletionDialog({
    required this.routeName,
    required this.category,
    required this.transportMode,
    required this.elapsed,
    required this.distance,
    required this.steps,
    required this.calories,
    required this.averageSpeed,
    required this.walkedPath,
    required this.onConfirm,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '운동 완료! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '수고하셨습니다',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 내용
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 경로명과 태그들
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('길 유형', category, const Color(0xFF00BCD4)),
                      _chip('이동 수단', transportMode, const Color(0xFF6C5CE7)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 미니 맵
                  _buildMiniMap(context),

                  const SizedBox(height: 20),

                  // 통계 그리드
                  _buildStatsGrid(),

                  const SizedBox(height: 16),

                  // 추가 정보
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.speed,
                          size: 20,
                          color: Color(0xFF6C5CE7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '평균 속도: ${averageSpeed.toStringAsFixed(1)} km/h',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(BuildContext context) {
    if (walkedPath.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: walkedPath.first,
            initialZoom: 15,
            interactiveFlags: InteractiveFlag.none,
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
                  points: walkedPath,
                  strokeWidth: 4,
                  color: const Color(0xFF00BCD4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          icon: Icons.timer_outlined,
          label: '운동 시간',
          value: _formatDuration(elapsed),
          color: const Color(0xFF6C5CE7),
        ),
        _buildStatCard(
          icon: Icons.route_outlined,
          label: '이동 거리',
          value: '${distance.toStringAsFixed(2)} km',
          color: const Color(0xFF00BCD4),
        ),
        _buildStatCard(
          icon: Icons.directions_run,
          label: '걸음 수',
          value: '$steps 걸음',
          color: const Color(0xFF4CAF50),
        ),
        _buildStatCard(
          icon: Icons.local_fire_department_outlined,
          label: '칼로리',
          value: '${calories.toStringAsFixed(0)} kcal',
          color: const Color(0xFFFF7043),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
