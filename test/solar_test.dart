import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/logic/solar.dart';
import 'package:sunseat/logic/sun_calc.dart';

/// 태양 계산 검증.
///
/// 이 앱이 내놓는 답은 "왼쪽/오른쪽 창가" 하나뿐이고, 그 답은 전적으로 태양
/// 방위각에서 나온다. 방위각이 틀리면 답이 **반대로** 나오는데 화면상으로는
/// 똑같이 그럴듯해 보인다 — 그래서 눈으로는 못 잡고 여기서 잡아야 한다.
///
/// 기준값은 천문학적으로 확정된 성질들이다(특정 사이트 수치를 베낀 게 아니라,
/// 검증 가능한 물리적 사실):
/// - 춘·추분에는 위도와 무관하게 태양이 정동에서 떠 정서로 진다
/// - 북반구 중위도에서 태양은 남중(정오에 방위 180°)한다
/// - 하지는 북동에서 떠 북서로, 동지는 남동에서 떠 남서로 진다
/// - 남중고도 = 90° − 위도 + 적위 (하지 +23.44°, 동지 −23.44°)
const _seoulLat = 37.5665, _seoulLng = 126.9780;
const _kst = Duration(hours: 9);

SunCalc _sun(DateTime date, {double lat = _seoulLat, double lng = _seoulLng}) =>
    SunCalc(lat: lat, lng: lng, date: date, tzOffset: _kst);

void main() {
  group('남중 — 정오 무렵 태양은 정남(180°)에 온다', () {
    test('서울 하지', () {
      final s = _sun(DateTime(2026, 6, 21));
      final az = s.azimuth(s._solarNoonForTest);
      expect(az, closeTo(180, 1.0));
    });

    test('서울 동지', () {
      final s = _sun(DateTime(2026, 12, 21));
      expect(s.azimuth(s._solarNoonForTest), closeTo(180, 1.0));
    });
  });

  group('남중고도 = 90° − 위도 + 적위', () {
    test('서울 하지는 약 76°', () {
      final s = _sun(DateTime(2026, 6, 21));
      // 90 - 37.5665 + 23.44 = 75.87
      expect(s.altitudeDeg(s._solarNoonForTest), closeTo(75.87, 0.5));
    });

    test('서울 동지는 약 29°', () {
      final s = _sun(DateTime(2026, 12, 21));
      // 90 - 37.5665 - 23.44 = 28.99
      expect(s.altitudeDeg(s._solarNoonForTest), closeTo(28.99, 0.5));
    });

    test('제주가 서울보다 남중고도가 높다 (위도가 낮으므로)', () {
      final seoul = _sun(DateTime(2026, 9, 8));
      final jeju = _sun(DateTime(2026, 9, 8), lat: 33.4996, lng: 126.5312);
      expect(jeju.altitudeDeg(jeju._solarNoonForTest),
          greaterThan(seoul.altitudeDeg(seoul._solarNoonForTest)));
    });
  });

  group('계절에 따라 뜨고 지는 방위가 달라진다 — 옛 선형 근사가 놓치던 부분', () {
    test('춘분에는 거의 정동(90°)에서 뜬다', () {
      final s = _sun(DateTime(2026, 3, 20));
      expect(s.azimuth(s.sunriseMin + 5), closeTo(90, 3.0));
    });

    test('하지에는 북동쪽에서 뜬다 (방위 90° 미만)', () {
      final s = _sun(DateTime(2026, 6, 21));
      expect(s.azimuth(s.sunriseMin + 5), lessThan(65));
    });

    test('동지에는 남동쪽에서 뜬다 (방위 90° 초과)', () {
      final s = _sun(DateTime(2026, 12, 21));
      expect(s.azimuth(s.sunriseMin + 5), greaterThan(115));
    });

    test('하지와 동지의 일출 방위 차이가 55° 이상 — 옛 코드는 늘 90°였다', () {
      final summer = _sun(DateTime(2026, 6, 21));
      final winter = _sun(DateTime(2026, 12, 21));
      final diff = (winter.azimuth(winter.sunriseMin + 5) - summer.azimuth(summer.sunriseMin + 5)).abs();
      expect(diff, greaterThan(55));
    });
  });

  group('일출·일몰 — 더 이상 상수가 아니다', () {
    test('하지가 동지보다 낮이 훨씬 길다 (서울 기준 4시간 이상)', () {
      final summer = _sun(DateTime(2026, 6, 21));
      final winter = _sun(DateTime(2026, 12, 21));
      final summerDay = summer.sunsetMin - summer.sunriseMin;
      final winterDay = winter.sunsetMin - winter.sunriseMin;
      expect(summerDay - winterDay, greaterThan(240));
    });

    test('같은 날이라도 위도가 다르면 낮 길이가 다르다', () {
      final seoul = _sun(DateTime(2026, 6, 21));
      final jeju = _sun(DateTime(2026, 6, 21), lat: 33.4996, lng: 126.5312);
      expect(seoul.sunsetMin - seoul.sunriseMin, greaterThan(jeju.sunsetMin - jeju.sunriseMin));
    });

    test('경도가 동쪽일수록 해가 일찍 뜬다 (부산 vs 인천)', () {
      final busan = _sun(DateTime(2026, 9, 8), lat: 35.1796, lng: 129.0756);
      final incheon = _sun(DateTime(2026, 9, 8), lat: 37.4563, lng: 126.7052);
      expect(busan.sunriseMin, lessThan(incheon.sunriseMin));
    });
  });

  group('밤 판정', () {
    test('한밤중은 밤, 정오는 낮', () {
      final s = _sun(DateTime(2026, 9, 8));
      expect(s.isNight(0), isTrue);
      expect(s.isNight(720), isFalse);
    });
  });

  group('compassName — 16방위', () {
    test('주요 방위', () {
      expect(compassName(0), '북');
      expect(compassName(90), '동');
      expect(compassName(180), '남');
      expect(compassName(270), '서');
      expect(compassName(135), '남동');
      expect(compassName(360), '북'); // 한 바퀴
    });
  });
}

/// 테스트 편의용 — 그날의 남중 시각(분).
extension on SunCalc {
  int get _solarNoonForTest => ((sunriseMin + sunsetMin) / 2).round();
}
