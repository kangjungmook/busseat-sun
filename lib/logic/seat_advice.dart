import 'dart:math' as math;

import '../theme/tokens.dart';
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

enum SegKind { shade, sun, under }

/// 구간 길이 비율 (6분할).
const List<int> kSegWeights = [14, 22, 9, 26, 11, 18];

class SeatCalc {
  /// 좌석 방향 판정 — 이 함수가 앱의 전부.
  static SeatAdvice advise({
    required double busBearing,
    required int minutes,
    required SunMode mode,
    double windowPct = 60,
  }) {
    final az = SunCalc.azimuth(minutes);
    final alt = SunCalc.altitude(minutes);

    final rel = ((az - busBearing) % 360 + 360) % 360;
    final sunOnRight = rel < 180;
    final leftSeat = (mode == SunMode.shade) ? sunOnRight : !sunOnRight;

    final sideStrength = (math.sin(rel * math.pi / 180)).abs();
    final base = 52 + 40 * (1 - alt * sideStrength);
    final raw = (mode == SunMode.shade) ? base : 148 - base;

    final pct = (raw * 0.55 + windowPct * 0.45).round().clamp(46, 95);

    return SeatAdvice(leftSeat: leftSeat, pct: pct, sunOnRight: sunOnRight, relative: rel);
  }

  /// 노선을 6개 구간으로 나눠 shade/sun/under로 분류.
  /// 노선번호 해시로 결정론적 생성 — 프로덕션에선 건물 그림자 데이터로 교체.
  static List<SegKind> segments(String routeNo, int dirIndex, int minutes, SunMode mode) {
    final hash = (routeNo.codeUnitAt(0) * 7 + routeNo.length * 13 + dirIndex * 29) % 5;
    final d = SunCalc.dayProgress(minutes);
    return List.generate(6, (i) {
      if ((i + hash) % 6 == 2) return SegKind.under;
      final good = ((i * 3 + hash + (d * 4).round()) % 5) != 0;
      final target = (mode == SunMode.shade) ? SegKind.shade : SegKind.sun;
      final other = (mode == SunMode.shade) ? SegKind.sun : SegKind.shade;
      return good ? target : other;
    });
  }

  /// 구간 지정(승차→하차)이 있을 때의 windowPct 계산 — 지정 구간과 겹치는 세그먼트만 가중 평균.
  static double windowPct(
    List<SegKind> kinds,
    int boardIdx,
    int alightIdx,
    int lastIdx,
    SunMode mode,
  ) {
    final winA = boardIdx / lastIdx * 100;
    final winB = alightIdx / lastIdx * 100;
    final total = kSegWeights.reduce((a, b) => a + b);
    final target = (mode == SunMode.shade) ? SegKind.shade : SegKind.sun;
    double cum = 0, hit = 0, span = 0;
    for (var i = 0; i < 6; i++) {
      final a = cum / total * 100, b = (cum + kSegWeights[i]) / total * 100;
      cum += kSegWeights[i];
      final overlap = math.max(0, math.min(b, winB) - math.max(a, winA));
      span += overlap;
      if (kinds[i] == target) hit += overlap;
    }
    return span > 0 ? hit / span * 100 : 60;
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
