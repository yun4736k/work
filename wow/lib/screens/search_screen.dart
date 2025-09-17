import 'package:flutter/material.dart';
import 'searched_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? activeDropdown;

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
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '태그 검색',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                buildDropdownButton('길 유형'),
                SizedBox(width: 8),
                buildDropdownButton('이동수단'),
                SizedBox(width: 8),
                buildDropdownButton('즐겨찾기'),
              ],
            ),
          ),
          if (activeDropdown != null) ...[
            SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tagData[activeDropdown!]!
                        .map(
                          (tag) => FilterChip(
                        label: Text(tag),
                        selected: selectedTags[activeDropdown!]!.contains(tag),
                        onSelected: (_) => toggleTag(activeDropdown!, tag),
                        selectedColor: Colors.lightBlueAccent.shade100,
                        checkmarkColor: Colors.white,
                      ),
                    )
                        .toList(),
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  "필터를 선택해주세요",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // 선택된 태그를 Map<String, List<String>> 형태로 변환해서 전달
                  final Map<String, List<String>> passedTags = {};
                  selectedTags.forEach((key, value) {
                    passedTags[key] = value.toList();
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchedScreen(selectedTags: passedTags),
                    ),
                  );
                },
                child: Text(
                  '검색하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDropdownButton(String title) {
    final bool isActive = activeDropdown == title;

    return Expanded(
      child: GestureDetector(
        onTap: () => toggleDropdown(title),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 4)]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
