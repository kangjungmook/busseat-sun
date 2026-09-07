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

  late final double azimuth = SunCalc.azimuth(minutes);
  late final double altitude = SunCalc.altitude(minutes);
  late final List<SegKind> segments = SeatCalc.segments(route.no, dirIndex, minutes, mode);
  late final double windowPctValue = SeatCalc.windowPct(segments, boardIndex, alightIndex, dir.stops.length - 1, mode);
  late final SeatAdvice advice = SeatCalc.advise(
    busBearing: dir.bearing,
    minutes: minutes,
    mode: mode,
    windowPct: windowPctValue,
  );

  SeatComputation._({
    required this.route,
    required this.dirIndex,
    required this.dir,
    required this.minutes,
    required this.mode,
    required this.boardIndex,
    required this.alightIndex,
  });

  factory SeatComputation.build({
    required BusRoute route,
    required int dirIndex,
    required int minutes,
    required SunMode mode,
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
    );
  }

  String get boardName => dir.stops[boardIndex];
  String get alightName => dir.stops[alightIndex];
  String get spanLabel => '$boardName → $alightName';
  String get timeLabel => SunCalc.timeLabel(minutes);
  String get azimuthShort => '${azimuth.round()}°';
  String get azimuthLong => '${azimuth.round()}° ${SunCalc.azimuthName(minutes)}';

  int get stopCount => dir.stopCount;
  int get durationMin => route.durationMin;

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
