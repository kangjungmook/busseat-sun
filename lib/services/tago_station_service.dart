import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';
import '../logic/geo.dart';
import '../models/tago.dart';
import 'tago_bus_service.dart' show TagoApiException, decodeTagoBody;

/// 국토교통부 TAGO 정류소정보조회 서비스(BusSttnInfoInqireService) 클라이언트.
///
/// ⚠️ **상태: 2026-09-09에 오퍼레이션 이름 오타를 고쳤다. 아직 실호출 미검증.**
///
/// 2026-09-07에 `NO_OPENAPI_SERVICE_ERROR`(returnReasonCode `12`)가 와서
/// "정류소정보 서비스를 별도로 활용신청하지 않아서"라고 적어뒀었는데, **틀린
/// 진단이었다.** 공식 활용가이드(v1.0)를 받아 대조해 보니 오퍼레이션 이름을
/// `getCrdntPrxmtStaionList`로 부르고 있었다 — 명세는
/// **`getCrdntPrxmtSttnList`**(Sttn, Staion 아님)다. 코드 12의 뜻도 그쪽에
/// 맞는다: "해당 오픈API서비스가 없거나 폐기됨". 활용신청이 안 됐다면
/// `SERVICE_ACCESS_DENIED_ERROR`(20)나 `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`(30)가
/// 왔을 것이다.
///
/// **반경 500m 제한**: 명세의 상세기능 설명이 "GPS좌표를 기반으로 근처(반경
/// 500m)에 있는 정류장을 검색한다"이다. 즉 500m 밖에서는 정상 응답에
/// `totalCount: 0`이 온다 — 오류가 아니다.
///
/// 이 오퍼레이션의 응답 항목은 `gpslati / gpslong / nodeid / nodenm / citycode`
/// 다섯 개다. 다른 오퍼레이션과 달리 **`nodeno`(정류소번호)가 없다** —
/// [TagoNearbyStation]은 이미 옵션으로 두고 있어서 그대로 동작한다.
///
/// 실호출로 확인하려면 아래를 브라우저에 붙여넣어 `resultCode: "00"`을 본다
/// (serviceKey는 **인코딩된** 값):
///
/// ```
/// https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList
///   ?serviceKey=<발급받은 키>&_type=json&gpsLati=36.3&gpsLong=127.3&numOfRows=5&pageNo=1
/// ```
///
/// (명세의 예제 좌표 36.3/127.3은 대전 근처이고, 예제 응답이 '성북3통' 정류소
/// 5건이므로 이 좌표로는 결과가 나와야 정상이다.)
///
/// 실패하면 홈 화면의 "가까운 정류장"은 [AppState] 쪽에서 **캐시된 노선의
/// 정류장 좌표**로 대신 계산한다 — 그쪽은 이미 검증된 버스노선정보 API
/// 데이터라 이 서비스와 무관하게 동작한다.
class TagoStationService {
  static const String _baseUrl = 'https://apis.data.go.kr/1613000/BusSttnInfoInqireService';

  /// [findNearby]가 던질 요청 URL. 오퍼레이션 이름과 파라미터 철자를 한 번
  /// 틀렸다가 이틀을 날렸기 때문에(`getCrdntPrxmtStaionList`), 테스트가 명세와
  /// 대조할 수 있도록 밖으로 빼뒀다.
  ///
  /// 주의할 비대칭: **요청은 `gpsLati`/`gpsLong`(대문자 L), 응답은
  /// `gpslati`/`gpslong`(전부 소문자)** 이다. 명세가 그렇게 되어 있다.
  static Uri nearbyUri({required double lat, required double lng, int numOfRows = 5}) =>
      Uri.parse('$_baseUrl/getCrdntPrxmtSttnList').replace(queryParameters: {
        'serviceKey': TagoConfig.apiKey,
        '_type': 'json',
        'gpsLati': lat.toString(),
        'gpsLong': lng.toString(),
        'pageNo': '1',
        'numOfRows': numOfRows.toString(),
      });

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
    final res = await http.get(nearbyUri(lat: lat, lng: lng, numOfRows: numOfRows));
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
      // 포털 공통 오류는 XML로만 오고, 그마저 JSON 요청에도 이 모양으로 온다.
      // 자주 보는 코드: 12(오퍼레이션 이름 오타 — 실제로 겪었다),
      // 20(접근거부), 22(요청제한 초과), 30(미등록 키), 31(활용기간 만료).
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
