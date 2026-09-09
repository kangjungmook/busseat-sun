/// 태양 위치 계산 — NOAA Solar Calculator 알고리즘.
///
/// 이전 구현은 "서울 9월"에 맞춘 선형 근사식이었다. 일출·일몰이 상수였고
/// 방위각은 동(90°)에서 서(270°)로 직선 보간이었는데, 실제 태양은 여름엔
/// 북동에서 떠 북서로 지고 겨울엔 남동→남서로 움직인다. 이 앱의 결론이
/// "어느 쪽 창가"라서, 방위각이 틀리면 답이 **반대로** 나온다.
///
/// 여기 있는 것은 전부 순수 함수다 — 네트워크도 상태도 없다.
/// 정확도는 태양 위치 약 ±0.5°, 일출·일몰 약 ±1분 수준으로, 좌석 판정에는
/// 충분히 남는다.
library;

import 'dart:math' as math;

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// 율리우스 세기 — 알고리즘 전체가 이 값을 기준으로 돈다.
/// (J2000.0 = 2451545.0 으로부터 36525일 단위)
double _julianCentury(DateTime utc) {
  var y = utc.year;
  var m = utc.month;
  final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  final jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b - 1524.5;
  return (jd - 2451545.0) / 36525.0;
}

/// 하루 중 태양의 적위(declination)와 균시차(equation of time).
/// 두 값 모두 하루 안에서는 매우 천천히 변해서, 위치 계산과 일출·일몰 계산이
/// 같은 함수를 공유한다.
({double declDeg, double eqTimeMin}) _solarParams(double t) {
  final l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);

  final c = math.sin(_rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      math.sin(_rad(2 * m)) * (0.019993 - 0.000101 * t) +
      math.sin(_rad(3 * m)) * 0.000289;

  final trueLong = l0 + c;
  final appLong = trueLong - 0.00569 - 0.00478 * math.sin(_rad(125.04 - 1934.136 * t));

  final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
  final eps = eps0 + 0.00256 * math.cos(_rad(125.04 - 1934.136 * t));

  final declDeg = _deg(math.asin(math.sin(_rad(eps)) * math.sin(_rad(appLong))));

  final y = math.tan(_rad(eps / 2)) * math.tan(_rad(eps / 2));
  final eqTime = 4 *
      _deg(y * math.sin(2 * _rad(l0)) -
          2 * e * math.sin(_rad(m)) +
          4 * e * y * math.sin(_rad(m)) * math.cos(2 * _rad(l0)) -
          0.5 * y * y * math.sin(4 * _rad(l0)) -
          1.25 * e * e * math.sin(2 * _rad(m)));

  return (declDeg: declDeg, eqTimeMin: eqTime);
}

/// 관측 지점에서 본 태양의 방위·고도.
class SunSample {
  /// 방위각(도). 0=북, 시계방향(동=90, 남=180, 서=270).
  /// 버스 진행 방위(`RouteDir.bearing`)와 같은 기준이라 바로 뺄 수 있다.
  final double azimuthDeg;

  /// 지평선 위 고도(도). 밤에는 음수.
  final double altitudeDeg;

  const SunSample({required this.azimuthDeg, required this.altitudeDeg});

  /// 일사 세기 계수 0~1 (= sin(고도), 지평선 아래면 0).
  /// 지면에 닿는 복사량이 입사각의 sin에 비례한다는 성질을 그대로 쓴다 —
  /// 예전의 `sin(π · 낮진행도)`와 달리 계절·위도가 반영된다.
  double get intensity => altitudeDeg <= 0 ? 0 : math.sin(_rad(altitudeDeg)).clamp(0.0, 1.0);
}

/// [utc] 시점에 위도 [latDeg]/경도 [lngDeg]에서 본 태양의 위치.
SunSample solarPosition({
  required DateTime utc,
  required double latDeg,
  required double lngDeg,
}) {
  final t = _julianCentury(utc);
  final p = _solarParams(t);

  // 진태양시(분) — 관측지 경도와 균시차로 보정한 하루 중 시각.
  final utcMinutes = utc.hour * 60 + utc.minute + utc.second / 60;
  final trueSolarTime = (utcMinutes + p.eqTimeMin + 4 * lngDeg) % 1440;
  final hourAngle = trueSolarTime / 4 - 180;

  final latR = _rad(latDeg);
  final declR = _rad(p.declDeg);
  final haR = _rad(hourAngle);

  final cosZenith =
      (math.sin(latR) * math.sin(declR) + math.cos(latR) * math.cos(declR) * math.cos(haR)).clamp(-1.0, 1.0);
  final zenith = math.acos(cosZenith);
  final altitude = 90 - _deg(zenith);

  double azimuth;
  final denom = math.cos(latR) * math.sin(zenith);
  if (denom.abs() > 0.000001) {
    final ratio = ((math.sin(latR) * cosZenith - math.sin(declR)) / denom).clamp(-1.0, 1.0);
    azimuth = 180 - _deg(math.acos(ratio));
    if (hourAngle > 0) azimuth = -azimuth;
  } else {
    // 태양이 천정 근처 — 방위가 정의되지 않는다. 극지방 예외 처리.
    azimuth = latDeg > 0 ? 180 : 0;
  }
  return SunSample(azimuthDeg: (azimuth + 360) % 360, altitudeDeg: altitude);
}

/// 그 날짜의 일출·일몰 시각 (자정부터의 분).
///
/// 백야·극야처럼 해가 뜨거나 지지 않는 날은 null이다 — 한국에서는 안 생기지만,
/// 계산식이 정의되지 않는 구간이라 호출하는 쪽이 처리할 수 있게 남겨둔다.
({int? sunriseMin, int? sunsetMin, int solarNoonMin}) sunriseSunset({
  required DateTime localDate,
  required double latDeg,
  required double lngDeg,
  required Duration tzOffset,
}) {
  // 그날 정오(UTC 환산)를 기준으로 적위·균시차를 구한다.
  final noonUtc = DateTime.utc(localDate.year, localDate.month, localDate.day, 12).subtract(tzOffset);
  final p = _solarParams(_julianCentury(noonUtc));

  final tzMin = tzOffset.inMinutes;
  final solarNoon = 720 - 4 * lngDeg - p.eqTimeMin + tzMin;

  // 90.833° = 태양 원반의 반지름과 대기 굴절을 감안한 일출·일몰 천정각.
  final latR = _rad(latDeg);
  final declR = _rad(p.declDeg);
  final cosHa = math.cos(_rad(90.833)) / (math.cos(latR) * math.cos(declR)) - math.tan(latR) * math.tan(declR);
  if (cosHa < -1 || cosHa > 1) {
    return (sunriseMin: null, sunsetMin: null, solarNoonMin: solarNoon.round());
  }
  final ha = _deg(math.acos(cosHa));
  return (
    sunriseMin: (solarNoon - 4 * ha).round(),
    sunsetMin: (solarNoon + 4 * ha).round(),
    solarNoonMin: solarNoon.round(),
  );
}

const List<String> _compass16 = [
  '북', '북북동', '북동', '동북동',
  '동', '동남동', '남동', '남남동',
  '남', '남남서', '남서', '서남서',
  '서', '서북서', '북서', '북북서',
];

/// 방위각(도)을 16방위 한글 이름으로. 0=북, 90=동.
String compassName(double azimuthDeg) {
  final idx = ((azimuthDeg % 360) / 22.5).round() % 16;
  return _compass16[idx];
}
