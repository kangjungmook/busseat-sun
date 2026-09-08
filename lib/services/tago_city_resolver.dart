import '../models/tago.dart';
import 'kakao_local_service.dart';

/// 카카오 행정구역명 → TAGO 도시코드 매칭.
///
/// TAGO는 `cityCode`가 필수인데 그 코드가 어느 지역인지는 이름으로만 알 수 있다.
/// 두 API의 이름 표기가 완전히 같지 않아서(예: 카카오 '성남시 분당구' ↔ TAGO
/// '성남시', 카카오 '서울' 또는 '서울특별시' ↔ TAGO '서울특별시') 느슨하게 맞춘다.
///
/// 코드 체계에서 얻는 힌트: 광역시·특별자치시는 2자리(`12`, `21`~`26`, `39`),
/// 도 소속 시·군은 5자리이고 앞 2자리가 도를 뜻한다(`31010`, `31020` → `31` 경기).
/// 그래서 시·군을 못 맞히면 **같은 도 전체**로 넓히는 2단계 폴백이 가능하다.
class TagoCityResolver {
  /// 공백을 없앤 비교용 문자열.
  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '');

  /// '성남시 분당구' → '성남시' (TAGO는 구 단위로 안 쪼갠다).
  static String _firstToken(String s) {
    final t = s.trim().split(RegExp(r'\s+'));
    return t.isEmpty ? '' : t.first;
  }

  /// '서울특별시'/'서울' → '서울'. 시도 표기 차이를 흡수하려고 앞 2글자만 본다.
  static String _sidoCore(String s) {
    final n = _norm(s);
    return n.length <= 2 ? n : n.substring(0, 2);
  }

  /// [region]에 해당하는 도시를 유력한 순서로 돌려준다.
  ///
  /// 1. 시·군 이름이 정확히 맞는 도시 (예: '성남시')
  /// 2. 시도 이름이 맞는 도시 (광역시·특별자치시. 예: '세종특별자치시')
  ///
  /// 하나도 못 찾으면 빈 리스트 — 호출하는 쪽이 더 넓은 검색으로 폴백한다.
  static List<TagoCity> candidatesFor(KakaoRegion region, List<TagoCity> cities) {
    final out = <TagoCity>[];
    final seen = <String>{};

    void add(TagoCity c) {
      if (seen.add(c.code)) out.add(c);
    }

    final sigungu = _norm(_firstToken(region.sigungu));
    if (sigungu.isNotEmpty) {
      for (final c in cities) {
        if (_norm(c.name) == sigungu) add(c);
      }
    }

    final core = _sidoCore(region.sido);
    if (core.isNotEmpty) {
      for (final c in cities) {
        // 광역시·특별자치시는 도시 하나가 곧 시도다 ('세종특별자치시').
        // 도(경기·강원 등)는 이 규칙에 걸리는 도시가 없거나 애매하니
        // 아래 [provinceSiblings]로 넓히는 쪽을 쓴다.
        if (_norm(c.name).startsWith(core)) add(c);
      }
    }
    return out;
  }

  /// [city]와 같은 도(道)에 속한 도시들 — 5자리 코드의 앞 2자리가 같은 것.
  ///
  /// 시·군을 정확히 못 맞혔거나, 그 도시에서 노선을 못 찾았을 때 쓴다
  /// (광역버스는 출발 시가 아니라 옆 시에 등록돼 있을 수 있다).
  /// 도 전체라도 40개 안팎이라 전국 200개보다는 훨씬 싸다.
  static List<TagoCity> provinceSiblings(TagoCity city, List<TagoCity> cities) {
    if (city.code.length < 5) return const []; // 광역시는 형제 도시가 없다
    final prefix = city.code.substring(0, 2);
    return cities.where((c) => c.code.length >= 5 && c.code.startsWith(prefix)).toList();
  }
}
