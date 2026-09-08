import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/logic/seat_advice.dart';
import 'package:sunseat/logic/sun_calc.dart';
import 'package:sunseat/models/route.dart';
import 'package:sunseat/theme/tokens.dart';

/// 구간별 일사 검증.
///
/// 예전 구현은 노선번호 해시(`routeNo.codeUnitAt(0) * 7 …`)로 구간을 칠했다.
/// 노선이 어디로 가는지, 해가 어디 있는지와 무관한 값이라 **노선 번호만 바꿔도
/// 결과가 달라지고, 노선을 정반대로 뒤집어도 결과가 그대로**였다.
/// 여기서는 그 두 가지가 이제 제대로 동작하는지를 본다.
const _kst = Duration(hours: 9);

/// 세종 근처에서 정확히 북쪽으로 뻗는 노선. 위도만 증가시킨다.
RouteDir _northbound({int stops = 7}) {
  const lat0 = 36.50, lng0 = 127.32;
  return RouteDir(
    name: '북쪽 방면',
    from: '출발',
    to: '도착',
    bearing: 0,
    stops: [for (var i = 0; i < stops; i++) '정류장$i'],
    stopCount: stops,
    stopCoords: [for (var i = 0; i < stops; i++) GeoPoint(lat: lat0 + i * 0.01, lng: lng0)],
  );
}

/// 같은 길을 정반대로 달리는 노선.
RouteDir _southbound({int stops = 7}) {
  const lat0 = 36.50, lng0 = 127.32;
  return RouteDir(
    name: '남쪽 방면',
    from: '출발',
    to: '도착',
    bearing: 180,
    stops: [for (var i = 0; i < stops; i++) '정류장$i'],
    stopCount: stops,
    stopCoords: [for (var i = 0; i < stops; i++) GeoPoint(lat: lat0 + (stops - 1 - i) * 0.01, lng: lng0)],
  );
}

/// 좌표가 하나도 없는 노선 (예: 좌표를 안 주는 도시).
RouteDir _noCoords({int stops = 5}) => RouteDir(
      name: '좌표 없음',
      from: '출발',
      to: '도착',
      bearing: 45,
      stops: [for (var i = 0; i < stops; i++) '정류장$i'],
      stopCount: stops,
    );

SunCalc _sunAt(DateTime d) => SunCalc(lat: 36.50, lng: 127.32, date: d, tzOffset: _kst);

List<RouteSegment> _segs(RouteDir dir, int minutes, {DateTime? date}) => SeatCalc.buildSegments(
      dir: dir,
      boardIdx: 0,
      alightIdx: dir.stops.length - 1,
      startMinutes: minutes,
      durationMin: 40,
      sun: _sunAt(date ?? DateTime(2026, 9, 8)),
    );

void main() {
  group('구간은 실제 좌표에서 나온다', () {
    test('북행 노선의 구간 방위는 모두 북쪽(0°)에 가깝다', () {
      for (final s in _segs(_northbound(), 540)) {
        expect(s.bearing % 360, closeTo(0, 1.0));
      }
    });

    test('남행 노선은 180°', () {
      for (final s in _segs(_southbound(), 540)) {
        expect(s.bearing, closeTo(180, 1.0));
      }
    });

    test('구간 거리 합이 전체 노선 길이와 맞는다 (0.01° ≈ 1.11km × 6구간)', () {
      final total = _segs(_northbound(), 540).fold<double>(0, (t, s) => t + s.meters);
      expect(total, closeTo(6 * 1113, 60));
    });

    test('좌표가 없으면 빈 목록 — 지어내지 않는다', () {
      expect(_segs(_noCoords(), 540), isEmpty);
    });
  });

  group('진행 방향을 뒤집으면 태양이 반대쪽에 온다', () {
    test('아침 북행에서 해가 오른쪽이면, 같은 시각 남행에서는 왼쪽', () {
      const morning = 540; // 09:00, 해는 동쪽(≈100°)
      final north = _segs(_northbound(), morning);
      final south = _segs(_southbound(), morning);
      expect(north.first.sunOnRight, isTrue, reason: '북쪽으로 달리면 동쪽 해는 오른쪽');
      expect(south.first.sunOnRight, isFalse, reason: '남쪽으로 달리면 동쪽 해는 왼쪽');
    });

    test('그늘 모드 추천 좌석도 함께 뒤집힌다', () {
      const morning = 540;
      expect(SeatCalc.preferLeftSeat(_segs(_northbound(), morning), SunMode.shade), isTrue);
      expect(SeatCalc.preferLeftSeat(_segs(_southbound(), morning), SunMode.shade), isFalse);
    });
  });

  group('시간대에 따라 바뀐다', () {
    test('북행 노선: 아침엔 해가 오른쪽(동), 오후엔 왼쪽(서)', () {
      expect(_segs(_northbound(), 540).first.sunOnRight, isTrue);
      expect(_segs(_northbound(), 1020).first.sunOnRight, isFalse); // 17:00
    });

    test('밤에는 일사 세기가 0이라 좌우를 가리지 않는다', () {
      final night = _segs(_northbound(), 60); // 01:00
      expect(night.every((s) => s.intensity == 0), isTrue);
      expect(night.every((s) => s.kindFor(true) == SegKind.weak), isTrue);
    });
  });

  group('꺾이는 노선은 구간마다 방위가 달라진다', () {
    test('북쪽으로 갔다가 동쪽으로 꺾이면 구간 방위가 0°대와 90°대로 갈린다', () {
      // 예전 해시 방식은 노선 모양을 아예 안 봤기 때문에, 직선이든 ㄱ자든
      // 같은 번호면 같은 결과가 나왔다.
      const lat0 = 36.50, lng0 = 127.32;
      final lShaped = RouteDir(
        name: 'ㄱ자',
        from: '출발',
        to: '도착',
        bearing: 45,
        stops: [for (var i = 0; i < 7; i++) '정류장\$i'],
        stopCount: 7,
        stopCoords: [
          // 북쪽으로 3구간
          for (var i = 0; i < 4; i++) GeoPoint(lat: lat0 + i * 0.01, lng: lng0),
          // 이후 동쪽으로 3구간
          for (var i = 1; i <= 3; i++) GeoPoint(lat: lat0 + 0.03, lng: lng0 + i * 0.01),
        ],
      );
      final segs = _segs(lShaped, 540);
      final bearings = segs.map((s) => s.bearing).toList();
      expect(bearings.any((b) => (b % 360) < 10 || (b % 360) > 350), isTrue, reason: '북쪽 구간');
      expect(bearings.any((b) => (b - 90).abs() < 10), isTrue, reason: '동쪽 구간');
    });
  });

  group('windowPct — 추천 좌석이 그늘인 거리 비율', () {
    test('해가 정측면인 직선 노선에서 추천 좌석은 대부분 그늘', () {
      final segs = _segs(_northbound(), 540);
      final left = SeatCalc.preferLeftSeat(segs, SunMode.shade);
      expect(SeatCalc.windowPct(segs, left), greaterThan(70));
    });

    test('반대쪽에 앉으면 같은 노선에서 값이 낮아진다', () {
      final segs = _segs(_northbound(), 540);
      final left = SeatCalc.preferLeftSeat(segs, SunMode.shade);
      expect(SeatCalc.windowPct(segs, !left), lessThan(SeatCalc.windowPct(segs, left)));
    });

    test('구간이 없으면 중립값 60', () {
      expect(SeatCalc.windowPct(const [], true), 60);
    });
  });
}
