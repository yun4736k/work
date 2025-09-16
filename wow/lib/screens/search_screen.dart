import 'package:flutter/material.dart';

void main() => runApp(SearchApp());

class SearchApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SearchPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String? activeDropdown; // '길 유형', '이동수단', '즐겨찾기'

  final Map<String, List<String>> tagData = {
    '길 유형': ['포장도로', '비포장도로', '산길', '숲길', '해변', '강변', '도시', '시골', '언덕', '계단', '산책로', '기타'],
    '이동수단': ['도보', '자전거', '전동킥보드', '자동차', '버스', '기차', '지하철', '휠체어', '유모차', '오토바이'],
    '즐겨찾기': ['카페', '식당', '전망대', '사진스팟', '공원', '유적지', '체험', '자연', '쇼핑', '온천']
  };

  final Map<String, Set<String>> selectedTags = {
    '길 유형': {},
    '이동수단': {},
    '즐겨찾기': {},
  };

  void toggleDropdown(String name) {
    setState(() {
      activeDropdown = (activeDropdown == name) ? null : name;
    });
  }

  void toggleTag(String category, String tag) {
    setState(() {
      if (selectedTags[category]!.contains(tag)) {
        selectedTags[category]!.remove(tag);
      } else {
        selectedTags[category]!.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // 상단 바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {},
                  ),
                  Text('현재 지역', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              SizedBox(height: 20),

              // 드롭다운 3개
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: DropdownHeader(
                      title: '길 유형',
                      isActive: activeDropdown == '길 유형',
                      onTap: () => toggleDropdown('길 유형'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: DropdownHeader(
                      title: '이동수단',
                      isActive: activeDropdown == '이동수단',
                      onTap: () => toggleDropdown('이동수단'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: DropdownHeader(
                      title: '즐겨찾기',
                      isActive: activeDropdown == '즐겨찾기',
                      onTap: () => toggleDropdown('즐겨찾기'),
                    ),
                  ),
                ],
              ),

              // 드롭다운 활성화 시 태그 목록
              if (activeDropdown != null)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tagData[activeDropdown!]!
                        .map(
                          (tag) => GestureDetector(
                        onTap: () => toggleTag(activeDropdown!, tag),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            color: selectedTags[activeDropdown!]!.contains(tag)
                                ? Colors.white
                                : Colors.transparent,
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: selectedTags[activeDropdown!]!.contains(tag)
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),

              Expanded(child: Container()),

              // 검색 버튼
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                ),
                child: TextButton(
                  onPressed: () {
                    print('선택된 태그: $selectedTags');
                  },
                  child: Text('검색', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropdownHeader extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const DropdownHeader({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: Colors.white)),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
