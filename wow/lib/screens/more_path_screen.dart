import 'package:flutter/material.dart';

class MorePathScreen extends StatefulWidget {
  final List<dynamic> allRoutes; // 전체 경로
  final Map<String, dynamic>? selectedRoute; // 현재 선택된 경로
  final Function(Map<String, dynamic>) onRouteSelected; // 선택 시 콜백

  const MorePathScreen({
    Key? key,
    required this.allRoutes,
    required this.selectedRoute,
    required this.onRouteSelected,
  }) : super(key: key);

  @override
  _MorePathScreenState createState() => _MorePathScreenState();
}

class _MorePathScreenState extends State<MorePathScreen> {
  String _selectedAlgorithm = '연관성';
  final List<String> _algorithms = [
    '연관성',
    '좋아요 높은순',
    '좋아요 낮은순',
    '즐겨찾기 높은순',
    '즐겨찾기 낮은순',
  ];

  late List<dynamic> routesToShow;

  @override
  void initState() {
    super.initState();
    _filterRoutes();
  }

  void _filterRoutes() {
    routesToShow = widget.allRoutes
        .where((route) => route != widget.selectedRoute)
        .toList();
    _sortRoutes();
  }

  void _sortRoutes() {
    setState(() {
      switch (_selectedAlgorithm) {
        case '연관성':
          routesToShow.sort((a, b) =>
              (a['route_name'] ?? '').compareTo(b['route_name'] ?? ''));
          break;
        case '좋아요 높은순':
          routesToShow.sort((b, a) =>
              (a['favoriteCount'] ?? 0).compareTo(b['favoriteCount'] ?? 0));
          break;
        case '좋아요 낮은순':
          routesToShow.sort((a, b) =>
              (a['favoriteCount'] ?? 0).compareTo(b['favoriteCount'] ?? 0));
          break;
        case '즐겨찾기 높은순':
          routesToShow.sort((b, a) =>
              (a['rating'] ?? 0.0).compareTo(b['rating'] ?? 0.0));
          break;
        case '즐겨찾기 낮은순':
          routesToShow.sort((a, b) =>
              (a['rating'] ?? 0.0).compareTo(b['rating'] ?? 0.0));
          break;
      }
    });
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
          return _buildRouteCard(context, route);
        },
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, Map<String, dynamic> route) {
    final routeName = route['route_name'] ?? '이름 없음';
    final creatorName = route['nickname'] ?? '알 수 없음';
    final favoriteCount = route['favoriteCount'] ?? 0;
    final rating = route['rating'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 이미지 플레이스홀더
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.only(right: 12),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    style: const TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('생성자: ', style: TextStyle(color: Colors.grey)),
                      Text(creatorName, style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text('$favoriteCount', style: const TextStyle(color: Colors.red)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.amber)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onRouteSelected(route);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: const Text('선택', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}