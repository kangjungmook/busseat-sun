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
class TagoBusService {
  static const String _baseUrl = 'https://apis.data.go.kr/1613000/BusRouteInfoInqireService';

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
    if (res.statusCode != 200) {
      throw TagoApiException('HTTP ${res.statusCode}', rawBody: res.body);
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw TagoApiException('JSON 파싱 실패 (XML 에러 응답일 가능성) — rawBody 확인', rawBody: res.body);
    }

    // 서비스키 미등록/IP 미등록/활용기간 만료 등 공통 오류는 이 형식으로 온다
    // (문서 2-1절, 실제로도 확인됨):
    // {"OpenAPI_ServiceResponse":{"cmmMsgHeader":{"errMsg":..., "returnAuthMsg":..., "returnReasonCode":...}}}
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

  /// [도시코드 목록 조회] getCtyCodeList — 파라미터 없음.
  static Future<List<TagoCity>> getCityCodes() async {
    final decoded = await _get('getCtyCodeList', {});
    return _items(decoded).map(TagoCity.fromJson).toList();
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
  static Future<List<TagoRouteStop>> getRouteStops({
    required String cityCode,
    required String routeId,
  }) async {
    final decoded = await _get('getRouteAcctoThrghSttnList', {
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
