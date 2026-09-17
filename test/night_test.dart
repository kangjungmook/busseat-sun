import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/logic/computation.dart';
import 'package:sunseat/logic/sun_calc.dart';
import 'package:sunseat/services/demo_route_service.dart';
import 'package:sunseat/theme/tokens.dart';

/// 밤 판정.
///
/// 해가 지면 좌우 어느 쪽도 직사광을 받지 않으므로 추천할 것이 없다. 그런데
/// [SeatAdvice.pct]는 하한이 46이라 **"차이 없음"을 표현할 수가 없고**, 늘
/// 한쪽과 46~95 사이 숫자를 내놓는다. 실제로 12월 19시에 "왼쪽 창가 · 73%"가
/// 나왔다 — 고도 −19.7°, 일사 0인 시각이다.
///
/// 그래서 화면은 [SeatComputation.isNight]를 보고 숫자 대신 사실을 말한다.
/// 여기서 고정하는 건 그 판정이 제대로 서는가다.
SunCalc _sun(DateTime d) =>
    SunCalc(lat: 36.5, lng: 127.3, date: d, tzOffset: SunCalc.kstOffset);

Future<SeatComputation> _comp(DateTime date, int minutes) async {
  final route = (await DemoRouteService.load())!;
  return SeatComputation.build(
    route: route,
    dirIndex: 0,
    minutes: minutes,
    mode: SunMode.shade,
    sun: _sun(date),
    board: 0,
    alight: route.dirs.first.stops.length - 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('12월 19시는 밤 — 예전에는 여기서 "왼쪽 73%"가 나왔다', () async {
    final c = await _comp(DateTime(2026, 12, 21), 19 * 60);
    expect(c.isNight, isTrue);
    expect(c.intensity, 0);
  });

  test('12월 이른 아침(06:00)도 밤 — 그때 일출은 07:40 무렵이다', () async {
    expect((await _comp(DateTime(2026, 12, 21), 6 * 60)).isNight, isTrue);
  });

  test('6월 19시는 아직 낮 — 계절을 안 보면 이걸 밤으로 잘라낸다', () async {
    expect((await _comp(DateTime(2026, 6, 21), 19 * 60)).isNight, isFalse);
  });

  test('한낮은 당연히 낮', () async {
    expect((await _comp(DateTime(2026, 9, 15), 13 * 60)).isNight, isFalse);
  });

  group('슬라이더가 움직일 수 있는 범위는 그날의 실제 낮', () {
    test('12월은 일몰이 18시 이전 — 고정 20:00 이던 시절엔 밤까지 갔다', () {
      final s = _sun(DateTime(2026, 12, 21));
      expect(s.sunsetMin, lessThan(18 * 60));
      expect(s.sunriseMin, greaterThan(7 * 60));
    });

    test('6월은 훨씬 넓다', () {
      final s = _sun(DateTime(2026, 6, 21));
      expect(s.sunsetMin, greaterThan(19 * 60));
    });

    test('"낮 기준으로 보기"는 그날 남중 — 하드코딩 16:12보다 해가 훨씬 높다', () {
      for (final d in [DateTime(2026, 12, 21), DateTime(2026, 6, 21)]) {
        final s = _sun(d);
        expect(s.solarNoonMin, greaterThan(s.sunriseMin));
        expect(s.solarNoonMin, lessThan(s.sunsetMin));
      }
      // 16:12는 12월에도 밤은 아니다(일몰 17:19). 다만 그때 고도가 10.2°로
      // 남중 30.1°의 3분의 1이라, 밤을 피해 누른 버튼치고는 최악에 가깝다.
      final winter = _sun(DateTime(2026, 12, 21));
      expect(winter.altitudeDeg(972), lessThan(15));
      expect(winter.altitudeDeg(winter.solarNoonMin), greaterThan(25));
    });
  });
}
