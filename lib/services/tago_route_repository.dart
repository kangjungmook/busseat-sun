import '../logic/geo.dart';
import '../models/route.dart';
import '../models/tago.dart';
import 'kakao_local_service.dart';
import 'location_service.dart';
import 'tago_bus_service.dart';
import 'tago_city_resolver.dart';

/// 검색 범위가 어디까지 넓어졌는지 — UI 안내와 로그용.
enum SearchScope { city, province, nationwide }

/// TAGO API 응답을 앱이 쓰는 [BusRoute]/[RouteDir] 모양으로 조립한다.
///
/// 방면 구분: **routeId 자체가 방향별로 다르게 온다** (2026-09-07 실제 응답으로
/// 확인 — 세종 `B7`이 `SJB271000805` 집현동→비하종점 / `SJB271000806` 반대방향
/// 두 건으로 잡히고, 정류소 응답에 `updowncd`는 아예 없었다). [_toDirs]는
/// `updowncd`가 오는 경우에도 그 안에서 한 번 더 나누므로 양쪽 다 커버한다.
///
/// 소요시간(durationMin)은 TAGO가 안 준다 — 정류장 수 기반 추정치다.

/// [TagoRouteRepository.search]의 결과.
///
/// "노선을 못 찾음"과 "그 지역을 TAGO가 담당하지 않음"은 사용자에게 완전히 다른
/// 이야기라 구분한다 — 전자는 번호를 다시 확인하라는 뜻이고, 후자는 번호를
/// 백 번 고쳐 넣어도 안 된다는 뜻이다 (서울이 대표적).
class RouteSearchResult {
  final BusRoute? route;

  /// 위치는 알아냈는데 그 지역을 담당하는 TAGO 도시가 하나도 없을 때의 지역명.
  /// (예: '세종특별자치시'. 서울이라면 '서울특별시')
  final String? unsupportedRegion;

  const RouteSearchResult({this.route, this.unsupportedRegion});
}

class TagoRouteRepository {
  /// 노선번호로 [BusRoute]를 조립한다.
  ///
  /// **호출 수를 아끼려고 범위를 단계적으로 넓힌다.** TAGO는 cityCode가 필수라
  /// 도시를 모르면 전국(150~250개 도시)을 훑어야 하는데, 그러면 검색 한 번에
  /// API가 200번 나가서 일일 한도(개발계정 보통 1,000건)가 몇 번 만에 소진된다.
  ///
  /// 1. [near]가 있으면 카카오 로컬 API로 좌표 → 행정구역 → 도시코드 (API 1~2회)
  /// 2. 그 도시에 없으면 **같은 도(道) 전체** (경기 기준 40개 안팎)
  ///    — 광역버스는 옆 시에 등록돼 있을 수 있어서 이 단계가 필요하다
  /// 3. 그래도 없고 [allowNationwide]면 전국 (마지막 수단)
  ///
  /// 위치를 못 얻었거나 카카오 키가 없으면 곧바로 3번으로 간다.
  ///
  /// **지역을 알아냈는데 담당 도시가 없으면 전국 검색을 하지 않고** 곧바로
  /// [RouteSearchResult.unsupportedRegion]을 돌려준다. 그런 지역(서울)에서는
  /// 전국을 다 훑어도 그 지역 버스가 나올 리 없는데, 그 헛수고 한 번이 API를
  /// 200번 쓴다 — 서울 사용자가 검색할 때마다 한도가 날아가는 걸 막는다.
  static Future<RouteSearchResult> search(
    String routeNo, {
    LocationResult? near,
    bool allowNationwide = true,
    void Function(SearchScope scope, int done, int total)? onProgress,
  }) async {
    final cities = await TagoBusService.getCityCodes();
    var matches = <TagoRouteMatch>[];

    TagoCity? primary;
    if (near != null) {
      KakaoRegion? region;
      try {
        region = await KakaoLocalService.regionForCoord(lat: near.lat, lng: near.lon);
      } catch (_) {
        region = null; // 좌표→지역 실패는 치명적이지 않다 — 아래에서 넓게 찾는다.
      }
      if (region != null) {
        final candidates = TagoCityResolver.candidatesFor(region, cities);
        if (candidates.isEmpty) {
          // 광역시·특별시는 이름 자체가 TAGO의 도시라, 못 찾았으면 정말
          // 담당하지 않는 지역이다(서울) → 헛되이 전국을 훑지 않고 바로 알린다.
          if (TagoCityResolver.sidoIsSingleCity(region.sido)) {
            return RouteSearchResult(unsupportedRegion: region.toString());
          }
          // 도 지역은 이름 표기가 어긋났을 뿐일 수 있다. 여기서 미지원이라고
          // 단정하면 멀쩡히 되는 지역이 영영 막히므로, 아래 넓은 검색에 맡긴다.
        } else {
          primary = candidates.first;
          matches = await TagoBusService.findRouteInCities(
            routeNo,
            candidates,
            onProgress: (d, t) => onProgress?.call(SearchScope.city, d, t),
          );
        }
      }
    }

    if (matches.isEmpty && primary != null) {
      final siblings = TagoCityResolver.provinceSiblings(primary, cities);
      if (siblings.isNotEmpty) {
        matches = await TagoBusService.findRouteInCities(
          routeNo,
          siblings,
          onProgress: (d, t) => onProgress?.call(SearchScope.province, d, t),
        );
      }
    }

    if (matches.isEmpty && allowNationwide) {
      matches = await TagoBusService.findRouteInCities(
        routeNo,
        cities,
        onProgress: (d, t) => onProgress?.call(SearchScope.nationwide, d, t),
      );
    }

    if (matches.isEmpty) return const RouteSearchResult();

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
    if (dirs.isEmpty) return const RouteSearchResult();

    return RouteSearchResult(
      route: BusRoute(
        no: routeNo,
        kind: routeType ?? '버스',
        durationMin: _estimateDuration(dirs),
        dirs: dirs,
      ),
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

      final named = group.where((s) => s.nodeName.isNotEmpty).toList();
      final names = named.map((s) => s.nodeName).toList();
      final coords = named.map((s) => s.lat != null && s.lng != null ? GeoPoint(lat: s.lat!, lng: s.lng!) : null).toList();
      final from = names.isNotEmpty ? names.first : (fallbackFrom ?? '');
      final to = names.isNotEmpty ? names.last : (fallbackTo ?? '');

      dirs.add(RouteDir(
        name: '$to 방면',
        from: from,
        to: to,
        bearing: bearing,
        stops: names, // 전체 실제 정류장 — stopPicker가 이 전체 목록을 쓴다.
        stopCount: names.length,
        stopCoords: coords, // stops[i]와 인덱스가 맞아야 한다 (좌표 없으면 null).
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
