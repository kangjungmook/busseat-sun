import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';
import '../logic/geo.dart';
import '../models/tago.dart';
import 'tago_bus_service.dart' show TagoApiException;

/// 국토교통부 TAGO 정류소정보조회 서비스(BusSttnInfoInqireService) 클라이언트.
///
/// ⚠️ **상태: 미검증**. [TagoBusService](같은 폴더, BusRouteInfoInqireService)는
/// 사용자가 공유해준 공식 문서로 확정됐지만, 이 서비스(getCrdntPrxmtStaionList,
/// 좌표기반근접정류소목록조회)는 그 문서에 없다 — 일반적으로 널리 알려진
/// data.go.kr TAGO 정류소정보조회 API 스펙을 따랐을 뿐, 실제 호출로 확인하지
/// 못했다. `secrets/dart_defines.json`에 키를 채운 뒤, 실기기 없이도 아래
/// URL을 브라우저 주소창에 그대로 붙여넣어 `resultCode: "00"`이 오는지 먼저
/// 확인해달라 (serviceKey는 URL 인코딩된 값 그대로):
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
    if (res.statusCode != 200) {
      throw TagoApiException('HTTP ${res.statusCode}', rawBody: res.body);
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw TagoApiException('JSON 파싱 실패 (XML 에러 응답일 가능성) — rawBody 확인', rawBody: res.body);
    }

    final cmmHeader = decoded['OpenAPI_ServiceResponse']?['cmmMsgHeader'];
    if (cmmHeader != null) {
      throw TagoApiException(
        'TAGO 공통 오류(${cmmHeader['returnReasonCode']}): ${cmmHeader['returnAuthMsg']}',
        rawBody: res.body,
      );
    }

    final header = decoded['response']?['header'];
    final resultCode = header?['resultCode']?.toString();
    if (resultCode != null && resultCode != '00') {
      throw TagoApiException('TAGO 오류 $resultCode: ${header?['resultMsg']}', rawBody: res.body);
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
