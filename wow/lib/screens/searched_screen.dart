import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'more_path_screen.dart';

class SearchedScreen extends StatefulWidget {
  final Map<String, List<String>> selectedTags;

  const SearchedScreen({Key? key, required this.selectedTags}) : super(key: key);

  @override
  _SearchedScreenState createState() => _SearchedScreenState();
}

class _SearchedScreenState extends State<SearchedScreen> {
  List<dynamic>? routes;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchRoutesFromServer();
  }

  Future<void> fetchRoutesFromServer() async {
    final url = Uri.parse('http://서버주소:포트/search'); // 실제 서버 주소로 변경하세요
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(widget.selectedTags),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          routes = jsonData['routes']; // 서버 응답 구조에 맞게 수정 필요
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = '서버 에러: ${response.statusCode}';
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

  @override
  Widget build(BuildContext context) {
    final tagSummary = widget.selectedTags.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .join('\n');

    return Scaffold(
      backgroundColor: Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D),
        title: const Text('지도 (선택 경로)', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('지도',
                      style: TextStyle(
                          color: Color(0xFF2D2D2D),
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('(선택 경로)', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (tagSummary.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  '선택된 태그:\n$tagSummary',
                  style: TextStyle(color: Color(0xFF2D2D2D)),
                ),
              ),

            if (tagSummary.isNotEmpty) const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('경로 이미지',
                          style: TextStyle(color: Color(0xFF3CAEA3), fontSize: 16)),
                      const Spacer(),
                      const Text('경로 이름',
                          style: TextStyle(color: Color(0xFF3CAEA3), fontSize: 16)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3CAEA3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('생성자 ID: num', style: TextStyle(color: Color(0xFF2D2D2D))),
                  const Text('지역: TEXT', style: TextStyle(color: Color(0xFF2D2D2D))),
                  const Text('컬링: num', style: TextStyle(color: Color(0xFF2D2D2D))),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.favorite, color: Colors.red, size: 20),
                      SizedBox(width: 4),
                      Text('num', style: TextStyle(color: Colors.red)),
                      SizedBox(width: 12),
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 4),
                      Text('num', style: TextStyle(color: Colors.amber)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return Center(child: CircularProgressIndicator());
                  } else if (errorMessage != null) {
                    return Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)));
                  } else if (routes == null || routes!.isEmpty) {
                    return Center(child: Text('검색 결과가 없습니다.'));
                  } else {
                    return ListView.builder(
                      itemCount: routes!.length + 1,
                      itemBuilder: (context, index) {
                        if (index == routes!.length) {
                          return Center(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => MorePathScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF577590),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                '더 많은 경로 보기',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          );
                        }
                        final route = routes![index];
                        // 서버에서 받아오는 데이터 키에 맞게 수정하세요
                        return _buildRouteCard(
                          context,
                          route['name'] ?? '경로명 없음',
                          route['region'] ?? '지역 없음',
                          route['curl']?.toString() ?? '0',
                          (route['rating'] is double) ? route['rating'] : 0.0,
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, String routeName, String region, String curl, double rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D))),
                  SizedBox(height: 4),
                  Text('지역: $region', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('컬링: $curl', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('평점: $rating', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print('$routeName 선택됨');
                // TODO: 상세 화면 이동 또는 선택 처리 로직 추가
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3CAEA3),
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
