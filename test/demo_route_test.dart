import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/services/demo_route_service.dart';

/// 예시 노선 검증.
///
/// 이 에셋은 2026-09-15에 `getRouteAcctoThrghSttnList`를 실제로 호출해 받은
/// 응답 원문이다(세종 cityCode 12 / routeId SJB271000805, B7 집현동→비하종점).
/// 여기서 보는 건 두 가지다: 검색 경로와 **같은 조립 코드**를 타는가, 그리고
/// 좌표가 살아 있어서 **좌석 계산이 실제로 가능한가**. 좌표가 빠지면 화면은
/// 멀쩡한데 구간 막대만 조용히 사라진다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('에셋이 실제 노선으로 조립된다', () async {
    final route = await DemoRouteService.load();
    expect(route, isNotNull);
    expect(route!.no, 'B7');
    expect(route.dirs, hasLength(1), reason: 'routeId 하나짜리 응답이라 방면도 하나');
  });

  test('정류장 39개가 순서대로, 좌표와 함께 들어온다', () async {
    final dir = (await DemoRouteService.load())!.dirs.first;
    expect(dir.stops, hasLength(39));
    expect(dir.from, '집현동');
    expect(dir.to, '비하종점');
    expect(dir.stopCoords, hasLength(dir.stops.length),
        reason: 'stops와 stopCoords는 인덱스가 맞아야 한다');
    expect(dir.stopCoords.every((c) => c != null), isTrue,
        reason: '좌표가 하나라도 비면 구간 계산이 조용히 빠진다');
  });

  test('진행 방위가 실제 좌표에서 나온다 — 세종에서 청주는 북동쪽', () async {
    // 집현동(36.498, 127.323) → 비하종점(36.643, 127.422): 북쪽으로 약 16km,
    // 동쪽으로 약 9km. 방위는 대략 30° 안팎이어야 한다.
    final dir = (await DemoRouteService.load())!.dirs.first;
    expect(dir.bearing, greaterThan(10));
    expect(dir.bearing, lessThan(60));
  });

  test('두 번 불러도 같은 인스턴스 — 에셋을 매번 다시 읽지 않는다', () async {
    expect(identical(await DemoRouteService.load(), await DemoRouteService.load()), isTrue);
  });
}
