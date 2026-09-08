import '../models/route.dart';
import '../theme/tokens.dart';
import 'seat_advice.dart';
import 'sun_calc.dart';

/// 특정 시각·모드·구간에서의 계산 결과 묶음.
/// result / seatMap / stopPicker / map / ar / today 화면이 공유해서 쓴다.
class SeatComputation {
  final BusRoute route;
  final int dirIndex;
  final RouteDir dir;
  final int minutes;
  final SunMode mode;
  final int boardIndex;
  final int alightIndex;
  final SunCalc sun;

  late final double azimuth = sun.azimuth(minutes);

  /// 태양 고도(도). 예전엔 0~1 계수였는데 실제 각도로 바뀌었다.
  late final double altitudeDeg = sun.altitudeDeg(minutes);

  /// 일사 세기 0~1 — 좌석 점수용.
  late final double intensity = sun.intensity(minutes);
  /// 승차→하차 구간을 실제 정류장 좌표로 자른 것. 좌표가 없으면 빈 목록.
  late final List<RouteSegment> routeSegments = SeatCalc.buildSegments(
    dir: dir,
    boardIdx: boardIndex,
    alightIdx: alightIndex,
    startMinutes: minutes,
    durationMin: route.durationMin,
    sun: sun,
  );

  /// 좌우 판정을 먼저 하고, 그 좌석 기준으로 구간을 분류한다 —
  /// '그늘'인지 '볕'인지는 어느 쪽에 앉느냐에 따라 뒤집히기 때문.
  late final SeatAdvice advice = SeatCalc.advise(
    fallbackBearing: dir.bearing,
    minutes: minutes,
    mode: mode,
    sun: sun,
    segments: routeSegments,
    windowPct: SeatCalc.windowPct(
      routeSegments,
      routeSegments.isEmpty ? true : SeatCalc.preferLeftSeat(routeSegments, mode),
    ),
  );

  late final List<SegKind> segments = [
    for (final s in routeSegments) s.kindFor(advice.leftSeat),
  ];

  /// 막대 폭에 쓸 실제 구간 거리(m).
  late final List<double> segmentMeters = [for (final s in routeSegments) s.meters];

  /// 구간 좌표가 없어 일사 분포를 못 그리는 노선인지.
  bool get hasSegmentData => routeSegments.isNotEmpty;

  SeatComputation._({
    required this.route,
    required this.dirIndex,
    required this.dir,
    required this.minutes,
    required this.mode,
    required this.boardIndex,
    required this.alightIndex,
    required this.sun,
  });

  factory SeatComputation.build({
    required BusRoute route,
    required int dirIndex,
    required int minutes,
    required SunMode mode,
    required SunCalc sun,
    int board = 0,
    int? alight,
  }) {
    final dir = route.dirs[dirIndex.clamp(0, route.dirs.length - 1)];
    final last = dir.stops.length - 1;
    final bIdx = board.clamp(0, last - 1 < 0 ? 0 : last - 1);
    final aIdx = alight == null ? last : alight.clamp(bIdx + 1, last);
    return SeatComputation._(
      route: route,
      dirIndex: dirIndex,
      dir: dir,
      minutes: minutes,
      mode: mode,
      boardIndex: bIdx,
      alightIndex: aIdx,
      sun: sun,
    );
  }

  String get boardName => dir.stops[boardIndex];
  String get alightName => dir.stops[alightIndex];
  String get spanLabel => '$boardName → $alightName';
  String get timeLabel => SunCalc.timeLabel(minutes);
  String get azimuthShort => '${azimuth.round()}°';
  String get azimuthLong => '${azimuth.round()}° ${sun.azimuthName(minutes)}';

  int get stopCount => dir.stopCount;
  int get durationMin => route.durationMin;

  /// "구간별 일사" 라벨 줄에 쓸 대표 정류장 이름 — 실제 정류장이 많을 수
  /// 있어(TAGO 연동 노선) 처음/중간 둘/끝, 최대 4개만 고르게 뽑는다.
  List<String> get sampledStopLabels {
    final stops = dir.stops;
    if (stops.length <= 4) return stops;
    final last = stops.length - 1;
    final idxs = {0, (last / 3).round(), (last * 2 / 3).round(), last}.toList()..sort();
    return idxs.map((i) => stops[i]).toList();
  }

  /// 지도용 근사 좌표 경로 (프로토타입의 M104 452L... 경로와 동일한 형태).
  static const List<String> mapPathSegments = [
    'M104 452L104 392Q104 380 120 376L170 366',
    'M170 366L198 360',
    'M198 360L198 268',
    'M198 268L198 196',
    'M198 196L198 150Q198 138 214 134L244 128',
    'M244 128L252 126',
  ];
}
