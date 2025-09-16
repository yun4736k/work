import 'package:flutter/material.dart';
import 'more_path_screen.dart'; // 동일 디렉터리에 있어야 합니다.

class SearchedScreen extends StatelessWidget {
  const SearchedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D),
        title: const Text('지도 (선택 경로)',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
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
            // 상단 부분
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
                  Text('(선택 경로)',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 경로 정보 입력
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
                          style:
                          TextStyle(color: Color(0xFF3CAEA3), fontSize: 16)),
                      const Spacer(),
                      const Text('경로 이름',
                          style:
                          TextStyle(color: Color(0xFF3CAEA3), fontSize: 16)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3CAEA3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('생성자 ID: num',
                      style: TextStyle(color: Color(0xFF2D2D2D))),
                  const Text('지역: TEXT',
                      style: TextStyle(color: Color(0xFF2D2D2D))),
                  const Text('컬링: num',
                      style: TextStyle(color: Color(0xFF2D2D2D))),
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
            // 경로 리스트
            Expanded(
              child: ListView(
                children: [
                  // 경로 예시 1
                  _buildRouteCard(context, '경로 1', '지역명', 'num', 4.5),
                  _buildRouteCard(context, '경로 2', '지역명', 'num', 4.0),
                  _buildRouteCard(context, '경로 3', '지역명', 'num', 5.0),
                  const SizedBox(height: 12),
                  // "더 많은 경로 보기" 버튼
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MorePathScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF577590),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 14.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '더 많은 경로 보기',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
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
  }

  Widget _buildRouteCard(
      BuildContext context, String routeName, String region, String curl, double rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routeName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2D2D2D))),
                  SizedBox(height: 4),
                  Text('지역: $region',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('컬링: $curl',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('평점: $rating',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print('$routeName 선택됨');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('선택'),
            ),
          ],
        ),
      ),
    );
  }
}