import 'package:flutter/material.dart';

class MorePathScreen extends StatefulWidget {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2D2D2D),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: DropdownButton<String>(
          value: _selectedAlgorithm,
          dropdownColor: Colors.black,
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          style: TextStyle(color: Colors.white),
          onChanged: (String? newValue) {
            setState(() {
              _selectedAlgorithm = newValue!;
            });
          },
          items: _algorithms.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(color: Colors.white)),
            );
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return _buildRouteCard(context, index);
        },
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // 이미지
            Container(
              width: 50,
              height: 50,
              color: Colors.grey[300],
              margin: EdgeInsets.only(right: 12),
            ),
            // 텍스트 및 선택 버튼
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '경로 이미지',
                    style: TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text('생성자 ID: ', style: TextStyle(color: Colors.grey[700])),
                      Text('12345', style: TextStyle(color: Colors.grey[800])),
                    ],
                  ),
                  Row(
                    children: [
                      Text('지역: ', style: TextStyle(color: Colors.grey[700])),
                      Text('TEXT', style: TextStyle(color: Colors.grey[800])),
                    ],
                  ),
                  Row(
                    children: [
                      Text('홀길이: ', style: TextStyle(color: Colors.grey[700])),
                      Text('123', style: TextStyle(color: Colors.grey[800])),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
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
            ElevatedButton(
              onPressed: () {
                print("경로 $index 선택됨");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('선택', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
