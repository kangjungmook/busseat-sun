import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';
import '../models/tago.dart';

/// 국토교통부 TAGO 버스노선정보 / 버스정류소정보 API 클라이언트.
///
/// 상태: **부분 검증**. 이 세션은 data.go.kr / apis.data.go.kr 접속이
/// 네트워크 정책으로 막혀 있어 실제로 호출해서 확인하지 못했다.
/// 웹 검색으로 다음까지는 확인했다:
/// - base URL 2개(아래 상수), 오퍼레이션 이름 3개, cityCode가 필수라는 것
/// - getRouteAcctoThrghSttnList 응답 필드: citycode, gpslati, gpslong, nodeid, nodenm, nodeno
/// - getCtyCodeList가 BusSttnInfoInqireService 아래 있다는 것
///
/// 검색으로 못 찾은 것(그래서 [TagoRoute]/[TagoRouteStop]의 일부 필드는 추정):
/// - getRouteNoList 응답 필드명 (routeid/routeno/routetp/startnodenm/endnodenm은 추정)
/// - getRouteAcctoThrghSttnList의 정확한 순번/상하행 필드명
///
/// [TagoDebugScreen](../screens/tago_debug_screen.dart)에서 실제로 호출해보고
/// 원본 JSON을 그대로 화면에 띄운다 — 실기기에서 실행해보고 결과(특히 에러
/// 메시지나 실제 필드명)를 알려주면 이 파일을 바로 맞출 수 있다.
class TagoBusService {
  static const String _routeBaseUrl = 'https://apis.data.go.kr/1613000/BusRouteInfoInqireService';
  static const String _stationBaseUrl = 'https://apis.data.go.kr/1613000/BusSttnInfoInqireService';

  static Future<Map<String, dynamic>> _get(String baseUrl, String operation, Map<String, String> params) async {
    if (!TagoConfig.isConfigured) {
      throw StateError('TAGO_API_KEY가 설정되지 않았습니다. secrets/dart_defines.json 참고.');
    }
    final uri = Uri.parse('$baseUrl/$operation').replace(queryParameters: {
      'serviceKey': TagoConfig.apiKey,
      '_type': 'json',
      ...params,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw TagoApiException('HTTP ${res.statusCode}', rawBody: res.body);
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      // data.go.kr은 서비스키가 잘못됐거나 오퍼레이션이 없으면 _type=json을
      // 무시하고 XML 에러를 돌려주는 경우가 있다 — 그대로 노출한다.
      throw TagoApiException('JSON 파싱 실패 (XML 에러 응답일 가능성) — rawBody 확인', rawBody: res.body);
    }

    final header = decoded['response']?['header'];
    final resultCode = header?['resultCode']?.toString();
    if (resultCode != null && resultCode != '00') {
      throw TagoApiException('TAGO 오류 ${resultCode}: ${header?['resultMsg']}', rawBody: res.body);
    }
    return decoded as Map<String, dynamic>;
  }

  /// items.item은 결과가 1건이면 Map, 여러 건이면 List로 오는 경우가 흔하다 — 둘 다 처리.
  static List<Map<String, dynamic>> _items(Map<String, dynamic> decoded) {
    final items = decoded['response']?['body']?['items'];
    if (items == null || items == '') return [];
    final item = items['item'];
    if (item == null) return [];
    if (item is List) return item.cast<Map<String, dynamic>>();
    return [item as Map<String, dynamic>];
  }

  /// 도시코드 목록 조회.
  static Future<List<TagoCity>> getCityCodes() async {
    final decoded = await _get(_stationBaseUrl, 'getCtyCodeList', {
      'pageNo': '1',
      'numOfRows': '100',
    });
    return _items(decoded).map(TagoCity.fromJson).toList();
  }

  /// 도시코드 + 노선번호로 노선 목록 검색.
  static Future<List<TagoRoute>> searchRoutesByNumber({
    required String cityCode,
    required String routeNo,
  }) async {
    final decoded = await _get(_routeBaseUrl, 'getRouteNoList', {
      'cityCode': cityCode,
      'routeNo': routeNo,
      'pageNo': '1',
      'numOfRows': '20',
    });
    return _items(decoded).map(TagoRoute.fromJson).toList();
  }

  /// 노선 ID로 경유 정류소(좌표 포함) 목록 조회.
  static Future<List<TagoRouteStop>> getRouteStops({
    required String cityCode,
    required String routeId,
  }) async {
    final decoded = await _get(_routeBaseUrl, 'getRouteAcctoThrghSttnList', {
      'cityCode': cityCode,
      'routeId': routeId,
      'pageNo': '1',
      'numOfRows': '100',
    });
    return _items(decoded).map(TagoRouteStop.fromJson).toList();
  }
}

class TagoApiException implements Exception {
  final String message;
  final String rawBody;

  TagoApiException(this.message, {required this.rawBody});

  @override
  String toString() => message;
}
