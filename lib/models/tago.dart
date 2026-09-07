/// TAGO 응답을 관대하게 파싱하기 위한 헬퍼 — 필드명이 문서마다 조금씩 다르게
/// 표기되는 경우가 있어 후보 키를 여러 개 시도한다.
String? _pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().isNotEmpty) return v.toString();
  }
  return null;
}

double? _pickDouble(Map<String, dynamic> m, List<String> keys) {
  final s = _pick(m, keys);
  if (s == null) return null;
  return double.tryParse(s);
}

/// 도시코드 목록 조회(getCtyCodeList) 결과 1건.
class TagoCity {
  final String code;
  final String name;

  const TagoCity({required this.code, required this.name});

  factory TagoCity.fromJson(Map<String, dynamic> json) {
    return TagoCity(
      code: _pick(json, ['citycode', 'cityCode']) ?? '',
      name: _pick(json, ['cityname', 'citynm', 'cityName']) ?? '',
    );
  }
}

/// 노선번호 목록 조회(getRouteNoList) 결과 1건.
///
/// ⚠️ routeno/routetp/startnodenm/endnodenm 필드명은 이 세션이 실제로 호출해
/// 확인한 게 아니라, 같은 TAGO 계열 API들의 공통 명명 규칙(정류소 API의
/// nodenm/nodeno 처럼 약어+ nm/no 접미사)을 따른다는 전제로 추정한 것이다.
class TagoRoute {
  final String routeId;
  final String routeNo;
  final String? routeType;
  final String? startNodeName;
  final String? endNodeName;
  final Map<String, dynamic> raw;

  const TagoRoute({
    required this.routeId,
    required this.routeNo,
    this.routeType,
    this.startNodeName,
    this.endNodeName,
    required this.raw,
  });

  factory TagoRoute.fromJson(Map<String, dynamic> json) {
    return TagoRoute(
      routeId: _pick(json, ['routeid', 'routeId']) ?? '',
      routeNo: _pick(json, ['routeno', 'routeNo']) ?? '',
      routeType: _pick(json, ['routetp', 'routeTp', 'routeType']),
      startNodeName: _pick(json, ['startnodenm', 'startNodeNm']),
      endNodeName: _pick(json, ['endnodenm', 'endNodeNm']),
      raw: json,
    );
  }
}

/// 노선별 경유 정류소 목록 조회(getRouteAcctoThrghSttnList) 결과 1건.
/// citycode/gpslati/gpslong/nodeid/nodenm/nodeno 는 웹 검색으로 확인됨.
/// nodeord(경유 순번)/updowncd(상하행)는 같은 계열 API의 통상적인 필드명을
/// 반영한 추정치라 실제 응답에서 다를 수 있다.
class TagoRouteStop {
  final String nodeId;
  final String nodeName;
  final String? nodeNo;
  final double? lat;
  final double? lng;
  final int? order;
  final Map<String, dynamic> raw;

  const TagoRouteStop({
    required this.nodeId,
    required this.nodeName,
    this.nodeNo,
    this.lat,
    this.lng,
    this.order,
    required this.raw,
  });

  factory TagoRouteStop.fromJson(Map<String, dynamic> json) {
    final orderStr = _pick(json, ['nodeord', 'nodeOrd']);
    return TagoRouteStop(
      nodeId: _pick(json, ['nodeid', 'nodeId']) ?? '',
      nodeName: _pick(json, ['nodenm', 'nodeNm']) ?? '',
      nodeNo: _pick(json, ['nodeno', 'nodeNo']),
      lat: _pickDouble(json, ['gpslati', 'gpsLati']),
      lng: _pickDouble(json, ['gpslong', 'gpsLong']),
      order: orderStr == null ? null : int.tryParse(orderStr),
      raw: json,
    );
  }
}
