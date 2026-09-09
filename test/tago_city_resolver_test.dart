import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/models/tago.dart';
import 'package:sunseat/services/kakao_local_service.dart';
import 'package:sunseat/services/tago_city_resolver.dart';

/// TAGO `getCtyCodeList`가 실제로 돌려준 목록 (2026-09-08, 138개 중 발췌).
///
/// 매칭이 어긋나면 앱은 조용히 전국 138개 도시를 훑거나, 더 나쁘게는 멀쩡한
/// 지역에 "지원하지 않아요"를 띄운다. 둘 다 눈에 안 띄는 실패라서, 실제 응답에
/// 있던 **까다로운 표기들**을 그대로 넣고 고정해둔다:
/// - `'세종특별시'`  — 카카오는 '세종특별자치시'로 준다 (표기 불일치)
/// - `'제주도'`      — 카카오는 '제주특별자치도'
/// - `'대전광역시/계룡시'`, `'원주시/횡성군'` — 한 코드에 두 지역이 묶여 있다
/// - `'광주광역시'` vs `'광주시'`(경기) — 이름이 겹치는 서로 다른 지역
const _cities = <TagoCity>[
  TagoCity(code: '12', name: '세종특별시'),
  TagoCity(code: '21', name: '부산광역시'),
  TagoCity(code: '24', name: '광주광역시'),
  TagoCity(code: '25', name: '대전광역시/계룡시'),
  TagoCity(code: '39', name: '제주도'),
  TagoCity(code: '31020', name: '성남시'),
  TagoCity(code: '31250', name: '광주시'),
  TagoCity(code: '32010', name: '춘천시'),
  TagoCity(code: '32020', name: '원주시/횡성군'),
  TagoCity(code: '34070', name: '계룡시'),
];

List<String> _codesFor(String sido, String sigungu) =>
    TagoCityResolver.candidatesFor(KakaoRegion(sido: sido, sigungu: sigungu), _cities)
        .map((c) => c.code)
        .toList();

void main() {
  group('candidatesFor — 첫 후보가 실제로 그 지역이어야 한다', () {
    test('시·군 이름이 그대로 있는 경우', () {
      expect(_codesFor('경기도', '성남시 분당구').first, '31020');
    });

    test('세종: 카카오 "세종특별자치시" ↔ TAGO "세종특별시"', () {
      expect(_codesFor('세종특별자치시', '').first, '12');
    });

    test('제주: 카카오 "제주특별자치도" ↔ TAGO "제주도"', () {
      expect(_codesFor('제주특별자치도', '서귀포시').first, '39');
    });

    test('슬래시로 묶인 뒤쪽 지역도 찾는다 (원주시/횡성군)', () {
      expect(_codesFor('강원특별자치도', '횡성군').first, '32020');
    });

    test('슬래시로 묶인 앞쪽 지역 (대전광역시/계룡시)', () {
      expect(_codesFor('대전광역시', '유성구').first, '25');
    });

    test('계룡시는 별도 코드가 있으므로 그쪽이 우선', () {
      expect(_codesFor('충청남도', '계룡시').first, '34070');
    });

    test('이름이 겹쳐도 광역시와 경기 광주시를 헷갈리지 않는다', () {
      expect(_codesFor('광주광역시', '북구').first, '24');
      expect(_codesFor('경기도', '광주시').first, '31250');
    });
  });

  group('candidatesFor — 못 찾는 경우', () {
    test('서울은 목록에 없다 (TAGO 미담당)', () {
      expect(_codesFor('서울특별시', '강남구'), isEmpty);
    });
  });

  group('sidoIsSingleCity — "미지원"이라고 단정해도 되는지', () {
    test('광역시·특별시·특별자치시는 TAGO에 도시 하나로 존재한다', () {
      expect(TagoCityResolver.sidoIsSingleCity('서울특별시'), isTrue);
      expect(TagoCityResolver.sidoIsSingleCity('부산광역시'), isTrue);
      expect(TagoCityResolver.sidoIsSingleCity('세종특별자치시'), isTrue);
    });

    test('도는 시·군 이름으로만 들어있어 단정하면 안 된다', () {
      // 강원·전북은 2023~2024년에 '특별자치도'로 바뀌었다. 이걸 광역시처럼
      // 취급하면 매칭이 한 번 어긋났을 때 그 도 전체가 "미지원"으로 막힌다.
      expect(TagoCityResolver.sidoIsSingleCity('강원특별자치도'), isFalse);
      expect(TagoCityResolver.sidoIsSingleCity('전북특별자치도'), isFalse);
      expect(TagoCityResolver.sidoIsSingleCity('경기도'), isFalse);
      expect(TagoCityResolver.sidoIsSingleCity('제주특별자치도'), isFalse);
    });
  });

  group('provinceSiblings — 같은 도로 넓히기', () {
    test('5자리 코드는 앞 2자리가 같은 도시들을 돌려준다', () {
      final gangwon = TagoCityResolver.provinceSiblings(
        const TagoCity(code: '32020', name: '원주시/횡성군'),
        _cities,
      ).map((c) => c.code);
      expect(gangwon, containsAll(<String>['32010', '32020']));
      expect(gangwon, isNot(contains('31020'))); // 경기는 섞이면 안 된다
    });

    test('광역시는 형제 도시가 없다', () {
      expect(
        TagoCityResolver.provinceSiblings(const TagoCity(code: '21', name: '부산광역시'), _cities),
        isEmpty,
      );
    });
  });

  group('KakaoRegion.displayName — 화면에 띄울 지명', () {
    test('시군구 + 동', () {
      expect(
        const KakaoRegion(sido: '대전광역시', sigungu: '유성구', dong: '봉명동').displayName,
        '유성구 봉명동',
      );
    });

    test('시군구가 비는 지역(세종)은 시도로 채운다', () {
      // 실제 응답에서 region_2depth_name이 빈 문자열로 온다.
      expect(
        const KakaoRegion(sido: '세종특별자치시', sigungu: '', dong: '집현동').displayName,
        '세종특별자치시 집현동',
      );
    });

    test('동이 없으면 시군구만', () {
      expect(const KakaoRegion(sido: '경기', sigungu: '성남시 분당구').displayName, '성남시 분당구');
    });
  });
}
