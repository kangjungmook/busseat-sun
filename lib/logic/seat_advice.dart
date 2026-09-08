import 'dart:math' as math;

import '../models/route.dart';
import '../theme/tokens.dart';
import 'geo.dart';
import 'sun_calc.dart';

/// 좌석 방향 판정 결과 — 앱의 전부.
class SeatAdvice {
  final bool leftSeat; // true면 왼쪽 창가 추천
  final int pct; // 46~95, 그늘(또는 볕) 비율
  final bool sunOnRight; // 태양이 진행 방향 오른쪽에 있나
  final double relative; // 진행 방향 기준 태양 상대 방위 0~360

  const SeatAdvice({
    required this.leftSeat,
    required this.pct,
    required this.sunOnRight,
    required this.relative,
  });

  String get sideLabel => leftSeat ? '왼쪽' : '오른쪽';

  /// 태양이 진행 방향 앞쪽이면 뒷열이 유리해진다.
  bool get sunAhead => math.cos(relative * math.pi / 180) > 0;
}

/// 한 구간이 추천 좌석에 어떤 영향을 주는지.
///
/// 예전에는 `under`(지하·터널)가 있었는데 **그 데이터가 없다.** 노선번호 해시로
/// `(i + hash) % 6 == 2`인 구간을 터널이라고 칠했을 뿐이라 삭제했다.
/// 건물 그림자도 마찬가지로 데이터가 없어서, 여기서 말하는 '그늘'은
/// **"태양이 반대쪽에 있어 그 창으로 직사광이 안 들어온다"**는 뜻이지
/// 건물에 가려진다는 뜻이 아니다.
enum SegKind {
  /// 추천 좌석 쪽에 직사광이 안 들어오는 구간.
  shade,

  /// 추천 좌석 쪽으로 해가 드는 구간.
  sun,

  /// 태양이 진행방향 앞·뒤라 좌우 차이가 거의 없거나, 고도가 낮아 일사가 약한 구간.
  weak,
}

/// 측면 일사가 이 값보다 약하면 좌우를 가릴 의미가 없다고 본다.
const double kWeakSideLoad = 0.15;

/// 노선의 한 토막 — 실제 좌표에서 뽑은 방위·거리와, 그때 태양이 어디 있었는지.
class RouteSegment {
  /// 이 구간의 진행 방위(도). 정류장 좌표로 실제 계산한 값.
  final double bearing;

  /// 구간 길이(m). 막대 폭과 가중 평균에 쓴다 — 예전의 고정 비율
  /// `[14, 22, 9, 26, 11, 18]`을 대체한다.
  final double meters;

  /// 진행방향 기준 태양 상대 방위 0~360.
  final double sunRelative;

  /// 그 시각의 일사 세기 0~1 (= sin 고도).
  final double intensity;

  const RouteSegment({
    required this.bearing,
    required this.meters,
    required this.sunRelative,
    required this.intensity,
  });

  bool get sunOnRight => sunRelative < 180;

  /// 측면 성분 — 태양이 정면/후면이면 0, 정측면이면 1.
  double get lateral => math.sin(sunRelative * math.pi / 180).abs();

  /// 창으로 실제로 들어오는 직사광 세기.
  double get sideLoad => intensity * lateral;

  /// [leftSeat]를 추천했을 때 이 구간이 그 좌석에 주는 영향.
  SegKind kindFor(bool leftSeat) {
    if (sideLoad < kWeakSideLoad) return SegKind.weak;
    return (sunOnRight == leftSeat) ? SegKind.shade : SegKind.sun;
  }
}

class SeatCalc {
  /// 좌석 방향 판정 — 이 함수가 앱의 전부.
  ///
  /// [segments]가 있으면 구간별 실제 방위를 거리로 가중해 판정하고, 좌표가 없어
  /// 비어 있으면 [fallbackBearing](기점→종점 직선) 하나로 예전처럼 판정한다.
  static SeatAdvice advise({
    required double fallbackBearing,
    required int minutes,
    required SunMode mode,
    required SunCalc sun,
    List<RouteSegment> segments = const [],
    double windowPct = 60,
  }) {
    final az = sun.azimuth(minutes);
    // 고도 자체가 아니라 일사 세기(sin 고도)를 쓴다 — 해가 낮게 뜨는 겨울엔
    // 창으로 들어오는 빛이 약해서, 같은 방위라도 좌석 차이가 줄어든다.
    final alt = sun.intensity(minutes);

    // 대표 방위: 구간이 있으면 거리로 가중한 실제 주행 방위, 없으면 직선.
    final rel = segments.isEmpty
        ? ((az - fallbackBearing) % 360 + 360) % 360
        : _weightedRelative(segments);

    final sunOnRight = rel < 180;
    final leftSeat = segments.isEmpty
        ? ((mode == SunMode.shade) ? sunOnRight : !sunOnRight)
        : preferLeftSeat(segments, mode);

    final sideStrength = (math.sin(rel * math.pi / 180)).abs();
    final base = 52 + 40 * (1 - alt * sideStrength);
    final raw = (mode == SunMode.shade) ? base : 148 - base;

    final pct = (raw * 0.55 + windowPct * 0.45).round().clamp(46, 95);

    return SeatAdvice(leftSeat: leftSeat, pct: pct, sunOnRight: sunOnRight, relative: rel);
  }

  /// 구간들의 상대 방위를 거리·일사로 가중한 대표값.
  /// 각도라서 산술 평균이 아니라 벡터 평균으로 더한다 (359°와 1°의 평균은 0°다).
  static double _weightedRelative(List<RouteSegment> segments) {
    var x = 0.0, y = 0.0;
    for (final s in segments) {
      final w = s.meters * (0.2 + s.intensity); // 밤 구간도 방위 정보는 남긴다
      x += math.cos(s.sunRelative * math.pi / 180) * w;
      y += math.sin(s.sunRelative * math.pi / 180) * w;
    }
    if (x == 0 && y == 0) return 0;
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// 승차→하차 구간을 실제 좌표로 잘라 [RouteSegment] 목록을 만든다.
  ///
  /// 예전에는 노선번호 해시로 만들어냈다:
  /// `(routeNo.codeUnitAt(0) * 7 + ...) % 5` — 노선이 어디로 가는지, 해가 어디
  /// 있는지와 아무 상관이 없는 값이었다. 지금은 TAGO가 준 정류장 좌표로
  /// 구간별 진행 방위와 거리를 구하고, 그 구간을 지날 시각의 태양 위치를 쓴다.
  ///
  /// 좌표가 없는 노선이면 **빈 목록**을 돌려준다 — 없는 데이터를 지어내느니
  /// 화면에서 "구간 정보 없음"이라고 말하는 게 맞다.
  ///
  /// [durationMin]은 TAGO가 주지 않아 정류장 수로 추정한 값이라, 구간별 통과
  /// 시각도 그만큼 근사다. 다만 한 노선을 지나는 동안 태양은 크게 움직이지
  /// 않아서(1시간에 약 15°) 좌우 판정이 뒤집힐 정도는 아니다.
  static List<RouteSegment> buildSegments({
    required RouteDir dir,
    required int boardIdx,
    required int alightIdx,
    required int startMinutes,
    required int durationMin,
    required SunCalc sun,
    int maxSegments = 6,
  }) {
    // 승차~하차 사이에서 양 끝 좌표가 다 있는 구간만 모은다.
    final legs = <({GeoPoint a, GeoPoint b, double meters})>[];
    for (var i = boardIdx; i < alightIdx && i + 1 < dir.stops.length; i++) {
      final a = dir.coordAt(i), b = dir.coordAt(i + 1);
      if (a == null || b == null) continue;
      final m = haversineMeters(lat1: a.lat, lng1: a.lng, lat2: b.lat, lng2: b.lng);
      if (m <= 0) continue;
      legs.add((a: a, b: b, meters: m));
    }
    if (legs.isEmpty) return const [];

    final totalMeters = legs.fold<double>(0, (t, l) => t + l.meters);
    final chunkCount = math.min(maxSegments, legs.length);
    final perChunk = (legs.length / chunkCount).ceil();

    final out = <RouteSegment>[];
    var travelled = 0.0;
    for (var c = 0; c < legs.length; c += perChunk) {
      final chunk = legs.sublist(c, math.min(c + perChunk, legs.length));
      final meters = chunk.fold<double>(0, (t, l) => t + l.meters);

      // 구간 양 끝을 잇는 방위 — 잔가지에 흔들리지 않는다.
      final bearing = initialBearing(
        lat1: chunk.first.a.lat,
        lng1: chunk.first.a.lng,
        lat2: chunk.last.b.lat,
        lng2: chunk.last.b.lng,
      );

      // 이 구간 중간 지점을 지날 무렵의 시각.
      final midFraction = totalMeters > 0 ? (travelled + meters / 2) / totalMeters : 0.0;
      final atMinutes = (startMinutes + durationMin * midFraction).round().clamp(0, 1439);
      final sample = sun.sampleAt(atMinutes);

      out.add(RouteSegment(
        bearing: bearing,
        meters: meters,
        sunRelative: ((sample.azimuthDeg - bearing) % 360 + 360) % 360,
        intensity: sample.intensity,
      ));
      travelled += meters;
    }
    return out;
  }

  /// 구간들을 거리로 가중해 왼쪽/오른쪽 중 어느 쪽이 더 오래 그늘인지 고른다.
  ///
  /// 예전에는 기점→종점 직선 방위 하나로 판정했다. 노선이 중간에 꺾이면
  /// 그 직선은 실제 주행 방향과 한참 다를 수 있는데, 이제는 구간마다 실제
  /// 방위를 보고 **거리로 투표**한다.
  static bool preferLeftSeat(List<RouteSegment> segments, SunMode mode) {
    var sunRightMeters = 0.0, sunLeftMeters = 0.0;
    for (final s in segments) {
      final w = s.meters * s.sideLoad; // 약한 구간은 자연스럽게 영향이 작아진다
      if (s.sunOnRight) {
        sunRightMeters += w;
      } else {
        sunLeftMeters += w;
      }
    }
    // 그늘 모드면 해가 많이 드는 반대쪽에 앉는다.
    final sunMostlyRight = sunRightMeters >= sunLeftMeters;
    return (mode == SunMode.shade) ? sunMostlyRight : !sunMostlyRight;
  }

  /// 추천 좌석이 목표 상태(그늘 모드면 그늘)로 유지되는 **거리 비율**.
  ///
  /// 예전에는 고정 비율 `[14, 22, 9, 26, 11, 18]`짜리 가짜 구간과 승하차 구간의
  /// 겹침을 계산했는데, 이제 구간 자체가 승차→하차 사이의 실제 거리라서
  /// 겹침을 따질 필요 없이 그대로 가중 평균하면 된다.
  ///
  /// 좌우 차이가 없는 구간(`weak`)은 "나쁘지 않다"는 뜻이라 절반만 쳐준다.
  static double windowPct(List<RouteSegment> segments, bool leftSeat) {
    if (segments.isEmpty) return 60;
    var total = 0.0, good = 0.0;
    for (final s in segments) {
      total += s.meters;
      switch (s.kindFor(leftSeat)) {
        case SegKind.shade:
          good += s.meters;
        case SegKind.weak:
          good += s.meters * 0.5;
        case SegKind.sun:
          break;
      }
    }
    return total > 0 ? (good / total * 100) : 60;
  }

  static const int rowCount = 6;

  /// 좌석별 그늘 점수 (좌석 지도 화면). 6열 × 4열(창-통로-통로-창).
  static int seatScore(int row, int col, SeatAdvice adv) {
    final isLeftSide = col < 2;
    final base = (isLeftSide == adv.leftSeat) ? adv.pct : (100 - adv.pct);
    final effRow = adv.sunAhead ? (rowCount - 1 - row) : row;
    final rowAdj = (effRow - 2.5) * 2.2;
    final isWindow = col == 0 || col == 3;
    final winAdj = base >= 50 ? (isWindow ? 4 : -3) : (isWindow ? -5 : 3);
    return (base + rowAdj + winAdj).round().clamp(5, 97);
  }

  /// 왼쪽/오른쪽 평균 그늘 비율 (좌석 지도 상단 비율 바).
  static (int left, int right) sideAverages(SeatAdvice adv) {
    final left = ((seatScore(2, 0, adv) + seatScore(3, 1, adv) + seatScore(1, 0, adv)) / 3).round();
    final right = ((seatScore(2, 3, adv) + seatScore(3, 2, adv) + seatScore(1, 3, adv)) / 3).round();
    return (left, right);
  }

  static ({int row, int col, int score}) bestSeat(SeatAdvice adv) {
    var bestScore = -1;
    var bestRow = 0, bestCol = 0;
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < 4; col++) {
        final sc = seatScore(row, col, adv);
        if (sc > bestScore) {
          bestScore = sc;
          bestRow = row;
          bestCol = col;
        }
      }
    }
    return (row: bestRow, col: bestCol, score: bestScore);
  }
}

/// 좌석 점수 4단계 색 매핑.
enum ShadeLevel { strong, mid, weak, direct }

ShadeLevel shadeLevelOf(int score) {
  if (score >= 76) return ShadeLevel.strong;
  if (score >= 58) return ShadeLevel.mid;
  if (score >= 40) return ShadeLevel.weak;
  return ShadeLevel.direct;
}
