import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

/// 부산 전용 지역 필터 기준
class RegionFilterCriteria {
  final String city;   // 고정: '부산광역시'
  final String? gu;    // 예: '부산진구'
  final String? dong;  // 예: '전포동'

  const RegionFilterCriteria({
    required this.city,
    this.gu,
    this.dong,
  });

  bool get isEmpty => gu == null && dong == null;

  String get label {
    if (dong != null) return '$gu · $dong';
    if (gu != null) return '$gu';
    return city;
  }

  Map<String, String?> toMap() => {'city': city, 'gu': gu, 'dong': dong};

  static RegionFilterCriteria fromMap(Map<String, String?> m) => RegionFilterCriteria(
    city: m['city'] ?? '부산광역시',
    gu: m['gu'],
    dong: m['dong'],
  );
}

/// 부산 구/군 → 동 목록 (법정동 표기 권장; 필요 시 추가)
const Map<String, List<String>> _BUSAN_DONGS = {
  '부산진구': ['전포동', '부전동', '범천동', '가야동', '당감동', '양정동'],
  '남구': ['대연동', '문현동', '용호동', '우암동'],
  '해운대구': ['우동', '좌동', '중동', '송정동', '반송동', '반여동'],
  '수영구': ['광안동', '남천동', '민락동'],
  '동래구': ['명륜동', '온천동', '사직동', '낙민동', '복천동'],
  '연제구': ['연산동'],
  '사상구': ['감전동', '괘법동', '주례동', '학장동'],
  '사하구': ['하단동', '당리동', '괴정동', '신평동'],
  '강서구': ['명지동', '대저동', '가락동'],
  '금정구': ['장전동', '구서동', '부곡동', '서동', '금사동'],
  '영도구': ['남항동', '영선동', '봉래동', '청학동', '동삼동'],
  '동구': ['초량동', '수정동', '좌천동', '범일동'],
  '중구': ['중앙동', '동광동', '보수동', '부평동', '신창동'],
  '북구': ['덕천동', '구포동', '만덕동'],
  '기장군': ['기장읍', '정관읍', '일광읍', '철마면'],
};

/// ───────────────────────────────────────────────────────────────────────────
/// 계정별 저장을 위한 키(네임스페이스: userId 붙이기)
String _kCity(String uid) => 'region_city_$uid';
String _kGu(String uid) => 'region_gu_$uid';
String _kDong(String uid) => 'region_dong_$uid';
/// ───────────────────────────────────────────────────────────────────────────

class RegionFilter {
  /// 저장된 필터 로드 (없으면 부산만 설정) — 계정별
  static Future<RegionFilterCriteria> load(String userId) async {
    final p = await SharedPreferences.getInstance();
    final city = p.getString(_kCity(userId)) ?? '부산광역시';
    final gu = p.getString(_kGu(userId));
    final dong = p.getString(_kDong(userId));

    // 저장값을 안전하게 정상화
    final normalized = _sanitize(city: city, gu: gu, dong: dong);
    return RegionFilterCriteria(
      city: '부산광역시',
      gu: normalized.$1,
      dong: normalized.$2,
    );
  }

  /// 선택값 저장 — 계정별
  static Future<void> save(String userId, RegionFilterCriteria c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCity(userId), c.city);

    // 저장 전에 정상화(리스트에 없으면 null로)
    final norm = _sanitize(city: c.city, gu: c.gu, dong: c.dong);
    final guOk = norm.$1;
    final dongOk = norm.$2;

    if (guOk != null) {
      await p.setString(_kGu(userId), guOk);
    } else {
      await p.remove(_kGu(userId));
    }
    if (dongOk != null) {
      await p.setString(_kDong(userId), dongOk);
    } else {
      await p.remove(_kDong(userId));
    }
  }

  /// 첫 진입 시점에 다이얼로그로 선택 요구 (이미 선택되어 있으면 건너뜀) — 계정별
  static Future<RegionFilterCriteria> ensureSelected(
      BuildContext context,
      String userId,
      ) async {
    final current = await load(userId);
    if (!current.isEmpty) return current; // 이 계정에 이미 선택됨

    final selected = await showRegionSelector(context, initial: current);
    if (selected != null) {
      await save(userId, selected);
      return selected;
    }
    // 사용자가 취소한 경우라도 부산만 유지
    return current;
  }

  /// 구/동 선택 다이얼로그 (부산 한정)
  static Future<RegionFilterCriteria?> showRegionSelector(
      BuildContext context, {
        RegionFilterCriteria? initial,
      }) async {
    String? gu = initial?.gu;
    String? dong = initial?.dong;

    // UI에서 value가 items에 반드시 포함되도록 초기값을 먼저 정상화
    final norm = _sanitize(city: '부산광역시', gu: gu, dong: dong);
    gu = norm.$1;
    dong = norm.$2;

    return showDialog<RegionFilterCriteria>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final guItems = _BUSAN_DONGS.keys.toList()..sort();
            final dongItems = (gu == null)
                ? <String>[]
                : List<String>.from(_BUSAN_DONGS[gu]!)..sort();

            // value는 반드시 items 안에 있을 때만 지정
            final safeGu = guItems.contains(gu) ? gu : null;
            final safeDong = dongItems.contains(dong) ? dong : null;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFF8F4EC),
              title: const Text('지역 선택 (부산)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1) 구/군
                    DropdownButtonFormField<String>(
                      value: safeGu,
                      decoration: InputDecoration(
                        labelText: '구/군',
                        hintText: '구/군을 선택하세요',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: guItems
                          .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          gu = v;
                          dong = null; // 구 바꾸면 동 초기화
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // 2) 동/읍/면
                    DropdownButtonFormField<String>(
                      value: safeDong,
                      decoration: InputDecoration(
                        labelText: '동/읍/면',
                        hintText: '동/읍/면을 선택하세요',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: dongItems
                          .map((d) =>
                          DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          dong = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('건너뛰기'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final norm2 =
                    _sanitize(city: '부산광역시', gu: gu, dong: dong);
                    final c = RegionFilterCriteria(
                      city: '부산광역시',
                      gu: norm2.$1,
                      dong: norm2.$2,
                    );
                    Navigator.pop(dialogCtx, c);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3CAEA3)),
                  child:
                  const Text('확인', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 경로(첫 좌표 기준)가 선택 지역과 일치하는지 판정
  /// - 서버에 지역 메타가 없을 때 사용 (역지오코딩 비교)
  static Future<bool> routeMatchesCriteria(
      List<LatLng> route, RegionFilterCriteria c) async {
    if (route.isEmpty) return false;
    if (c.isEmpty) return true; // 선택이 없다면 전체 허용

    try {
      final start = route.first;
      final placemarks =
      await placemarkFromCoordinates(start.latitude, start.longitude);
      if (placemarks.isEmpty) return false;

      final p = placemarks.first;
      final city = (p.administrativeArea ?? '').replaceAll(' ', '');
      final gu = (p.subAdministrativeArea ?? '').trim(); // ex) 부산진구
      final dong = (p.locality ?? p.subLocality ?? '').trim(); // ex) 전포동 등

      if (!city.contains('부산')) return false;
      if (c.gu != null && c.gu != gu) return false;
      if (c.dong != null && c.dong != dong) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 여러 경로를 지역 기준으로 필터링 (클라이언트 후처리용)
  /// - items: 서버 응답 형태에 맞춰 { 'route_path': [[lat,lng], ...], ... } 구조를 기대
  /// - getPath: 각 아이템에서 좌표리스트를 꺼내는 함수
  static Future<List<T>> filterRoutes<T>(
      List<T> items,
      List<LatLng> Function(T) getPath,
      RegionFilterCriteria c,
      ) async {
    if (c.isEmpty) return items;
    final List<T> kept = [];
    for (final item in items) {
      final ok = await routeMatchesCriteria(getPath(item), c);
      if (ok) kept.add(item);
    }
    return kept;
  }

  /// 저장값/현재값을 안전하게 맞춤
  /// 반환: (gu, dong)
  static (String?, String?) _sanitize(
      {required String city, String? gu, String? dong}) {
    // 부산만 서비스하므로 city는 고정으로 취급
    final guList = _BUSAN_DONGS.keys.toList();
    if (gu == null || !guList.contains(gu)) {
      return (null, null);
    }
    final dongList = _BUSAN_DONGS[gu]!;
    if (dong == null || !dongList.contains(dong)) {
      return (gu, null);
    }
    return (gu, dong);
  }

  /// (선택) 특정 계정의 지역 선택값 초기화
  static Future<void> reset(String userId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCity(userId));
    await p.remove(_kGu(userId));
    await p.remove(_kDong(userId));
  }
}
