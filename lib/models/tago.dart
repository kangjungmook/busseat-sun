/// TAGO 응답 모델. 필드명은 "오픈API활용가이드_국토교통부(TAGO)_버스노선정보v1.0"
/// 공식 문서(2026-09-07 확인)를 그대로 반영한다 — 더 이상 추정이 아니다.
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

int? _pickInt(Map<String, dynamic> m, List<String> keys) {
  final s = _pick(m, keys);
  if (s == null) return null;
  return int.tryParse(s);
}

/// [도시코드 목록 조회] getCtyCodeList 결과 1건.
class TagoCity {
  final String code; // citycode
  final String name; // cityname

  const TagoCity({required this.code, required this.name});

  factory TagoCity.fromJson(Map<String, dynamic> json) {
    return TagoCity(
      code: _pick(json, ['citycode']) ?? '',
      name: _pick(json, ['cityname']) ?? '',
    );
  }
}

/// [노선번호목록 조회] getRouteNoList / [노선정보항목 조회] getRouteInfoIem 공통 필드.
class TagoRoute {
  final String routeId; // routeid
  final String routeNo; // routeno
  final String? routeType; // routetp — 예: '마을버스', '직행좌석버스'
  final String? startNodeName; // startnodenm — 기점
  final String? endNodeName; // endnodenm — 종점
  final String? startVehicleTime; // startvehicletime — 첫차 HHMM
  final String? endVehicleTime; // endvehicletime — 막차 HHMM
  /// getRouteInfoIem에서만 오는 배차간격(분). getRouteNoList엔 없다.
  final int? intervalWeekday; // intervaltime
  final int? intervalSaturday; // intervalsattime
  final int? intervalSunday; // intervalsuntime
  final Map<String, dynamic> raw;

  const TagoRoute({
    required this.routeId,
    required this.routeNo,
    this.routeType,
    this.startNodeName,
    this.endNodeName,
    this.startVehicleTime,
    this.endVehicleTime,
    this.intervalWeekday,
    this.intervalSaturday,
    this.intervalSunday,
    required this.raw,
  });

  factory TagoRoute.fromJson(Map<String, dynamic> json) {
    return TagoRoute(
      routeId: _pick(json, ['routeid']) ?? '',
      routeNo: _pick(json, ['routeno']) ?? '',
      routeType: _pick(json, ['routetp']),
      startNodeName: _pick(json, ['startnodenm']),
      endNodeName: _pick(json, ['endnodenm']),
      startVehicleTime: _pick(json, ['startvehicletime']),
      endVehicleTime: _pick(json, ['endvehicletime']),
      intervalWeekday: _pickInt(json, ['intervaltime']),
      intervalSaturday: _pickInt(json, ['intervalsattime']),
      intervalSunday: _pickInt(json, ['intervalsuntime']),
      raw: json,
    );
  }
}

/// [노선별경유정류소목록 조회] getRouteAcctoThrghSttnList 결과 1건.
class TagoRouteStop {
  final String routeId; // routeid
  final String nodeId; // nodeid — 정류소ID
  final String nodeName; // nodenm — 정류소명
  final String? nodeNo; // nodeno — 정류소번호 (옵션)
  final int? order; // nodeord — 경유 순번
  final double? lat; // gpslati — WGS84 위도
  final double? lng; // gpslong — WGS84 경도
  final int? upDownCode; // updowncd — 0:상행, 1:하행 (옵션)
  final Map<String, dynamic> raw;

  const TagoRouteStop({
    required this.routeId,
    required this.nodeId,
    required this.nodeName,
    this.nodeNo,
    this.order,
    this.lat,
    this.lng,
    this.upDownCode,
    required this.raw,
  });

  factory TagoRouteStop.fromJson(Map<String, dynamic> json) {
    return TagoRouteStop(
      routeId: _pick(json, ['routeid']) ?? '',
      nodeId: _pick(json, ['nodeid']) ?? '',
      nodeName: _pick(json, ['nodenm']) ?? '',
      nodeNo: _pick(json, ['nodeno']),
      order: _pickInt(json, ['nodeord']),
      lat: _pickDouble(json, ['gpslati']),
      lng: _pickDouble(json, ['gpslong']),
      upDownCode: _pickInt(json, ['updowncd']),
      raw: json,
    );
  }
}
