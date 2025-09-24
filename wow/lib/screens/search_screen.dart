import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'searched_screen.dart';

enum CategoryType { region, roadType, transport }

class SearchScreen extends StatefulWidget {
  final String? userId; // 즐겨찾기 전용 필터 시 필요
  const SearchScreen({Key? key, this.userId}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? activeDropdown;
  bool onlyFavorites = false;
  String _searchQuery = '';
  String? _currentGu;
  String currentRegionLabel = '[현재 지역]';

  // 최초 워밍업/로딩 상태
  bool _didWarmup = false;
  bool _isSearching = false;

  // --- 필터 데이터 ---
  static const Map<String, List<String>> tagData = {
    '길 유형': ['포장도로', '비포장도로', '등산로', '짧은 산책로', '긴 산책로', '운동용 산책로'],
    '이동수단': ['걷기', '뜀걸음', '자전거', '휠체어', '유모차'],
  };

  static const List<String> busanGus = [
    '중구','서구','동구','영도구','부산진구','동래구','남구','북구',
    '해운대구','사하구','금정구','강서구','연제구','수영구','사상구','기장군',
  ];

  static const Map<String, List<String>> busanDongs = {
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

  static const List<String> seoulGus = [
    '강남구','강동구','강북구','강서구','관악구','광진구','구로구','금천구',
    '노원구','도봉구','동대문구','동작구','마포구','서대문구','서초구','성동구',
    '성북구','송파구','양천구','영등포구','용산구','은평구','종로구','중구','중랑구',
  ];

  static const Map<String, List<String>> seoulDongs = {
    '강남구': ['신사동','논현동','역삼동','삼성동','청담동','대치동','압구정동'],
    '강동구': ['천호동','암사동','길동','성내동','둔촌동','명일동'],
    '강북구': ['미아동','번동','수유동','우이동'],
    '강서구': ['화곡동','등촌동','가양동','발산동','염창동'],
    '관악구': ['봉천동','신림동','남현동','은천동'],
    '광진구': ['자양동','구의동','광장동','화양동'],
    '구로구': ['구로동','개봉동','오류동','항동'],
    '금천구': ['가산동','독산동','시흥동'],
    '노원구': ['상계동','중계동','하계동','공릉동'],
    '도봉구': ['도봉동','창동','쌍문동','방학동'],
    '동대문구': ['청량리동','회기동','휘경동','장안동'],
    '동작구': ['사당동','대방동','노량진동','상도동'],
    '마포구': ['합정동','망원동','상수동','연남동','공덕동'],
    '서대문구': ['홍제동','연희동','북아현동','충정로동','신촌동'],
    '서초구': ['서초동','반포동','잠원동','양재동','방배동'],
    '성동구': ['왕십리동','행당동','금호동','성수동'],
    '성북구': ['성북동','정릉동','돈암동','길음동','월곡동'],
    '송파구': ['잠실동','가락동','문정동','석촌동','오금동','방이동'],
    '양천구': ['목동','신정동','신월동','목5동'],
    '영등포구': ['영등포동','당산동','양평동','신길동'],
    '용산구': ['이태원동','한남동','용문동','서빙고동','후암동'],
    '은평구': ['불광동','응암동','역촌동','녹번동','신사동'],
    '종로구': ['종로','청운동','궁정동','평창동','사직동'],
    '중구': ['명동','을지로동','필동','회현동','신당동'],
    '중랑구': ['망우동','면목동','상봉동','신내동'],
  };

  final Map<String, Set<String>> selectedTags = {
    '지역': {},
    '길 유형': {},
    '이동수단': {},
  };

  final Map<String, int> regionToId = {
    '중구/광복동': 1, '중구/남포동': 2, '중구/대청동': 3, '중구/동광동': 4, '중구/보수동': 5, '중구/부평동': 6,
    '서구/동대신동': 7, '서구/서대신동': 8, '서구/암남동': 9, '서구/아미동': 10, '서구/토성동': 11,
    '동구/초량동': 12, '동구/수정동': 13, '동구/좌천동': 14, '동구/범일동': 15,
    '영도구/남항동': 16, '영도구/신선동': 17, '영도구/봉래동': 18, '영도구/청학동': 19, '영도구/동삼동': 20,
    '부산진구/부전동': 21, '부산진구/전포동': 22, '부산진구/양정동': 23, '부산진구/범전동': 24, '부산진구/범천동': 25, '부산진구/가야동': 26,
    '동래구/명장동': 27, '동래구/사직동': 28, '동래구/안락동': 29, '동래구/온천동': 30, '동래구/수안동': 31,
    '남구/대연동': 32, '남구/문현동': 33, '남구/감만동': 34, '남구/용호동': 35, '남구/우암동': 36,
    '북구/구포동': 37, '북구/덕천동': 38, '북구/만덕동': 39, '북구/화명동': 40,
    '해운대구/우동': 41, '해운대구/중동': 42, '해운대구/좌동': 43, '해운대구/송정동': 44, '해운대구/재송동': 45,
    '사하구/괴정동': 46, '사하구/당리동': 47, '사하구/하단동': 48, '사하구/장림동': 49, '사하구/다대동': 50,
    '금정구/장전동': 51, '금정구/구서동': 52, '금정구/부곡동': 53, '금정구/서동': 54, '금정구/금사동': 55,
    '강서구/명지동': 56, '강서구/가락동': 57, '강서구/녹산동': 58, '강서구/대저1동': 59, '강서구/대저2동': 60,
    '연제구/연산동': 61,
    '수영구/광안동': 62, '수영구/남천동': 63, '수영구/망미동': 64, '수영구/민락동': 65,
    '사상구/감전동': 66, '사상구/괘법동': 67, '사상구/덕포동': 68, '사상구/모라동': 69,
    '기장군/기장읍': 70, '기장군/정관읍': 71, '기장군/일광읍': 72, '기장군/철마면': 73, '기장군/장안읍': 74,
  };

  final Map<String, int> roadTypeToId = {
    '포장도로': 101, '비포장도로': 102, '등산로': 103, '짧은 산책로': 104, '긴 산책로': 105, '운동용 산책로': 106,
  };

  final Map<String, int> transportToId = {
    '걷기': 201, '뜀걸음': 202, '자전거': 203, '휠체어': 204, '유모차': 205,
  };

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  Future<void> _initCurrentLocation() async {
    try {
      // 권한 체크(필요 시 앱 권한 로직 보강)
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception('Permission denied');
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final country = placemark.country ?? '';
        if (country != '대한민국') {
          if (!mounted) return;
          setState(() => currentRegionLabel = '해외');
        } else {
          final gu = placemark.subAdministrativeArea ?? '';
          final dong = placemark.subLocality ?? '';
          if (!mounted) return;
          setState(() => currentRegionLabel = '$gu $dong');
          if (gu.isNotEmpty && dong.isNotEmpty) {
            final tag = '$gu/$dong';
            selectedTags['지역']?.add(tag);
          }
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => currentRegionLabel = '해외');
    }
  }

  // ---------- 워밍업(헬스체크) & 안전 파싱 ----------
  Future<void> _prePing() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/healthz');
      await http.get(url).timeout(const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {
      // 실패해도 본 검색은 진행
    }
  }

  Map<String, dynamic> _safeJsonDecode(String body) {
    if (body.isEmpty) return {};
    try {
      final v = json.decode(body);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }

  void toggleDropdown(String name) {
    setState(() {
      activeDropdown = activeDropdown == name ? null : name;
      if (name != '지역') _currentGu = null;
    });
  }

  void toggleTag(String category, String tag) {
    setState(() {
      selectedTags[category]!.contains(tag)
          ? selectedTags[category]!.remove(tag)
          : selectedTags[category]!.add(tag);
    });
  }

  void toggleRegion(String gu, String dong) => toggleTag('지역', '$gu/$dong');

  void resetSelection() {
    setState(() {
      for (final key in selectedTags.keys) selectedTags[key]!.clear();
      onlyFavorites = false;
      activeDropdown = null;
      _currentGu = null;
      _searchQuery = '';
      _initCurrentLocation();
    });
  }

  Map<String, dynamic> getSelectedTagData() {
    final Map<String, dynamic> result = {};
    selectedTags.forEach((category, tags) {
      List<String> ids = [];
      if (category == '지역') ids = tags.map((t) => regionToId[t]?.toString()).whereType<String>().toList();
      if (category == '길 유형') ids = tags.map((t) => roadTypeToId[t]?.toString()).whereType<String>().toList();
      if (category == '이동수단') ids = tags.map((t) => transportToId[t]?.toString()).whereType<String>().toList();
      result[category] = ids;
    });
    return result;
  }

  Widget buildTagChip(String category, String tag, {String? gu}) {
    final isSelected = selectedTags[category]!.contains(tag);
    final labelText = (category == '지역' && gu != null) ? tag.split('/')[1] : tag;

    return FilterChip(
      label: Text(labelText),
      selected: isSelected,
      onSelected: (_) => category == '지역' && gu != null ? toggleRegion(gu, tag.split('/')[1]) : toggleTag(category, tag),
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blueAccent.shade100,
      showCheckmark: false,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  List<Widget> buildSelectedTagChips() => selectedTags.entries
      .expand((e) => e.value.map((t) => buildTagChip(e.key, t, gu: e.key == '지역' ? t.split('/')[0] : null)))
      .toList();

  // --- 검색 버튼 클릭 ---
  Future<void> _onSearchPressed() async {
    if (_isSearching) return; // 중복 탭 방지
    setState(() => _isSearching = true);

    try {
      // 최초 1회만 서버 워밍업
      if (!_didWarmup) {
        _didWarmup = true;
        await _prePing();
      }

      // 즐겨찾기 필터는 로그인 필요
      if (onlyFavorites && (widget.userId == null || widget.userId!.isEmpty)) {
        setState(() => onlyFavorites = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('즐겨찾기 필터를 사용하려면 로그인된 사용자 ID가 필요합니다.')),
        );
        return;
      }

      final selectedData = getSelectedTagData();
      final url = Uri.parse('${ApiService.baseUrl}/search_routes');

      Future<http.Response> _doPost() {
        return http
            .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            // 서버 keep-alive 불안정하면 테스트용으로 아래 줄을 잠시 풀어보자
            // 'Connection': 'close',
          },
          body: json.encode({
            "categories": selectedData,
            "onlyFavorites": onlyFavorites,
            if (onlyFavorites) "user_id": widget.userId,
            "matchType": "AND",
          }),
        )
            .timeout(const Duration(seconds: 15));
      }

      http.Response response;
      try {
        response = await _doPost();
      } on http.ClientException catch (_) {
        // 콜드스타트/수신 중 연결 종료 보호: 최초 1회 즉시 재시도
        response = await _doPost();
      }

      if (!mounted) return;

      final status = response.statusCode;
      final data = _safeJsonDecode(response.body);

      if (status == 200) {
        final List<dynamic> routes = (data['routes'] ?? []) as List<dynamic>;
        if (routes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('조건에 맞는 경로가 없습니다.')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchedScreen(
              userId: widget.userId, // 즐겨찾기 토글/표시용
              selectedTags: selectedData,
              onlyFavorites: onlyFavorites,
              searchResults: routes.map((r) {
                return {
                  "id": r['id'],
                  "route_name": r['route_name'],
                  "nickname": r['nickname'],
                  "region_id": r['region_id'],
                  "road_type_id": r['road_type_id'],
                  "transport_id": r['transport_id'],
                  // route_path 우선, 없으면 polyline
                  "route_path": r['route_path'] ?? r['polyline'] ?? [],
                  // 즐겨찾기 정보
                  "favorite_count": r['favorite_count'] ?? 0,
                  "is_favorite": r['is_favorite'] ?? false,
                };
              }).toList(),
            ),
          ),
        );
      } else {
        final msg = (data['message'] ?? '검색 실패').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("에러 발생: $e")));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              currentRegionLabel,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
            ),
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
                    onTap: () {
                      if (widget.userId == null || widget.userId!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인 후 즐겨찾기 필터를 사용할 수 있어요.')),
                        );
                        return;
                      }
                      setState(() => onlyFavorites = !onlyFavorites);
                    },
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
                      child: Wrap(spacing: 8, runSpacing: 6, children: buildSelectedTagChips()),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // 하단 검색 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSearching ? null : _onSearchPressed,
                child: _isSearching
                    ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('검색하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget buildSimpleTagGrid(String category) {
    final tags = tagData[category]!;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((tag) => buildTagChip(category, tag)).toList(),
    );
  }

  Widget buildRegionDropdown() {
    List<String> filteredBusanGus = busanGus
        .where((gu) =>
    gu.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        busanDongs[gu]!.any((dong) => dong.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    List<String> filteredSeoulGus = seoulGus
        .where((gu) =>
    gu.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        seoulDongs[gu]!.any((dong) => dong.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    Widget buildGuTile(String gu, List<String> dongs) {
      final filteredDongs = dongs.where((dong) => dong.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      final allSelected = filteredDongs.every((dong) => selectedTags['지역']!.contains('$gu/$dong'));

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Row(
            children: [
              const Icon(Icons.location_city, size: 20, color: Colors.blueAccent),
              const SizedBox(width: 6),
              Text(gu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (allSelected) {
                      for (final dong in filteredDongs) {
                        selectedTags['지역']!.remove('$gu/$dong');
                      }
                    } else {
                      for (final dong in filteredDongs) {
                        selectedTags['지역']!.add('$gu/$dong');
                      }
                    }
                  });
                },
                child: Text(allSelected ? '전체 해제' : '전체 선택', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: filteredDongs.map((dong) => buildTagChip('지역', '$gu/$dong', gu: gu)).toList(),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildCityCard(String cityName, List<String> gus, Map<String, List<String>> dongsMap) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text(cityName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          children: gus.map((gu) => buildGuTile(gu, dongsMap[gu]!)).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: '구 또는 동 검색',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 8),
        if (filteredSeoulGus.isNotEmpty) buildCityCard('서울', filteredSeoulGus, seoulDongs),
        if (filteredBusanGus.isNotEmpty) buildCityCard('부산', filteredBusanGus, busanDongs),
      ],
    );
  }
}
