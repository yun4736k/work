import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'more_path_screen.dart';
import 'running_start.dart';

class SearchedScreen extends StatefulWidget {
  final Map<String, List<String>> selectedTags; // SearchScreen에서 전달
  final bool onlyFavorites; // 현재는 UI표시만, 서버 요청엔 미사용

  const SearchedScreen({
    Key? key,
    required this.selectedTags,
    required this.onlyFavorites,
  }) : super(key: key);

  @override
  State<SearchedScreen> createState() => _SearchedScreenState();
}

class _SearchedScreenState extends State<SearchedScreen> {
  // ✅ 서버 주소/엔드포인트 확정
  static const String baseUrl = 'http://13.125.177.95:5000';
  static const String searchEndpoint = '/search_routes';

  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> routes = [];
  Map<String, dynamic>? selectedRoute;

  @override
  void initState() {
    super.initState();
    _fetchRoutesFromServer();
  }

  /// 선택된 태그를 categories 배열로 평탄화 (서버 규격)
  List<String> _buildCategories() {
    final out = <String>[];
    for (final key in const ['지역', '길 유형', '이동수단']) {
      final vals = widget.selectedTags[key];
      if (vals != null && vals.isNotEmpty) {
        out.addAll(vals.map((e) => e.toString()));
      }
    }
    return out;
  }

  Future<void> _fetchRoutesFromServer() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse('$baseUrl$searchEndpoint');
      final categories = _buildCategories();

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"categories": categories}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['routes'] as List?) ?? [];
        setState(() {
          routes = list
              .whereType<Map>() // 안전
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = '서버 에러: ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '네트워크 오류: $e';
        isLoading = false;
      });
    }
  }

  // ---------- 표시에 쓰는 헬퍼들 ----------
  String _buildTagSummary() {
    final parts = <String>[];
    widget.selectedTags.forEach((k, v) {
      if (v.isNotEmpty) parts.add('$k: ${v.join(', ')}');
    });
    if (widget.onlyFavorites) parts.add('즐겨찾기: 켜짐');
    return parts.join('\n');
  }

  String _routeName(Map<String, dynamic> r) =>
      (r['route_name'] ?? r['name'] ?? '경로명 없음').toString();

  String _routeRegion(Map<String, dynamic> r) =>
      (r['region'] ?? r['location'] ?? r['addr'] ?? '지역 정보 없음').toString();

  String _routeLength(Map<String, dynamic> r) =>
      (r['curl'] ?? r['length_km'] ?? r['distance'] ?? '-').toString();

  int _routeLikes(Map<String, dynamic> r) {
    final v = r['like_count'] ?? r['likes'] ?? r['likes_count'] ?? 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _routeRating(Map<String, dynamic> r) {
    final v = r['rating'] ?? r['avg_rating'] ?? 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _creatorLabel(Map<String, dynamic> r) =>
      (r['user_id'] ?? r['nickname'] ?? '알 수 없음').toString();

  List<LatLng> _polyline(Map<String, dynamic> r) {
    final raw = (r['route_path'] ?? r['polyline'] ?? []) as List?;
    if (raw == null) return const [];
    return raw
        .whereType<List>()
        .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
  }
  // -------------------------------------

  @override
  Widget build(BuildContext context) {
    final tagSummary = _buildTagSummary();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('지도 (선택 경로)', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchRoutesFromServer,
            tooltip: '다시 불러오기',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단: "지도" 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 4))],
              ),
              child: const Text('지도',
                  style: TextStyle(color: Color(0xFF2D2D2D), fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // 선택 태그 요약
            if (tagSummary.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 3))],
                ),
                child: Text('선택된 태그:\n$tagSummary', style: const TextStyle(color: Color(0xFF2D2D2D))),
              ),
            if (tagSummary.isNotEmpty) const SizedBox(height: 16),

            // 선택한 경로 미리보기 + 산책 시작
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedRoute != null ? _routeName(selectedRoute!) : '경로를 선택하세요',
                    style: const TextStyle(color: Color(0xFF3CAEA3), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('생성자: ${selectedRoute != null ? _creatorLabel(selectedRoute!) : '-'}',
                      style: const TextStyle(color: Color(0xFF2D2D2D))),
                  Text('지역: ${selectedRoute != null ? _routeRegion(selectedRoute!) : '-'}',
                      style: const TextStyle(color: Color(0xFF2D2D2D))),
                  Text('길이: ${selectedRoute != null ? _routeLength(selectedRoute!) : '-'}',
                      style: const TextStyle(color: Color(0xFF2D2D2D))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        selectedRoute != null ? _routeLikes(selectedRoute!).toString() : '0',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        selectedRoute != null ? _routeRating(selectedRoute!).toStringAsFixed(1) : '0.0',
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedRoute == null
                          ? null
                          : () {
                        final polylinePoints = _polyline(selectedRoute!);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RunningStartScreen(
                              userId: _creatorLabel(selectedRoute!),
                              routeName: _routeName(selectedRoute!),
                              polylinePoints: polylinePoints, // ✅ List<LatLng>
                              intervalMinutes: 0,
                              intervalSeconds: 0,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3CAEA3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('산책 시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 결과 리스트
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _fetchRoutesFromServer,
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (routes.isEmpty) {
                    return const Center(child: Text('검색 결과가 없습니다.'));
                  }

                  return ListView.separated(
                    itemCount: routes.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == routes.length) {
                        // 마지막에 "더 많은 경로 보기" 버튼
                        return Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => MorePathScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF577590),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('더 많은 경로 보기',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        );
                      }

                      final r = routes[index];
                      return _buildRouteCard(
                        route: r,
                        onSelect: () => setState(() => selectedRoute = r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard({
    required Map<String, dynamic> route,
    required VoidCallback onSelect,
  }) {
    final routeName = _routeName(route);
    final region = _routeRegion(route);
    final len = _routeLength(route);
    final likes = _routeLikes(route);
    final rating = _routeRating(route);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D))),
                  const SizedBox(height: 4),
                  Text('지역: $region', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('길이: $len', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text('$likes', style: const TextStyle(color: Colors.red)),
                      const SizedBox(width: 10),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.amber)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('선택'),
            ),
          ],
        ),
      ),
    );
  }
}
