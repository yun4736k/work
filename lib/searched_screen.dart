import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text('지도 (선택 경로)', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // 뒤로 가기 버튼 클릭 시 처리 로직
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              // 상단 부분 (지도 및 선택 경로)
              Container(
                color: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('지도', style: TextStyle(color: Colors.red, fontSize: 24)),
                    SizedBox(height: 5),
                    Text('(선택 경로)', style: TextStyle(color: Colors.red, fontSize: 18)),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // 경로 정보 입력 부분 (현재 선택된 경로)
              Container(
                color: Colors.black,
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('경로 이미지', style: TextStyle(color: Colors.red, fontSize: 18)),
                        Spacer(),
                        Text('경로 이름', style: TextStyle(color: Colors.red, fontSize: 18)),
                        Spacer(),
                        ElevatedButton(
                          onPressed: () {},
                          child: Text('선택'),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(Colors.red),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('생성자 ID: num', style: TextStyle(color: Colors.red)),
                    Text('지역: TEXT', style: TextStyle(color: Colors.red)),
                    Text('컬링: num', style: TextStyle(color: Colors.red)),
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.red),
                        Text('num', style: TextStyle(color: Colors.red)),
                        Icon(Icons.star, color: Colors.yellow),
                        Text('num', style: TextStyle(color: Colors.yellow)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // 경로 리스트 부분
              Expanded(
                child: ListView(
                  children: [
                    // 경로 1
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      color: Colors.black,
                      padding: EdgeInsets.all(15.0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('경로 1', style: TextStyle(color: Colors.red, fontSize: 18)),
                              SizedBox(height: 5),
                              Text('지역: 지역명', style: TextStyle(color: Colors.white)),
                              Text('컬링: num', style: TextStyle(color: Colors.white)),
                              Text('평점: 4.5', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          Spacer(),
                          ElevatedButton(
                            onPressed: () {},
                            child: Text('선택'),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 경로 2
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      color: Colors.black,
                      padding: EdgeInsets.all(15.0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('경로 2', style: TextStyle(color: Colors.red, fontSize: 18)),
                              SizedBox(height: 5),
                              Text('지역: 지역명', style: TextStyle(color: Colors.white)),
                              Text('컬링: num', style: TextStyle(color: Colors.white)),
                              Text('평점: 4.0', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          Spacer(),
                          ElevatedButton(
                            onPressed: () {},
                            child: Text('선택'),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 경로 3 (현재 선택된 경로)
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      color: Colors.black,
                      padding: EdgeInsets.all(15.0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('경로 3', style: TextStyle(color: Colors.red, fontSize: 18)),
                              SizedBox(height: 5),
                              Text('지역: 지역명', style: TextStyle(color: Colors.white)),
                              Text('컬링: num', style: TextStyle(color: Colors.white)),
                              Text('평점: 5.0', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          Spacer(),
                          ElevatedButton(
                            onPressed: () {},
                            child: Text('선택'),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // "더 많은 경로 보기" 버튼 추가
                    SizedBox(height: 20),
                    Center(
                      child: IconButton(
                        icon: Icon(Icons.arrow_downward, color: Colors.red),
                        onPressed: () {
                          // 더 많은 경로를 로드하는 로직을 여기에 추가할 수 있습니다.
                          print("더 많은 경로 보기 클릭됨");
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
