import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'dart:convert';
import 'searched_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? activeDropdown;
  bool onlyFavorites = false;

  final Map<String, List<String>> tagData = {
    '길 유형': ['포장도로', '비포장도로', '등산로', '짧은 산책로', '긴 산책로', '운동용 산책로'],
    '이동수단': ['걷기', '뜀걸음', '자전거', '휠체어', '유모차'],
  };

  final List<String> _busanGus = const [
    '중구','서구','동구','영도구','부산진구','동래구','남구','북구',
    '해운대구','사하구','금정구','강서구','연제구','수영구','사상구','기장군',
  ];

  final Map<String, List<String>> _busanDongs = const {
    '중구': ['광복동','남포동','대청동','동광동','보수동','부평동'],
    '서구': ['동대신동','서대신동','암남동','아미동','토성동'],
    '동구': ['초량동','수정동','좌천동','범일동'],
    '영도구': ['남항동','신선동','봉래동','청학동','동삼동'],
    '부산진구': ['부전동','전포동','양정동','범전동','범천동','가야동'],
    '동래구': ['명장동','사직동','안락동','온천동','수안동'],
    '남구': ['대연동','문현동','감만동','용호동','우암동'],
    '북구': ['구포동','덕천동','만덕동','화명동'],
    '해운대구': ['우동','중동','좌동','송정동','재송동'],
    '사하구': ['괴정동','당리동','하단동','장림동','다대동'],
    '금정구': ['장전동','구서동','부곡동','서동','금사동'],
    '강서구': ['명지동','가락동','녹산동','대저1동','대저2동'],
    '연제구': ['연산동'],
    '수영구': ['광안동','남천동','망미동','민락동'],
    '사상구': ['감전동','괘법동','덕포동','모라동'],
    '기장군': ['기장읍','정관읍','일광읍','철마면','장안읍'],
  };

  final Map<String, Set<String>> selectedTags = {
    '지역': {},
    '길 유형': {},
    '이동수단': {},
  };

  String? _currentGu;

  void toggleDropdown(String name) {
    setState(() {
      if (activeDropdown == name) {
        activeDropdown = null;
      } else {
        activeDropdown = name;
        if (name != '지역') _currentGu = null;
      }
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

  void toggleRegion(String gu, String dong) {
    toggleTag('지역', '$gu/$dong');
  }

  void resetSelection() {
    setState(() {
      for (final key in selectedTags.keys) selectedTags[key]!.clear();
      onlyFavorites = false;
      activeDropdown = null;
      _currentGu = null;
    });
  }

  Map<String, List<String>> getFilteredTags() {
    return selectedTags.map((key, value) {
      final sortedList = value.toList()..sort();
      return MapEntry(key, sortedList);
    });
  }

  List<Widget> buildSelectedTagChips() {
    final List<Widget> chips = [];
    final sortedCategories = selectedTags.keys.toList()..sort();
    for (final category in sortedCategories) {
      final tags = selectedTags[category]!.toList()..sort();
      for (final tag in tags) {
        final label = category == '지역' ? tag.replaceAll('/', ' - ') : tag;
        chips.add(FilterChip(
          label: Text(label),
          selected: true,
          onSelected: (_) {
            if (category == '지역' && tag.contains('/')) {
              final sp = tag.split('/');
              toggleRegion(sp[0], sp[1]);
            } else {
              toggleTag(category, tag);
            }
          },
          backgroundColor: Colors.grey.shade100,
          selectedColor: Colors.lightBlueAccent.shade100,
          showCheckmark: false,
          labelStyle: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ));
      }
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTags = getFilteredTags();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('[현재 지역]',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
            TextButton(
              onPressed: resetSelection,
              child: const Text('초기화', style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                buildDropdownButton('지역'),
                const SizedBox(width: 8),
                buildDropdownButton('길 유형'),
                const SizedBox(width: 8),
                buildDropdownButton('이동수단'),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => onlyFavorites = !onlyFavorites),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: onlyFavorites ? Colors.orangeAccent : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Center(
                        child: Text(
                          '즐겨찾기',
                          style: TextStyle(
                            color: onlyFavorites ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  if (activeDropdown != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: _buildDropdownContent(),
                    ),
                  const SizedBox(height: 12),
                  if (selectedTags.values.any((set) => set.isNotEmpty))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: buildSelectedTagChips(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final filteredTags = getFilteredTags();
                  final allSelectedTags = [
                    ...filteredTags['지역'] ?? [],
                    ...filteredTags['길 유형'] ?? [],
                    ...filteredTags['이동수단'] ?? [],
                  ];

                  final url = Uri.parse('${ApiService.baseUrl}/search_routes');

                  try {
                    final response = await http.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({"categories": allSelectedTags}),
                    ).timeout(const Duration(seconds: 10));

                    if (response.statusCode == 200) {
                      final responseData = json.decode(response.body);
                      final routes = responseData['routes'] as List<dynamic>;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchedScreen(
                            selectedTags: filteredTags,
                            onlyFavorites: onlyFavorites,
                            searchResults: routes,
                          ),
                        ),
                      );
                    } else {
                      final error = json.decode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error['message'] ?? "검색 실패")),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("에러 발생: $e")),
                    );
                  }
                },
                child: const Text('검색하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            boxShadow: isActive ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 4)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isActive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent() {
    switch (activeDropdown) {
      case '지역':
        return buildRegionDropdown();
      case '길 유형':
        return buildSimpleTagGrid('길 유형');
      case '이동수단':
        return buildSimpleTagGrid('이동수단');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget buildRegionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          value: _currentGu,
          hint: const Text('구 선택'),
          items: _busanGus.map((gu) => DropdownMenuItem(value: gu, child: Text(gu))).toList(),
          onChanged: (val) => setState(() => _currentGu = val),
        ),
        const SizedBox(height: 8),
        if (_currentGu != null)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _busanDongs[_currentGu!]!.map((dong) {
              final key = '$_currentGu/$dong';
              return FilterChip(
                label: Text(dong),
                selected: selectedTags['지역']!.contains(key),
                onSelected: (_) => toggleRegion(_currentGu!, dong),
                backgroundColor: Colors.grey.shade100,
                selectedColor: Colors.lightBlueAccent.shade100,
                showCheckmark: false,
                labelStyle: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget buildSimpleTagGrid(String category) {
    final tags = tagData[category]!;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((tag) {
        final isSelected = selectedTags[category]!.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (_) => toggleTag(category, tag),
          backgroundColor: Colors.grey.shade100,
          selectedColor: Colors.lightBlueAccent.shade100,
          showCheckmark: false,
          labelStyle: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }
}