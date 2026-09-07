import '../logic/geo.dart';
import '../models/route.dart';
import '../models/tago.dart';
import 'tago_bus_service.dart';

/// TAGO API 응답을 앱이 쓰는 [BusRoute]/[RouteDir] 모양으로 조립한다.
///
/// ⚠️ 실기기에서 아직 끝까지 확인되지 않은 부분:
/// - 같은 routeId 안에서 상행/하행이 `updowncd`로 구분되는지, 아니면
///   방면별로 routeId 자체가 다른지는 API 문서 예제만으로는 100% 확정이
///   안 됐다. 아래 [_buildRoute]는 두 경우를 모두 처리하도록 짰다
///   (updowncd로 먼저 나누고, 그래도 방향이 하나뿐이면 routeId 자체가
///   그 방향 전용이라고 보고 그대로 쓴다).
/// - 소요시간(durationMin)은 TAGO가 안 준다 — 정류장 수 기반 추정치다.
class TagoRouteRepository {
  /// 노선번호로 전국을 검색해 [BusRoute] 하나로 조립한다. 못 찾으면 null.
  static Future<BusRoute?> search(String routeNo) async {
    final matches = await TagoBusService.findRouteNationwide(routeNo);
    if (matches.isEmpty) return null;

    // 같은 routeId가 여러 도시에서 중복으로 잡힐 수는 없지만(도시별로 관리되는
    // 값), 만약을 대비해 routeId 기준으로만 중복 제거한다.
    final seen = <String>{};
    final unique = <TagoRouteMatch>[];
    for (final m in matches) {
      if (seen.add(m.route.routeId)) unique.add(m);
    }

    final dirs = <RouteDir>[];
    String? routeType;
    for (final m in unique) {
      routeType ??= m.route.routeType;
      final stops = await TagoBusService.getRouteStops(cityCode: m.city.code, routeId: m.route.routeId);
      dirs.addAll(_toDirs(stops, fallbackFrom: m.route.startNodeName, fallbackTo: m.route.endNodeName));
    }
    if (dirs.isEmpty) return null;

    return BusRoute(
      no: routeNo,
      kind: routeType ?? '버스',
      durationMin: _estimateDuration(dirs),
      dirs: dirs,
    );
  }

  static List<RouteDir> _toDirs(
    List<TagoRouteStop> stops, {
    String? fallbackFrom,
    String? fallbackTo,
  }) {
    if (stops.isEmpty) return [];

    final byUpDown = <int, List<TagoRouteStop>>{};
    for (final s in stops) {
      final key = s.upDownCode ?? 0;
      byUpDown.putIfAbsent(key, () => []).add(s);
    }

    final dirs = <RouteDir>[];
    for (final group in byUpDown.values) {
      group.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      final withCoords = group.where((s) => s.lat != null && s.lng != null).toList();
      if (withCoords.isEmpty) continue;

      final first = withCoords.first;
      final last = withCoords.last;
      final bearing = withCoords.length >= 2 ? initialBearing(lat1: first.lat!, lng1: first.lng!, lat2: last.lat!, lng2: last.lng!) : 0.0;

      final names = group.map((s) => s.nodeName).where((n) => n.isNotEmpty).toList();
      final from = names.isNotEmpty ? names.first : (fallbackFrom ?? '');
      final to = names.isNotEmpty ? names.last : (fallbackTo ?? '');

      dirs.add(RouteDir(
        name: '$to 방면',
        from: from,
        to: to,
        bearing: bearing,
        stops: names, // 전체 실제 정류장 — stopPicker가 이 전체 목록을 쓴다.
        stopCount: names.length,
      ));
    }
    return dirs;
  }

  /// TAGO가 총 소요시간을 안 줘서, 정류장 수 기반으로 대충 추정한다
  /// (정류장당 평균 2~3분 가정). 실제 값이 아니라는 걸 UI 캡션에도 밝혀야 한다.
  static int _estimateDuration(List<RouteDir> dirs) {
    final maxStops = dirs.map((d) => d.stopCount).fold(0, (a, b) => a > b ? a : b);
    return (maxStops * 2.5).round().clamp(15, 180);
  }
}
