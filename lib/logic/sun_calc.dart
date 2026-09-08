import 'solar.dart';

/// 특정 **날짜·장소**에서 본 태양. 화면과 좌석 판정이 공유하는 진입점이다.
///
/// 예전에는 전부 static이고 서울 9월 상수(일출 05:58 / 일몰 19:04, 방위각
/// 동→서 직선)가 박혀 있었다. 그러면 부산 12월 아침에도 같은 답이 나온다 —
/// 이 앱의 결론이 "왼쪽/오른쪽 창가" 하나뿐이라 방위각이 틀리면 답이 뒤집힌다.
/// 지금은 [solarPosition]으로 실제 계산한다.
class SunCalc {
  final double lat;
  final double lng;

  /// 계산 기준 날짜(로컬). 시각은 [minutes]로 따로 받는다 — 사용자가 지도
  /// 화면에서 탑승 시각 슬라이더를 움직이기 때문.
  final DateTime date;

  /// 로컬 표준시 오프셋. 한국은 +9시간.
  final Duration tzOffset;

  SunCalc({
    required this.lat,
    required this.lng,
    required this.date,
    required this.tzOffset,
  });

  /// 위치를 아직 못 받았을 때 쓰는 기준점 — 대전 부근(전국 중심).
  ///
  /// 서울을 기본값으로 두지 않는 이유: TAGO가 서울을 담당하지 않아서 이 앱이
  /// 서울에서 쓰일 일이 없는데, 서울 기준으로 계산하면 실제 사용 지역과 가장
  /// 먼 값을 기본으로 삼게 된다. 위도 1°는 태양 고도 1°에 해당해서, 남해안과
  /// 서울의 차이가 4° 넘는다.
  static const double fallbackLat = 36.35;
  static const double fallbackLng = 127.38;

  /// 한국 표준시.
  static const Duration kstOffset = Duration(hours: 9);

  SunSample sampleAt(int minutes) {
    final localMidnight = DateTime(date.year, date.month, date.day);
    final localTime = localMidnight.add(Duration(minutes: minutes));
    // DateTime.utc로 만든 뒤 오프셋을 빼야 기기 시간대와 무관하게 같은 값이 나온다.
    final utc = DateTime.utc(
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
    ).subtract(tzOffset);
    return solarPosition(utc: utc, latDeg: lat, lngDeg: lng);
  }

  late final ({int? sunriseMin, int? sunsetMin, int solarNoonMin}) _daylight = sunriseSunset(
    localDate: date,
    latDeg: lat,
    lngDeg: lng,
    tzOffset: tzOffset,
  );

  int get sunriseMin => _daylight.sunriseMin ?? 0;
  int get sunsetMin => _daylight.sunsetMin ?? 1439;

  /// 0(일출) ~ 1(일몰) 정규화된 낮 진행도. 구간 분류처럼 "하루 중 언제쯤"만
  /// 필요한 곳에서 쓴다.
  double dayProgress(int minutes) {
    final span = sunsetMin - sunriseMin;
    if (span <= 0) return 0;
    return ((minutes - sunriseMin) / span).clamp(0.0, 1.0);
  }

  /// 태양 방위각(도). 0=북, 시계방향 — 버스 진행 방위와 같은 기준.
  double azimuth(int minutes) => sampleAt(minutes).azimuthDeg;

  /// 태양 고도(도). 지평선 아래면 음수.
  double altitudeDeg(int minutes) => sampleAt(minutes).altitudeDeg;

  /// 일사 세기 계수 0~1 (= sin(고도)). 좌석 점수 계산이 쓰는 값.
  double intensity(int minutes) => sampleAt(minutes).intensity;

  /// 밤 판정 — 좌석 추천이 의미 없어지는 시각.
  /// 고도가 음수면 밤이다(시민박명 언저리는 낮으로 친다).
  bool isNight(int minutes) => altitudeDeg(minutes) <= 0;

  /// 16방위 한글 이름.
  String azimuthName(int minutes) => compassName(azimuth(minutes));

  /// 분 → 'HH:MM'. 태양과 무관한 순수 포맷이라 static으로 남긴다.
  static String timeLabel(int minutes) {
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
