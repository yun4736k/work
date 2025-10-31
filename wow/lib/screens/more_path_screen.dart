import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart'; // ★ 역지오코딩 추가

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

  // ====== ID → 이름 매핑 ======
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

  final Map<int, String> idToRoadType = {
    101: '포장도로', 102: '비포장도로', 103: '등산로', 104: '짧은 산책로', 105: '긴 산책로', 106: '운동용 산책로',
  };

  final Map<int, String> idToTransport = {
    201: '걷기', 202: '뜀걸음', 203: '자전거', 204: '휠체어', 205: '유모차',
  };

  @override
  void initState() {
    super.initState();
    routesToShow = widget.allRoutes.toList();
    _sortRoutes();
    _backfillRegionLabels(); // ★ 지역 라벨/ID 백필
  }

  // ====== 정렬 ======
  void _sortRoutes() {
    setState(() {
      switch (_selectedAlgorithm) {
        case '연관성':
        case '이름순':
          routesToShow.sort(
                (a, b) => (a['route_name'] ?? '').compareTo(b['route_name'] ?? ''),
          );
          break;
        case '최신순':
          routesToShow.sort((b, a) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
          break;
        case '즐겨찾기 높은순':
          routesToShow.sort(
                (b, a) =>
                (a['favorite_count'] ?? 0).compareTo(b['favorite_count'] ?? 0),
          );
          break;
        case '즐겨찾기 낮은순':
          routesToShow.sort(
                (a, b) =>
                (a['favorite_count'] ?? 0).compareTo(b['favorite_count'] ?? 0),
          );
          break;
      }
    });
  }

  // ====== 안전한 route_path 변환 ======
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

  // ====== 지역 라벨/ID 백필(역지오코딩) ======
  Future<void> _backfillRegionLabels() async {
    bool changed = false;

    for (final r in routesToShow) {
      final injected = (r['region_label'] ?? r['regionLabel'] ?? r['regionName'])?.toString().trim();
      final rawId = (r['region_id'] ?? r['regionId'])?.toString().trim();

      final hasLabel = (injected != null && injected.isNotEmpty);
      final hasId = (rawId != null && rawId.isNotEmpty);

      if (hasLabel || hasId) continue;

      // 대표 좌표: route_path 마지막 → 첫번째
      final pts = _toLatLngList(r['route_path']);
      if (pts.isEmpty) continue;
      final base = pts.last;

      try {
        final placemarks = await placemarkFromCoordinates(base.latitude, base.longitude);
        if (placemarks.isEmpty) continue;

        final p = placemarks.first;

        // 플랫폼별 차이를 감안한 느슨한 추출
        final guRaw   = (p.locality ?? p.subAdministrativeArea ?? '').trim();
        final dongRaw = (p.subLocality ?? p.thoroughfare ?? '').trim();
        if (guRaw.isEmpty || dongRaw.isEmpty) continue;

        final gu   = guRaw.replaceAll(' ', '');
        final dong = dongRaw.replaceAll(' ', '');
        final label = '$gu/$dong';

        // 1) 정확 매칭
        int? regionId = idToRegion.entries.firstWhere(
              (e) => e.value == label,
          orElse: () => const MapEntry(-1, ''),
        ).key;
        if (regionId == -1) {
          // 2) 느슨 매칭: 같은 구 && 동 접두/포함
          final match = idToRegion.entries.firstWhere(
                (e) {
              final parts = e.value.split('/');
              if (parts.length != 2) return false;
              final eg = parts[0].replaceAll(' ', '');
              final ed = parts[1].replaceAll(' ', '');
              return eg == gu && (ed.startsWith(dong) || dong.startsWith(ed));
            },
            orElse: () => const MapEntry(-1, ''),
          );
          regionId = match.key == -1 ? null : match.key;
        }

        if (regionId != null) {
          r['region_id'] = regionId.toString();         // snake
          r['region_label'] = idToRegion[regionId];     // 라벨도 주입
          changed = true;
        }
      } catch (_) {
        // 역지오코딩 실패 시 스킵
      }
    }

    if (changed && mounted) setState(() {});
  }

  // ====== 칩 UI(균일 스타일) ======
  Widget _tagChip(String text, {IconData? icon}) {
    if (text.trim().isEmpty || text == '-') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 4),
          ],
          Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
        ],
      ),
    );
  }

  // ====== 라벨(주입 우선, 없으면 매핑) ======
  String _regionLabel(Map<String, dynamic> r) {
    // 1) 라벨 키: snake, camel, 기타
    final injected = (r['region_label'] ?? r['regionLabel'] ?? r['regionName'])?.toString();
    if (injected != null && injected.trim().isNotEmpty) return injected;

    // 2) ID 키: snake, camel, nested(region:{id:..})
    dynamic rawId = r['region_id'] ?? r['regionId'];
    if (rawId == null && r['region'] is Map) {
      final m = r['region'] as Map;
      rawId = m['id'] ?? m['region_id'] ?? m['regionId'];
    }

    final raw = (rawId ?? '').toString();
    if (raw.isEmpty) return '-';

    // "01" → 1
    final normalized = raw.replaceFirst(RegExp(r'^0+'), '');
    final id = int.tryParse(normalized);
    return idToRegion[id ?? -1] ?? '-';
  }

  String _roadTypeLabel(Map<String, dynamic> r) {
    final injected = (r['roadTypeLabel'] as String?);
    if (injected != null && injected.trim().isNotEmpty) return injected;

    final raw = r['road_type_id']?.toString() ?? '';
    // ① 101~106 매핑 시도
    final id = int.tryParse(raw);
    if (id != null && idToRoadType.containsKey(id)) {
      return idToRoadType[id]!;
    }
    // ② "01"~"06" / 1~6 → 101~106 변환
    final short = int.tryParse(raw);
    if (short != null && short >= 1 && short <= 6) {
      final longId = 100 + short; // 1→101
      return idToRoadType[longId] ?? '-';
    }
    if (raw.length == 2 && raw.startsWith('0')) {
      final n = int.tryParse(raw);
      if (n != null) {
        final longId = 100 + n;
        return idToRoadType[longId] ?? '-';
      }
    }
    // ③ 서버가 보낸 category_labels가 있으면 첫 값 사용
    if (r['category_labels'] is List && (r['category_labels'] as List).isNotEmpty) {
      return (r['category_labels'] as List).first.toString();
    }
    return '-';
  }

  String _transportLabel(Map<String, dynamic> r) {
    final injected = (r['transportLabel'] as String?);
    if (injected != null && injected.trim().isNotEmpty) return injected;

    final raw = r['transport_id']?.toString() ?? '';
    // ① 201~205 매핑 시도
    final id = int.tryParse(raw);
    if (id != null && idToTransport.containsKey(id)) {
      return idToTransport[id]!;
    }
    // ② "01"~"05" / 1~5 → 201~205 변환
    final short = int.tryParse(raw);
    if (short != null && short >= 1 && short <= 5) {
      final longId = 200 + short; // 1→201
      return idToTransport[longId] ?? '-';
    }
    if (raw.length == 2 && raw.startsWith('0')) {
      final n = int.tryParse(raw);
      if (n != null) {
        final longId = 200 + n;
        return idToTransport[longId] ?? '-';
      }
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2D2D2D),
        title: DropdownButton<String>(
          value: _selectedAlgorithm,
          underline: const SizedBox.shrink(),
          dropdownColor: Colors.black,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedAlgorithm = newValue;
                _sortRoutes();
              });
            }
          },
          items: _algorithms
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
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

  // ====== 카드 ======
  Widget _buildRouteCard(Map<String, dynamic> route) {
    final routeName = (route['route_name'] ?? '이름 없음').toString();
    final creatorName = (route['nickname'] ?? '알 수 없음').toString();
    final favoriteCount =
    (route['favorite_count'] is int)
        ? route['favorite_count'] as int
        : int.tryParse('${route['favorite_count'] ?? 0}') ?? 0;

    final regionLabel = _regionLabel(route);
    final roadTypeLabel = _roadTypeLabel(route);
    final transportLabel = _transportLabel(route);

    // 태그 리스트
    final List<_TagItem> tags = [
      _TagItem(regionLabel, Icons.place),
      _TagItem(roadTypeLabel, Icons.route),
      _TagItem(transportLabel, Icons.directions_walk),
    ].where((t) => t.label.isNotEmpty && t.label != '-').toList();

    const int maxShowChips = 4;
    final int hidden = tags.length > maxShowChips ? (tags.length - maxShowChips) : 0;
    final List<_TagItem> visible = tags.take(maxShowChips).toList();

    final points = _toLatLngList(route['route_path']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double mapW = (constraints.maxWidth * 0.35).clamp(130, 190).toDouble();
        const double starColW = 64; // ▶ 우측 별+카운트 고정폭을 넓힘

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 미니맵
                Container(
                  width: mapW,
                  height: mapW,
                  margin: const EdgeInsets.only(right: 16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade200,
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      interactiveFlags: InteractiveFlag.none,
                      bounds: points.isNotEmpty
                          ? LatLngBounds.fromPoints(points)
                          : LatLngBounds.fromPoints(const [
                        LatLng(35.1796, 129.0756),
                        LatLng(35.1798, 129.0758),
                      ]),
                      boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(6)),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: points, color: Colors.blue, strokeWidth: 3.5),
                          ],
                        ),
                    ],
                  ),
                ),

                // 텍스트 영역 + 우측 별 고정 컬럼
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 제목/생성자/태그
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: routeName,
                              waitDuration: const Duration(milliseconds: 400),
                              child: Text(
                                routeName,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: (constraints.maxWidth < 360) ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '생성자: $creatorName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...visible.map((t) => _tagChip(t.label, icon: t.icon)),
                                if (hidden > 0) _tagChip('+$hidden', icon: Icons.more_horiz),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 오른쪽: 별 + 카운트 (한 줄, 줄바꿈 방지)
                      SizedBox(
                        width: starColW,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 26),
                                const SizedBox(width: 6),
                                Text(
                                  '$favoriteCount',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 내부 태그 모델
class _TagItem {
  final String label;
  final IconData icon;
  _TagItem(this.label, this.icon);
}
