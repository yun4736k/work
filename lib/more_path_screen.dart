import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 드롭다운 선택된 값 저장용 변수
  String _selectedAlgorithm = '연관성';

  // 드롭다운 메뉴 항목들
  final List<String> _algorithms = [
    '연관성',
    '좋아요 높은순',
    '좋아요 낮은순',
    '즐겨찾기 높은순',
    '즐겨찾기 낮은순',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
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
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // 돌아가기 버튼을 눌렀을 때의 동작
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {
                // 검색 버튼을 눌렀을 때의 동작
              },
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: ListView.builder(
          itemCount: 5, // 항목 개수
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.all(10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // 이미지
                  Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey, // 이미지 placeholder
                    margin: EdgeInsets.only(right: 10),
                  ),
                  // 텍스트 및 선택 버튼
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '경로 이미지', // 제목
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              '생선자 ID: ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              '12345',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '지역: ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              'TEXT',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '홀길이: ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              '123',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red, size: 20),
                            SizedBox(width: 5),
                            Text(
                              'num',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.star, color: Colors.yellow, size: 20),
                            SizedBox(width: 5),
                            Text(
                              'num',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 선택 버튼
                  TextButton(
                    onPressed: () {
                      // 선택 버튼을 눌렀을 때의 동작
                      print("경로 $index 선택됨");
                    },
                    child: Text(
                      '선택',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
