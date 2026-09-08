import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';
import '../models/tago.dart';

/// 국토교통부 TAGO 버스노선정보 API(BusRouteInfoInqireService) 클라이언트.
///
/// 상태: **공식 문서로 확정**. "오픈API활용가이드_국토교통부(TAGO)_버스노선정보v1.0"
/// 문서(사용자가 활용신청 승인 후 내려받아 공유해줌)를 그대로 반영했고,
/// getRouteNoList는 실제 호출로도 resultCode "00" NORMAL SERVICE를 확인했다.
///
/// 4개 오퍼레이션 전부 **같은 base URL** 아래에 있다 — getCtyCodeList도
/// 별도 서비스(BusSttnInfoInqireService)가 아니라 여기 있다. 처음에 웹 검색만
/// 보고 정류소 API 쪽으로 잘못 짚었던 부분을 문서로 바로잡았다.
/// [findRouteNationwide]가 도시 하나에서 노선을 찾았을 때 함께 돌려주는 짝.
typedef TagoRouteMatch = ({TagoCity city, TagoRoute route});

/// TAGO 응답 본문을 **항상 UTF-8로** 읽는다.
///
/// TAGO는 Content-Type에 charset을 제대로 안 실어준다. 그런데 `http` 패키지의
/// `Response.body`는 charset이 없으면 **latin1**로 디코딩해서(패키지 기본값),
/// 정류장 이름·도시명 같은 한글이 전부 깨진 문자로 들어온다.
/// (브라우저로 같은 URL을 열어도 "?몄쥌?밸퀧"처럼 깨져 보이는 게 같은 이유다.)
/// 그래서 `body` 대신 `bodyBytes`를 직접 UTF-8로 디코딩한다.
///
/// `allowMalformed: true`는 혹시 진짜로 UTF-8이 아닌 응답이 와도 예외 대신
/// 대체 문자로 넘어가게 해서, 인코딩 하나 때문에 검색 전체가 죽지 않게 한다.
String decodeTagoBody(http.Response res) => utf8.decode(res.bodyBytes, allowMalformed: true);

class TagoBusService {
  static const String _baseUrl = 'https://apis.data.go.kr/1613000/BusRouteInfoInqireService';

  // 도시코드는 자주 바뀌지 않으니 앱 켜 있는 동안은 다시 안 불러온다.
  static List<TagoCity>? _cityCache;

  static Future<Map<String, dynamic>> _get(String operation, Map<String, String> params) async {
    if (!TagoConfig.isConfigured) {
      throw StateError('TAGO_API_KEY가 설정되지 않았습니다. secrets/dart_defines.json 참고.');
    }
    final uri = Uri.parse('$_baseUrl/$operation').replace(queryParameters: {
      'serviceKey': TagoConfig.apiKey,
      '_type': 'json',
      ...params,
    });
    final res = await http.get(uri);
    final body = decodeTagoBody(res);
    if (res.statusCode != 200) {
      throw TagoApiException('HTTP ${res.statusCode}', rawBody: body);
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw TagoApiException('JSON 파싱 실패 (XML 에러 응답일 가능성) — rawBody 확인', rawBody: body);
    }

    // 서비스키 미등록/IP 미등록/활용기간 만료 등 공통 오류는 이 형식으로 온다
    // (문서 2-1절, 실제로도 확인됨):
    // {"OpenAPI_ServiceResponse":{"cmmMsgHeader":{"errMsg":..., "returnAuthMsg":..., "returnReasonCode":...}}}
    final cmmHeader = decoded['OpenAPI_ServiceResponse']?['cmmMsgHeader'];
    if (cmmHeader != null) {
      // returnAuthMsg는 한글이라 깨져 보일 수 있어 영문 errMsg를 먼저 쓴다
      // (예: 활용신청 안 된 서비스 → "NO_OPENAPI_SERVICE_ERROR", 코드 12).
      throw TagoApiException(
        'TAGO 공통 오류(${cmmHeader['returnReasonCode']}): ${cmmHeader['errMsg'] ?? cmmHeader['returnAuthMsg']}',
        rawBody: body,
      );
    }

    final header = decoded['response']?['header'];
    final resultCode = header?['resultCode']?.toString();
    if (resultCode != null && resultCode != '00') {
      throw TagoApiException('TAGO 오류 $resultCode: ${header?['resultMsg']}', rawBody: body);
    }
    return decoded as Map<String, dynamic>;
  }

  /// items.item은 결과가 1건이면 Map, 여러 건이면 List로 온다.
  static List<Map<String, dynamic>> _items(Map<String, dynamic> decoded) {
    final items = decoded['response']?['body']?['items'];
    if (items == null || items == '') return [];
    final item = items['item'];
    if (item == null) return [];
    if (item is List) return item.cast<Map<String, dynamic>>();
    return [item as Map<String, dynamic>];
  }

  /// [도시코드 목록 조회] getCtyCodeList — 파라미터 없음. 세션 내 캐싱.
  static Future<List<TagoCity>> getCityCodes({bool forceRefresh = false}) async {
    if (!forceRefresh && _cityCache != null) return _cityCache!;
    final decoded = await _get('getCtyCodeList', {});
    final cities = _items(decoded).map(TagoCity.fromJson).toList();
    _cityCache = cities;
    return cities;
  }

  /// 주어진 [cities]에서만 노선번호를 찾는다 (동시 [concurrency]개씩).
  ///
  /// TAGO는 cityCode가 필수라 "도시를 모르는 검색"이 없다. 그래서 앱이 도시를
  /// 하나씩 물어보는 수밖에 없는데, **호출 수가 곧 도시 수**라서 범위를 좁히는
  /// 게 중요하다 (전국 = 150~250회, 개발계정 일일 한도가 보통 1,000건).
  /// 범위 선택은 [TagoRouteRepository]가 위치 기반으로 단계적으로 넓힌다.
  static Future<List<TagoRouteMatch>> findRouteInCities(
    String routeNo,
    List<TagoCity> cities, {
    int concurrency = 8,
    void Function(int done, int total)? onProgress,
  }) async {
    final matches = <TagoRouteMatch>[];
    var done = 0;

    for (var i = 0; i < cities.length; i += concurrency) {
      final batch = cities.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(batch.map((city) async {
        try {
          final routes = await searchRoutesByNumber(cityCode: city.code, routeNo: routeNo);
          return routes.map((r) => (city: city, route: r)).toList();
        } catch (_) {
          // 개별 도시 조회 실패(그 도시엔 해당 노선유형 자체가 없는 등)는
          // 무시하고 계속 진행 — 전체 검색을 막을 이유가 아니다.
          return <TagoRouteMatch>[];
        }
      }));
      for (final r in batchResults) {
        matches.addAll(r);
      }
      done += batch.length;
      onProgress?.call(done, cities.length);
    }
    return matches;
  }

  /// 전국 도시를 전부 훑는다 — **호출 수가 도시 수만큼(150~250회)** 나가므로
  /// 마지막 수단으로만 쓴다. 평소 경로는 [TagoRouteRepository.search]가
  /// 위치로 도시를 좁힌 뒤 [findRouteInCities]를 부르는 쪽이다.
  static Future<List<TagoRouteMatch>> findRouteNationwide(
    String routeNo, {
    int concurrency = 8,
    void Function(int done, int total)? onProgress,
  }) async {
    final cities = await getCityCodes();
    return findRouteInCities(routeNo, cities, concurrency: concurrency, onProgress: onProgress);
  }

  /// [노선번호목록 조회] getRouteNoList — cityCode 필수, routeNo 옵션(비우면 그 도시 전체 노선).
  static Future<List<TagoRoute>> searchRoutesByNumber({
    required String cityCode,
    required String routeNo,
  }) async {
    final decoded = await _get('getRouteNoList', {
      'cityCode': cityCode,
      'routeNo': routeNo,
      'pageNo': '1',
      'numOfRows': '20',
    });
    return _items(decoded).map(TagoRoute.fromJson).toList();
  }

  /// [노선정보항목 조회] getRouteInfoIem — 배차간격 등 노선 상세.
  static Future<TagoRoute?> getRouteInfo({
    required String cityCode,
    required String routeId,
  }) async {
    final decoded = await _get('getRouteInfoIem', {
      'cityCode': cityCode,
      'routeId': routeId,
    });
    final items = _items(decoded);
    return items.isEmpty ? null : TagoRoute.fromJson(items.first);
  }

  /// [노선별경유정류소목록 조회] getRouteAcctoThrghSttnList — 정류소 이름+좌표+순번.
  ///
  /// 정류소가 [pageSize]개를 넘으면 `totalCount`를 보고 다음 페이지까지 이어
  /// 받는다. 한 페이지만 받으면 긴 노선의 뒷부분이 통째로 잘려서, 종점이
  /// 엉뚱한 정류장이 되고 그걸로 계산한 진행 방위(bearing)까지 틀어진다
  /// — 좌석 판정이 조용히 잘못되는 경로라 페이징을 넣었다.
  static Future<List<TagoRouteStop>> getRouteStops({
    required String cityCode,
    required String routeId,
    int pageSize = 200,
    int maxPages = 10,
  }) async {
    final stops = <TagoRouteStop>[];
    var pageNo = 1;

    while (pageNo <= maxPages) {
      final decoded = await _get('getRouteAcctoThrghSttnList', {
        'cityCode': cityCode,
        'routeId': routeId,
        'pageNo': '$pageNo',
        'numOfRows': '$pageSize',
      });
      final items = _items(decoded);
      stops.addAll(items.map(TagoRouteStop.fromJson));

      // totalCount는 문자열로 올 수도 숫자로 올 수도 있다 (routeno가 "B7"/430
      // 둘 다로 오는 것과 같은 이유) — toString 후 파싱한다.
      final total = int.tryParse(decoded['response']?['body']?['totalCount']?.toString() ?? '');
      if (items.isEmpty || total == null || stops.length >= total) break;
      pageNo++;
    }
    return stops;
  }
}

class TagoApiException implements Exception {
  final String message;
  final String rawBody;

  TagoApiException(this.message, {required this.rawBody});

  @override
  String toString() => message;
}
