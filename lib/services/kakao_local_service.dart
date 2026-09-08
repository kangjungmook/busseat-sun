import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/kakao_local_config.dart';

/// 좌표가 속한 행정구역.
class KakaoRegion {
  /// region_1depth_name — 시/도. 예: '세종특별자치시', '경기', '서울'.
  /// (카카오가 '서울'로 줄지 '서울특별시'로 줄지 확정하지 못해, 매칭하는 쪽에서
  /// 앞 두 글자만 비교하도록 했다 — tago_city_resolver.dart 참고.)
  final String sido;

  /// region_2depth_name — 시/군/구. 예: '성남시 분당구', '강남구', '' (세종 등).
  final String sigungu;

  const KakaoRegion({required this.sido, required this.sigungu});

  @override
  String toString() => '$sido $sigungu'.trim();
}

/// 카카오 로컬 API — 좌표 → 행정구역(coord2regioncode).
///
/// ⚠️ **이 세션에서 실제 호출로 검증하지 못했다** (샌드박스에서
/// `dapi.kakao.com` 접근 차단). 엔드포인트·파라미터·응답 필드명은 널리 쓰이는
/// 공개 스펙을 따랐다. 실패하면 [regionForCoord]가 null을 돌려주고,
/// 호출하는 쪽(`TagoRouteRepository`)은 예전처럼 넓은 범위 검색으로 조용히
/// 넘어가므로 앱이 멈추지는 않는다.
///
/// 브라우저로 먼저 확인하려면(REST 키는 헤더로 보내야 해서 주소창만으로는 안 되고
/// curl이 필요하다):
///
/// ```sh
/// curl -H "Authorization: KakaoAK <REST API 키>" \
///   "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json?x=127.322785&y=36.498135"
/// ```
///
/// **자주 걸리는 함정** — 키가 맞는데도 이런 응답이 오면:
/// ```json
/// {"errorType":"NotAuthorizedError","message":"App(햇살좌석) disabled OPEN_MAP_AND_LOCAL service."}
/// ```
/// 키 문제가 아니라 **앱에서 카카오맵 제품이 꺼져 있는 것**이다 (2026-09-08 실제로 겪음).
/// 카카오 디벨로퍼스 → 내 애플리케이션 → **제품 설정 → 카카오맵 → 활성화 ON**.
/// 같은 스위치가 지도 화면(JS SDK)에도 걸려 있어서, 꺼져 있으면 둘 다 안 된다.
class KakaoLocalService {
  static const String _url = 'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json';

  /// [lat]/[lng]가 속한 행정구역. 키가 없거나 실패하면 null.
  static Future<KakaoRegion?> regionForCoord({required double lat, required double lng}) async {
    if (!KakaoLocalConfig.isConfigured) return null;

    // 카카오는 x=경도, y=위도 순서다 (위경도 반대로 넣는 실수가 잦은 지점).
    final uri = Uri.parse(_url).replace(queryParameters: {'x': '$lng', 'y': '$lat'});
    final res = await http.get(uri, headers: {'Authorization': 'KakaoAK ${KakaoLocalConfig.restApiKey}'});
    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final docs = decoded['documents'];
    if (docs is! List || docs.isEmpty) return null;

    // region_type 'B'(법정동)를 우선하고, 없으면 첫 번째를 쓴다.
    final doc = docs.firstWhere(
      (d) => d is Map && d['region_type'] == 'B',
      orElse: () => docs.first,
    ) as Map;

    return KakaoRegion(
      sido: (doc['region_1depth_name'] ?? '').toString(),
      sigungu: (doc['region_2depth_name'] ?? '').toString(),
    );
  }
}
