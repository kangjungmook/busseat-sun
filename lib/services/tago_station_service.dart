import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';
import '../logic/geo.dart';
import '../models/tago.dart';
import 'tago_bus_service.dart' show TagoApiException, decodeTagoBody;

/// 국토교통부 TAGO 정류소정보조회 서비스(BusSttnInfoInqireService) 클라이언트.
///
/// ⚠️ **상태: 현재 이 프로젝트의 키로는 동작하지 않는다.** 2026-09-07에 실제로
/// 브라우저에서 호출해본 결과, 사용자의 서비스키로는
/// `NO_OPENAPI_SERVICE_ERROR`(returnReasonCode `12`)가 돌아왔다.
/// 공공데이터포털에서 신청한 것이 "국토교통부(TAGO)_**버스노선정보**"뿐이라
/// **정류소정보 서비스는 별도로 활용신청**을 해야 하기 때문으로 보인다.
/// (같은 키로 BusRouteInfoInqireService의 getCtyCodeList는 `resultCode: "00"`
/// 정상 응답 — 즉 키 자체는 멀쩡하다.)
///
/// 그래서 홈 화면의 "가까운 정류장"은 이 서비스가 실패하면
/// [AppState] 쪽에서 **캐시된 노선의 정류장 좌표**로 대신 계산한다 — 그쪽은
/// 이미 검증된 버스노선정보 API 데이터라 추가 신청이 필요 없다.
///
/// 활용신청을 한 뒤 다시 쓰려면, 먼저 아래 URL을 브라우저에 붙여넣어
/// `resultCode: "00"`이 오는지 확인하면 된다 (serviceKey는 **인코딩된** 값):
///
/// ```
/// https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtStaionList
///   ?serviceKey=<발급받은 키>&_type=json&gpsLati=37.498&gpsLong=127.028&numOfRows=5&pageNo=1
/// ```
///
/// 응답 필드명이 다르면(예: gpsLati/gpsLong 대소문자, citycode 유무) [TagoNearbyStation.fromJson]만
/// 고치면 된다 — 나머지 파이프라인(정렬/거리 계산)은 그대로 재사용 가능하다.
class TagoStationService {
  static const String _baseUrl = 'https://apis.data.go.kr/1613000/BusSttnInfoInqireService';

  /// 좌표 [lat]/[lng] 근처 정류소를 거리순으로 최대 [numOfRows]개 돌려준다.
  /// API가 이미 근접순으로 줄 가능성이 높지만, 확실하지 않으니 받은 뒤에도
  /// 클라이언트에서 하버사인으로 다시 정렬한다.
  static Future<List<TagoNearbyStation>> findNearby({
    required double lat,
    required double lng,
    int numOfRows = 5,
  }) async {
    if (!TagoConfig.isConfigured) {
      throw StateError('TAGO_API_KEY가 설정되지 않았습니다. secrets/dart_defines.json 참고.');
    }
    final uri = Uri.parse('$_baseUrl/getCrdntPrxmtStaionList').replace(queryParameters: {
      'serviceKey': TagoConfig.apiKey,
      '_type': 'json',
      'gpsLati': lat.toString(),
      'gpsLong': lng.toString(),
      'pageNo': '1',
      'numOfRows': numOfRows.toString(),
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

    final cmmHeader = decoded['OpenAPI_ServiceResponse']?['cmmMsgHeader'];
    if (cmmHeader != null) {
      // 활용신청을 안 한 서비스면 여기로 온다 (returnReasonCode "12",
      // NO_OPENAPI_SERVICE_ERROR) — 2026-09-07 실제 호출로 확인됨.
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

    final items = decoded['response']?['body']?['items'];
    if (items == null || items == '') return [];
    final rawItem = items['item'];
    if (rawItem == null) return [];
    final list = (rawItem is List ? rawItem : [rawItem]).cast<Map<String, dynamic>>();

    final stations = list.map(TagoNearbyStation.fromJson).whereType<TagoNearbyStation>().toList();
    stations.sort((a, b) {
      final da = haversineMeters(lat1: lat, lng1: lng, lat2: a.lat, lng2: a.lng);
      final db = haversineMeters(lat1: lat, lng1: lng, lat2: b.lat, lng2: b.lng);
      return da.compareTo(db);
    });
    return stations;
  }
}
