import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MorePathScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allRoutes;
  final Map<String, String>? selectedTags;
  final Function(Map<String, dynamic>) onRouteSelected;

  const MorePathScreen({
    Key? key,
    required this.allRoutes,
    this.selectedTags,
    required this.onRouteSelected,
  }) : super(key: key);

  @override
  _MorePathScreenState createState() => _MorePathScreenState();
}

class _MorePathScreenState extends State<MorePathScreen> {
  String _selectedAlgorithm = '연관성';
  final List<String> _algorithms = [
    '연관성',
    '이름순',
    '최신순',
    '즐겨찾기 높은순',
    '즐겨찾기 낮은순',
  ];

  late List<Map<String, dynamic>> routesToShow;

  final Map<int, String> idToRegion = {
    1: '중구/광복동', 2: '중구/남포동', 3: '중구/대청동', 4: '중구/동광동', 5: '중구/보수동', 6: '중구/부평동',
    7: '서구/동대신동', 8: '서구/서대신동', 9: '서구/암남동', 10: '서구/아미동', 11: '서구/토성동',
    12: '동구/초량동', 13: '동구/수정동', 14: '동구/좌천동', 15: '동구/범일동',
    16: '영도구/남항동', 17: '영도구/신선동', 18: '영도구/봉래동', 19: '영도구/청학동', 20: '영도구/동삼동',
    21: '부산진구/부전동', 22: '부산진구/전포동', 23: '부산진구/양정동', 24: '부산진구/범전동',
    25: '부산진구/범천동', 26: '부산진구/가야동',
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

  @override
  void initState() {
    super.initState();
    routesToShow = widget.allRoutes.toList();
    _sortRoutes();
  }

  void _sortRoutes() {
    setState(() {
      switch (_selectedAlgorithm) {
        case '연관성':
          routesToShow.sort(
                (a, b) => (a['route_name'] ?? '').compareTo(b['route_name'] ?? ''),
          );
          break;
        case '이름순':
          routesToShow.sort(
                (a, b) => (a['route_name'] ?? '').compareTo(b['route_name'] ?? ''),
          );
          break;
        case '최신순':
          routesToShow.sort(
            // id가 큰 게 최신
                (b, a) => (a['id'] ?? 0).compareTo(b['id'] ?? 0),
          );
          break;
        case '즐겨찾기 높은순':
          routesToShow.sort(
                (b, a) => (a['favorite_count'] ?? 0).compareTo(b['favorite_count'] ?? 0),
          );
          break;
        case '즐겨찾기 낮은순':
          routesToShow.sort(
                (a, b) => (a['favorite_count'] ?? 0).compareTo(b['favorite_count'] ?? 0),
          );
          break;
      }
    });
  }

  // 안전한 route_path → List<LatLng> 변환
  List<LatLng> _toLatLngList(dynamic raw) {
    if (raw == null) return const [];
    final List<LatLng> out = [];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length >= 2) {
          final lat = (p[0] as num?)?.toDouble();
          final lng = (p[1] as num?)?.toDouble();
          if (lat != null && lng != null) out.add(LatLng(lat, lng));
        } else if (p is Map) {
          final lat = p['lat'] ?? p['latitude'];
          final lng = p['lng'] ?? p['lon'] ?? p['longitude'];
          if (lat is num && lng is num) out.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: DropdownButton<String>(
          value: _selectedAlgorithm,
          dropdownColor: Colors.black,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedAlgorithm = newValue;
                _sortRoutes();
              });
            }
          },
          items: _algorithms.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        ),
      ),
      body: ListView.builder(
        itemCount: routesToShow.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final route = routesToShow[index];
          return GestureDetector(
            onTap: () {
              widget.onRouteSelected(route);
              Navigator.pop(context);
            },
            child: _buildRouteCard(route),
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final routeName = route['route_name'] ?? '이름 없음';
    final creatorName = route['nickname'] ?? '알 수 없음';
    final favoriteCount = route['favorite_count'] ?? 0;

    final regionLabel =
        idToRegion[int.tryParse(route['region_id']?.toString() ?? '') ?? 0] ?? '-';

    final List<LatLng> points = _toLatLngList(route['route_path']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미니맵
            Container(
              width: 150,
              height: 150,
              margin: const EdgeInsets.only(right: 20),
              child: FlutterMap(
                options: MapOptions(
                  interactiveFlags: InteractiveFlag.none,
                  bounds: LatLngBounds.fromPoints(
                    points.isNotEmpty ? points : [const LatLng(0, 0)],
                  ),
                  boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(8)),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(points: points, color: Colors.blue, strokeWidth: 4),
                      ],
                    ),
                ],
              ),
            ),

            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    style: const TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '생성자: $creatorName',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text('지역: $regionLabel', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text('$favoriteCount', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
