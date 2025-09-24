import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'more_path_screen.dart';
import 'running_start.dart';
import '../services/api_service.dart'; // 즐겨찾기 토글/백필 사용

class SearchedScreen extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic> selectedTags;
  final bool onlyFavorites;
  final List<dynamic> searchResults;

  const SearchedScreen({
    Key? key,
    this.userId,
    required this.selectedTags,
    required this.onlyFavorites,
    required this.searchResults,
  }) : super(key: key);

  @override
  _SearchedScreenState createState() => _SearchedScreenState();
}

class _SearchedScreenState extends State<SearchedScreen> {
  Map<String, dynamic>? selectedRoute;
  Position? currentPosition;
  final MapController _mapController = MapController();

  // 즐겨찾기 상태/카운트 로컬 캐시
  final Map<int, bool> _favoriteStates = {};
  final Map<int, int> _favoriteCounts = {};

  // ID → 이름 매핑
  final Map<int, String> idToRegion = {
    1: '중구/광복동', 2: '중구/남포동', 3: '중구/대청동', 4: '중구/동광동', 5: '중구/보수동', 6: '중구/부평동',
    7: '서구/동대신동', 8: '서구/서대신동', 9: '서구/암남동', 10: '서구/아미동', 11: '서구/토성동',
    12: '동구/초량동', 13: '동구/수정동', 14: '동구/좌천동', 15: '동구/범일동',
    16: '영도구/남항동', 17: '영도구/신선동', 18: '영도구/봉래동', 19: '영도구/청학동', 20: '영도구/동삼동',
    21: '부산진구/부전동', 22: '부산진구/전포동', 23: '부산진구/양정동', 24: '부산진구/범전동', 25: '부산진구/범천동', 26: '부산진구/가야동',
    27: '동래구/명장동', 28: '동래구/사직동', 29: '동래구/안락동', 30: '동래구/온천동', 31: '동래구/수안동',
    32: '남구/대연동', 33: '남구/문현동', 34: '남구/감만동', 35: '남구/용호동', 36: '남구/우암동',
    37: '북구/구포동', 38: '북구/덕천동', 39: '북구/만덕동', 40: '북구/화명동',
    41: '해운대구/우동', 42: '해운대구/중동', 43: '해운대구/좌동', 44: '해운대구/송정동', 45: '해운대구/재송동',
    46: '사하구/괴정동', 47: '사하구/당리동', 48: '사하구/하단동', 49: '사하구/장림동', 50: '사하구/다대동',
    51: '금정구/장전동', 52: '금정구/구서동', 53: '금정구/부곡동', 54: '금정구/서동', 55: '금정구/금사동',
    56: '강서구/명지동', 57: '강서구/가락동', 58: '강서구/녹산동', 59: '강서구/대저1동', 60: '강서구/대저2동',
    61: '연제구/연산동',
    62: '수영구/광안동', 63: '수영구/남천동', 64: '수영구/망미동', 65: '수영구/민락동',
    66: '사상구/감전동', 67: '사상구/괘법동', 68: '사상구/덕포동', 69: '사상구/모라동',
    70: '기장군/기장읍', 71: '기장군/정관읍', 72: '기장군/일광읍', 73: '기장군/철마면', 74: '기장군/장안읍',
  };

  final Map<int, String> idToRoadType = {
    101: '포장도로', 102: '비포장도로', 103: '등산로', 104: '짧은 산책로', 105: '긴 산책로', 106: '운동용 산책로',
  };

  final Map<int, String> idToTransport = {
    201: '걷기', 202: '뜀걸음', 203: '자전거', 204: '휠체어', 205: '유모차',
  };

  @override
  void initState() {
    super.initState();
    _primeFavoriteStates();
    _getCurrentLocation();
    _sortRoutes();
    _backfillFavoritesFromServer(); // ✅ 서버에서 내 즐겨찾기 목록으로 보정
  }

  /// 서버 응답에 포함된 is_favorite / favorite_count 초기화
  void _primeFavoriteStates() {
    final Map<int, bool> favStates = {};
    final Map<int, int> favCounts = {};

    for (final r in widget.searchResults) {
      final id = (r['id'] ?? r['route_id'])?.toString();
      if (id == null) continue;
      final rid = int.tryParse(id);
      if (rid == null) continue;

      bool isFav = r['is_favorite'] == true;
      // onlyFavorites 화면에서는 true 보정
      if (!isFav && widget.onlyFavorites && (widget.userId != null && widget.userId!.isNotEmpty)) {
        isFav = true;
      }

      final count = (r['favorite_count'] is int)
          ? r['favorite_count'] as int
          : int.tryParse(r['favorite_count']?.toString() ?? '0') ?? 0;

      favStates[rid] = isFav;
      favCounts[rid] = count;
    }

    setState(() {
      _favoriteStates
        ..clear()
        ..addAll(favStates);
      _favoriteCounts
        ..clear()
        ..addAll(favCounts);
    });
  }

  /// ✅ 서버에서 내 즐겨찾기 목록을 가져와서 보정
  Future<void> _backfillFavoritesFromServer() async {
    if (widget.userId == null || widget.userId!.isEmpty) return;

    try {
      final favIds = await ApiService.getFavoriteRouteIds(userId: widget.userId!);
      setState(() {
        for (final r in widget.searchResults) {
          final rid = int.tryParse((r['id'] ?? r['route_id']).toString());
          if (rid == null) continue;
          final isFav = favIds.contains(rid);
          _favoriteStates[rid] = isFav;
          r['is_favorite'] = isFav;
        }
      });
    } catch (e) {
      print('[favorites backfill error] $e');
    }
  }

  void _sortRoutes() {
    widget.searchResults.sort((a, b) {
      final nameA = a['route_name'] ?? '';
      final nameB = b['route_name'] ?? '';
      return nameA.compareTo(nameB);
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) return;
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      currentPosition = pos;
    });
    _fitMapBounds();
  }

  void _fitMapBounds() {
    final List<LatLng> pts = [];
    if (currentPosition != null) {
      pts.add(LatLng(currentPosition!.latitude, currentPosition!.longitude));
    }
    if (selectedRoute != null) {
      pts.addAll(_convertToLatLngList(selectedRoute!['route_path']));
    }
    if (pts.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(pts);
      _mapController.fitBounds(bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(50)));
    }
  }

  // 즐겨찾기 토글
  Future<void> _toggleFavorite(Map<String, dynamic> route) async {
    final uid = widget.userId;
    final rid = int.tryParse((route['id'] ?? route['route_id']).toString());
    if (uid == null || uid.isEmpty || rid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 즐겨찾기를 사용할 수 있어요.')),
      );
      return;
    }

    try {
      final resp = await ApiService.toggleFavorite(userId: uid, routeId: rid);
      final bool newIsFav =
          resp['is_favorite'] == true || resp['isFavorite'] == true;
      final int newCount = (resp['favorite_count'] is int)
          ? resp['favorite_count'] as int
          : int.tryParse(resp['favorite_count']?.toString() ?? '0') ?? 0;

      setState(() {
        _favoriteStates[rid] = newIsFav;
        _favoriteCounts[rid] = newCount;

        if (selectedRoute != null &&
            (selectedRoute!['id']?.toString() == rid.toString())) {
          selectedRoute!['is_favorite'] = newIsFav;
          selectedRoute!['favorite_count'] = newCount;
        }

        for (final r in widget.searchResults) {
          if ((r['id'] ?? r['route_id']).toString() == rid.toString()) {
            r['is_favorite'] = newIsFav;
            r['favorite_count'] = newCount;
            break;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 변경 실패: $e')),
      );
    }
  }


@override
  Widget build(BuildContext context) {
    final routesToShow = (widget.searchResults.length > 3
        ? widget.searchResults.sublist(0, 3)
        : widget.searchResults)
        .cast<Map<String, dynamic>>();

    final canStart = selectedRoute != null &&
        _convertToLatLngList(selectedRoute!['route_path']).isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('지도 (선택 경로)', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 선택된 태그 표시
          if (widget.selectedTags.values.any((v) => v.isNotEmpty))
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _buildSelectedTagChips(),
              ),
            ),

          // 상단 지도
          Expanded(
            flex: 4,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: currentPosition != null
                    ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
                    : const LatLng(35.1796, 129.0756),
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (selectedRoute != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _convertToLatLngList(selectedRoute!['route_path']),
                        color: Colors.blueAccent.shade400,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.7),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 선택된 경로 카드 (선택된 경우에만 표시)
          if (selectedRoute != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSelectedRouteCard(selectedRoute!),
            ),
          if (selectedRoute != null) const SizedBox(height: 8),

          // 경로 목록
          Expanded(
            flex: 5,
            child: ListView.builder(
              itemCount: routesToShow.length + 1,
              itemBuilder: (context, index) {
                if (index == routesToShow.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MorePathScreen(
                                allRoutes:
                                widget.searchResults.cast<Map<String, dynamic>>(),
                                selectedTags: widget.selectedTags
                                    .map((key, value) => MapEntry(key, value.toString())),
                                onRouteSelected: (route) {
                                  setState(() {
                                    selectedRoute = route;
                                  });
                                  _fitMapBounds();
                                },
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF577590),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '더 많은 경로 보기',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }

                final route = routesToShow[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedRoute = route;
                    });
                    _fitMapBounds();
                  },
                  child: _buildListRouteCard(route, isSelected: selectedRoute == route),
                );
              },
            ),
          ),

          // 하단 고정: 선택 경로로 시작 버튼
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFFF5F7FA),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canStart
                      ? () {
                    final pts =
                    _convertToLatLngList(selectedRoute!['route_path']);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RunningStartScreen(
                          userId: widget.userId ?? 'guest',
                          routeName:
                          selectedRoute!['route_name'] ?? '선택 경로',
                          polylinePoints: pts,
                          intervalMinutes: 1,
                          intervalSeconds: 0,
                          promptNameOnStart: false,
                        ),
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('선택한 경로로 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3CAEA3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedTagChips() {
    final List<Widget> chips = [];

    widget.selectedTags.forEach((category, ids) {
      if (ids is List && ids.isNotEmpty) {
        for (final id in ids) {
          String label;
          if (category == '지역') {
            label = idToRegion[int.tryParse(id.toString()) ?? 0] ?? '';
          } else if (category == '길 유형') {
            label = idToRoadType[int.tryParse(id.toString()) ?? 0] ?? '';
          } else if (category == '이동수단') {
            label = idToTransport[int.tryParse(id.toString()) ?? 0] ?? '';
          } else {
            label = id.toString();
          }

          if (label.isNotEmpty) {
            chips.add(
              Chip(
                label: Text(label,
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
                backgroundColor: Colors.grey.shade200,
              ),
            );
          }
        }
      }
    });

    return chips;
  }

  Widget _buildSelectedRouteCard(Map<String, dynamic> route) {
    final routeName = route['route_name'] ?? '-';
    final creatorName = route['nickname'] ?? '-';
    final rid = int.tryParse((route['id'] ?? route['route_id']).toString());
    final regionLabel =
        idToRegion[int.tryParse(route['region_id']?.toString() ?? '') ?? 0] ?? '-';
    final roadTypeLabel =
        idToRoadType[int.tryParse(route['road_type_id']?.toString() ?? '') ?? 0] ?? '-';
    final transportLabel =
        idToTransport[int.tryParse(route['transport_id']?.toString() ?? '') ?? 0] ?? '-';

    final favCount = (rid != null)
        ? (_favoriteCounts[rid] ?? (route['favorite_count'] ?? 0))
        : (route['favorite_count'] ?? 0);
    final isFav = (rid != null)
        ? (_favoriteStates[rid] ?? (route['is_favorite'] == true))
        : (route['is_favorite'] == true);

    final pts = _convertToLatLngList(route['route_path']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: pts.isNotEmpty
                ? FlutterMap(
              options: MapOptions(
                interactiveFlags: InteractiveFlag.none,
                bounds: LatLngBounds.fromPoints(pts),
                boundsOptions:
                const FitBoundsOptions(padding: EdgeInsets.all(8)),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: pts, color: Colors.blue, strokeWidth: 4),
                  ],
                ),
              ],
            )
                : Container(
              color: Colors.grey.shade300,
              child: const Center(child: Text("경로 스냅샷 없음")),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(routeName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: widget.userId == null
                          ? '로그인 필요'
                          : (isFav ? '즐겨찾기 해제' : '즐겨찾기'),
                      onPressed:
                      (rid == null || widget.userId == null) ? null : () => _toggleFavorite(route),
                      icon: Icon(isFav ? Icons.star : Icons.star_border,
                          color: Colors.amber),
                    ),
                    Text('$favCount'),
                  ],
                ),
                const SizedBox(height: 4),
                Text('생성자: $creatorName'),
                Text('지역: $regionLabel'),
                Text('길 유형: $roadTypeLabel'),
                Text('이동수단: $transportLabel'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRouteCard(Map<String, dynamic> route, {bool isSelected = false}) {
    final routeName = route['route_name'] ?? '이름 없음';
    final creatorName = route['nickname'] ?? '알 수 없음';
    final rid = int.tryParse((route['id'] ?? route['route_id']).toString());

    final regionLabel =
        idToRegion[int.tryParse(route['region_id']?.toString() ?? '') ?? 0] ?? '-';
    final roadTypeLabel =
        idToRoadType[int.tryParse(route['road_type_id']?.toString() ?? '') ?? 0] ?? '-';
    final transportLabel =
        idToTransport[int.tryParse(route['transport_id']?.toString() ?? '') ?? 0] ?? '-';

    final favCount = (rid != null)
        ? (_favoriteCounts[rid] ?? (route['favorite_count'] ?? 0))
        : (route['favorite_count'] ?? 0);
    final isFav = (rid != null)
        ? (_favoriteStates[rid] ?? (route['is_favorite'] == true))
        : (route['is_favorite'] == true);

    final pts = _convertToLatLngList(route['route_path']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isSelected ? Colors.blue[50] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isSelected ? 4 : 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 지도 스냅샷
            Container(
              width: 120,
              height: 120,
              margin: const EdgeInsets.only(right: 12),
              child: pts.isNotEmpty
                  ? FlutterMap(
                options: MapOptions(
                  interactiveFlags: InteractiveFlag.none,
                  bounds: LatLngBounds.fromPoints(pts),
                  boundsOptions:
                  const FitBoundsOptions(padding: EdgeInsets.all(4)),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(points: pts, color: Colors.blue, strokeWidth: 3),
                    ],
                  ),
                ],
              )
                  : Container(
                color: Colors.grey.shade300,
                child: const Center(child: Text("없음")),
              ),
            ),
            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(routeName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: widget.userId == null
                            ? '로그인 필요'
                            : (isFav ? '즐겨찾기 해제' : '즐겨찾기'),
                        onPressed:
                        (rid == null || widget.userId == null) ? null : () => _toggleFavorite(route),
                        icon: Icon(isFav ? Icons.star : Icons.star_border,
                            color: Colors.amber, size: 18),
                      ),
                      Text('$favCount'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('생성자: $creatorName'),
                  Text('지역: $regionLabel'),
                  Text('길 유형: $roadTypeLabel'),
                  Text('이동수단: $transportLabel'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _convertToLatLngList(List<dynamic>? path) {
    if (path == null) return [];
    return path.map<LatLng>((p) {
      if (p is List && p.length >= 2) {
        return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }
      if (p is Map) {
        final lat = p['lat'] ?? p['latitude'];
        final lng = p['lng'] ?? p['lon'] ?? p['longitude'];
        if (lat is num && lng is num) {
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }
      return const LatLng(0, 0);
    }).toList();
  }
}
