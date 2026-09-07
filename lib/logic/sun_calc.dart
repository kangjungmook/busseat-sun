import 'dart:math' as math;

/// 태양 위치 근사 계산. 서울 9월 기준 일출 05:58(358분) / 일몰 19:04(1144분).
/// 프로토타입은 선형 근사식을 쓴다 — 프로덕션에선 SPA(Solar Position Algorithm)로 교체.
class SunCalc {
  static const int sunriseMin = 358;
  static const int sunsetMin = 1144;

  /// 0(일출) ~ 1(일몰) 정규화된 낮 진행도.
  static double dayProgress(int minutes) => ((minutes - sunriseMin) / (sunsetMin - sunriseMin)).clamp(0.0, 1.0);

  /// 태양 고도 계수 0~1 (정오에 1). 실제 각도는 altitude * 62°.
  static double altitude(int minutes) {
    final d = dayProgress(minutes);
    return math.max(0, math.sin(math.pi * d));
  }

  /// 태양 방위각 (도). 동(90°) → 서(270°) 선형 근사.
  static double azimuth(int minutes) => 90 + dayProgress(minutes) * 180;

  /// 밤 판정 — 좌석 추천 불가 화면으로 분기.
  static bool isNight(int minutes) => minutes < 390 || minutes > 1140;

  static const List<String> _dirs8 = ['동', '동남동', '남동', '남남동', '남', '남남서', '남서', '서남서', '서'];

  static String azimuthName(int minutes) {
    final d = dayProgress(minutes);
    final idx = (d * 8).round().clamp(0, 8);
    return _dirs8[idx];
  }

  static String timeLabel(int minutes) {
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
