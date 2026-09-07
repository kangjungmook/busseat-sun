import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/tago_config.dart';

/// 국토교통부 TAGO 버스노선정보 API 클라이언트.
///
/// ⚠️ 미검증: 이 파일의 엔드포인트 경로·파라미터명·응답 구조는 확정된 것이 아니다.
/// 이 세션은 인터넷에서 data.go.kr의 실제 API 명세(활용신청 상세 페이지의
/// "OpenAPI 개발가이드" PDF/문서)를 조회할 수 없어서, 공공데이터포털 버스 계열
/// API들이 공통으로 쓰는 일반적인 패턴(서비스키 + pageNo/numOfRows + XML/JSON
/// 응답의 response.body.items.item 구조)만 반영해 뼈대만 만들어뒀다.
///
/// 실제로 쓰려면 발급받은 "국토교통부_(TAGO)_버스노선정보" 활용신청 상세 페이지의
/// API 문서를 보고 아래를 맞춰야 한다:
/// - 실제 base URL / operation 경로 (예: /BusRouteInfoInqireService/... 형태로 추정되나 미확인)
/// - 노선번호 검색, 노선 상세(경유 정류소) 조회 등 각 오퍼레이션의 파라미터명
/// - 응답이 XML인지 JSON인지 (data.go.kr은 기본 XML이고 `_type=json` 등으로 JSON 요청 가능한 경우가 많음)
class TagoBusService {
  // TODO: 실제 base URL로 교체 (data.go.kr API 문서 참고).
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
      throw HttpException('TAGO API 오류: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 노선번호로 노선 목록 검색. (엔드포인트/파라미터명 미검증 — TODO)
  static Future<Map<String, dynamic>> searchRoutesByNumber(String routeNo, {int pageNo = 1, int numOfRows = 10}) {
    return _get('getRouteNoList', {
      'routeNo': routeNo,
      'pageNo': '$pageNo',
      'numOfRows': '$numOfRows',
    });
  }
}

class HttpException implements Exception {
  final String message;

  HttpException(this.message);

  @override
  String toString() => message;
}
