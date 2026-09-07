import 'dart:math' as math;

/// 두 좌표 사이의 초기 방위각(도, 0=북 시계방향) — 대권 방위각(initial bearing) 공식.
/// TAGO가 주는 정류소 좌표(WGS84)로 노선의 진행 방향을 근사할 때 쓴다.
double initialBearing({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final deltaLambda = (lng2 - lng1) * math.pi / 180;

  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
  final theta = math.atan2(y, x);
  return (theta * 180 / math.pi + 360) % 360;
}

const double _earthRadiusM = 6371000;

/// 두 좌표 사이 거리(미터) — 하버사인 공식. 근접 정류장 찾기(GPS ↔ 정류소
/// 좌표 비교)에 쓴다. TAGO 좌표 기반 API가 거리를 직접 안 줄 수도 있어서
/// 클라이언트에서 항상 다시 계산한다.
double haversineMeters({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) + math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusM * c;
}
