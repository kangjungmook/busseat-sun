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

  /// TAGO 도시명 하나가 실제로는 **여러 지역을 묶은 것**일 수 있다:
  /// `'대전광역시/계룡시'`, `'원주시/횡성군'` (2026-09-08 실제 목록 확인).
  /// 슬래시로 갈라 각 조각을 따로 비교해야 횡성군 사용자가 32020에 걸린다.
  static List<String> _nameParts(String s) =>
      s.split('/').map(_norm).where((e) => e.isNotEmpty).toList();

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

  /// '성남시' → '성남'. 두 API가 '시/군/구'를 붙이는지가 서로 다를 수 있어
  /// 접미사를 떼고도 한 번 비교한다. 한 글자만 남는 경우('중구'→'중')는
  /// 엉뚱한 도시와 겹치기 쉬워 비교에 쓰지 않는다.
  static String? _sigunguCore(String s) {
    final n = _norm(s);
    final stripped = (n.length > 1 && (n.endsWith('시') || n.endsWith('군') || n.endsWith('구')))
        ? n.substring(0, n.length - 1)
        : n;
    return stripped.length >= 2 ? stripped : null;
  }

  /// 이 시도가 TAGO에서 **도시 하나로 존재하는지**.
  ///
  /// 광역시·특별시·특별자치시는 그 이름 자체가 TAGO의 도시다('세종특별자치시').
  /// 반면 '경기도' 같은 도는 TAGO에 도 단위 도시가 없고 '성남시'처럼 시·군
  /// 이름으로만 들어있다.
  ///
  /// 이 구분이 필요한 이유: 후보를 못 찾았을 때 **"미지원"이라고 단정해도
  /// 되는지**가 갈리기 때문이다. 광역시인데 못 찾았으면 정말 TAGO가 담당하지
  /// 않는 것이고(서울), 도인데 못 찾은 건 이름 표기가 어긋났을 뿐일 수 있다.
  /// 후자를 미지원으로 단정하면 멀쩡히 되는 지역 사용자에게 앱이 영영 막힌
  /// 것처럼 보인다 — 그래서 도 지역은 넓은 검색으로 넘긴다.
  static bool sidoIsSingleCity(String sido) {
    final n = _norm(sido);
    return n.endsWith('특별시') || n.endsWith('광역시') || n.endsWith('특별자치시');
  }

  /// [region]에 해당하는 도시를 유력한 순서로 돌려준다.
  ///
  /// 1. 시·군 이름이 정확히 맞는 도시 (예: 카카오 '성남시 분당구' → TAGO '성남시')
  /// 2. 시도 이름이 정확히 맞는 도시 (예: '세종특별자치시')
  /// 3. 시도 앞 2글자로 시작하는 도시 (표기 차이 흡수: '세종' → '세종시')
  ///
  /// 2·3을 나눈 이유는 오탐 때문이다. 예를 들어 광주광역시 사용자는 시군구가
  /// '북구'라 1번에서 안 걸리고 3번으로 내려오는데, `startsWith('광주')`는
  /// **경기도 광주시**까지 같이 잡는다. 정확히 일치하는 걸 먼저 넣어두면
  /// 첫 번째 후보(=province 폴백의 기준)가 엉뚱한 도시가 되지 않는다.
  ///
  /// 세종처럼 `region_2depth_name`이 빈 문자열인 지역도 있어서(2026-09-08
  /// 실제 응답 확인) 시군구는 비어 있을 수 있다 — 그때는 2·3번으로 잡힌다.
  ///
  /// 하나도 못 찾으면 빈 리스트 — **TAGO가 그 지역을 아예 담당하지 않는다는
  /// 뜻일 수 있다** (서울처럼). 호출하는 쪽이 그 경우를 구분해서 다룬다.
  static List<TagoCity> candidatesFor(KakaoRegion region, List<TagoCity> cities) {
    final out = <TagoCity>[];
    final seen = <String>{};

    void add(TagoCity c) {
      if (seen.add(c.code)) out.add(c);
    }

    bool anyPart(TagoCity c, bool Function(String part) test) => _nameParts(c.name).any(test);

    // 1) 시·군 이름이 그대로 일치 ('성남시' → '성남시')
    final sigungu = _norm(_firstToken(region.sigungu));
    if (sigungu.isNotEmpty) {
      // 이름 **전체**가 같은 도시를 먼저 본다. 조합명의 한 조각과 같은 것보다
      // 강한 신호이기 때문 — 계룡시 사용자는 '대전광역시/계룡시'(25)가 아니라
      // 자기 코드 '계룡시'(34070)가 첫 후보여야 도(충남) 폴백이 살아난다.
      for (final c in cities) {
        if (_norm(c.name) == sigungu) add(c);
      }
      for (final c in cities) {
        if (anyPart(c, (p) => p == sigungu)) add(c);
      }
      // 2) 접미사 표기만 다른 경우 ('성남시' ↔ '성남')
      final core = _sigunguCore(sigungu);
      if (core != null) {
        for (final c in cities) {
          if (anyPart(c, (p) => _sigunguCore(p) == core)) add(c);
        }
      }
    }

    // 3) 시도 이름이 그대로 일치 ('대전광역시' → '대전광역시/계룡시'의 앞 조각)
    final sido = _norm(region.sido);
    if (sido.isNotEmpty) {
      for (final c in cities) {
        if (anyPart(c, (p) => p == sido)) add(c);
      }
    }

    // 4) 시도 앞 2글자로 시작 — 개편·약칭 표기차를 흡수한다.
    //    카카오 '세종특별자치시' ↔ TAGO '세종특별시',
    //    카카오 '제주특별자치도' ↔ TAGO '제주도' 가 여기서 걸린다.
    final core = _sidoCore(region.sido);
    if (core.isNotEmpty) {
      for (final c in cities) {
        if (anyPart(c, (p) => p.startsWith(core))) add(c);
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
