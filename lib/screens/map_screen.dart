import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/kakao_js_config.dart';
import '../logic/computation.dart';
import '../logic/seat_advice.dart';
import '../logic/sun_calc.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/route_map_painter.dart';

class MapScreen extends StatelessWidget {
  final AppPalette palette;

  const MapScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    final dir = state.currentDir;
    if (route == null || dir == null) return const SizedBox.shrink();

    final comp = SeatComputation.build(route: route, dirIndex: state.dirIndex, minutes: state.minutes, mode: state.effectiveMode, sun: state.sun, board: state.boardIndex, alight: state.alightIndex);
    final adv = comp.advice;

    // 실제 정류장 좌표(TAGO)가 있고 카카오맵 JS 키가 설정된 경우에만 실제 지도로
    // 바꾼다. 둘 중 하나라도 없으면 기존 도로 그리드 플레이스홀더로 대체한다
    // (README "지도 SDK" 절 참고).
    //
    // 웹에서는 항상 플레이스홀더다 — `webview_flutter`가 웹을 지원하지 않아서
    // [KakaoMapView]를 만들면 터진다. 웹은 UI 미리보기 전용이라(README 참고)
    // 여기서 막아두면 키가 채워져 있어도 안전하다.
    final mapStops = dir.mappableStops;
    final useRealMap = !kIsWeb && KakaoJsConfig.isConfigured && mapStops.isNotEmpty;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth, h = constraints.maxHeight;
              Offset frac(double x, double y) => Offset(x / 390 * w, y / 790 * h);
              final originC = frac(90 + 15, 438 + 15);
              final destC = frac(240 + 14, 112 + 14);
              final locC = frac(182 + 17, 282 + 17);

              return Stack(
                children: [
                  ...useRealMap
                      ? [
                          Positioned.fill(
                            child: KakaoMapView(
                              key: ValueKey('${route.no}-${state.dirIndex}'),
                              lat: mapStops[mapStops.length ~/ 2].point.lat,
                              lng: mapStops[mapStops.length ~/ 2].point.lng,
                              level: 6,
                              stops: [for (final s in mapStops) MapStop(name: s.name, lat: s.point.lat, lng: s.point.lng)],
                            ),
                          ),
                        ]
                      : [
                          Positioned.fill(child: CustomPaint(painter: RouteMapPainter(palette: palette, segments: comp.segments))),
                          Positioned(
                            left: originC.dx - 15,
                            top: originC.dy - 15,
                            child: Container(width: 30, height: 30, decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle, boxShadow: [palette.cardShadow]), child: const Icon(Icons.directions_bus, color: Colors.white, size: 16)),
                          ),
                          Positioned(left: originC.dx - 40, top: originC.dy + 20, child: _MapLabel(text: dir.from, palette: palette)),
                          Positioned(
                            left: destC.dx - 14,
                            top: destC.dy - 14,
                            child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: kLocationBlue, shape: BoxShape.circle), child: const Icon(Icons.location_on, color: Colors.white, size: 15)),
                          ),
                          Positioned(left: destC.dx + 6, top: destC.dy - 2, child: _MapLabel(text: dir.to, palette: palette)),
                          Positioned(
                            left: locC.dx - 17,
                            top: locC.dy - 17,
                            child: SizedBox(width: 34, height: 34, child: Center(child: _PulseDot())),
                          ),
                        ],
                  Positioned(
                    right: 14,
                    top: 74,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(999), boxShadow: [palette.cardShadow]),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_outlined, size: 17, color: palette.sunDiscColor),
                          const SizedBox(width: 6),
                          Text(comp.azimuthLong, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: palette.text)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(20), boxShadow: [palette.cardShadow]),
                      child: Row(
                        children: [
                          DirectionArrow(pointLeft: adv.leftSeat, color: palette.primaryText, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${adv.sideLabel} 창가', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -.4, color: palette.text)),
                                Text(
                                  '${state.effectiveMode == SunMode.shade ? '이동 중 ' : '이동 중 '}${adv.pct}${state.effectiveMode == SunMode.shade ? '% 그늘 유지' : '% 볕 좋음'}',
                                  style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w700, color: palette.primaryText),
                                ),
                              ],
                            ),
                          ),
                          IconCircleButton(icon: const Icon(Icons.close, size: 15), color: palette.textMuted, onTap: () => state.goto(AppScreen.result)),
                        ],
                      ),
                    ),
                  ),
                  if (state.guiding)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 18,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 260),
                        builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(20), boxShadow: [palette.cardShadow, palette.cardShadow]),
                          child: Row(
                            children: [
                              _LivePulse(color: palette.primaryText),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('안내 중 · ${route.no}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .2, color: palette.primaryText)),
                                    Text('${adv.sideLabel} 창가 · ${adv.pct}%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text)),
                                  ],
                                ),
                              ),
                              Text('3분 후 도착', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
                              const SizedBox(width: 6),
                              IconCircleButton(icon: const Icon(Icons.close, size: 15), color: palette.textMuted, onTap: state.stopGuide),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            transformAlignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..scale(1.0, state.guiding ? 0.94 : 1.0),
            constraints: BoxConstraints(maxHeight: state.guiding ? 0 : 280),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 320),
              opacity: state.guiding ? 0 : 1,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: _MapSheet(palette: palette, state: state, comp: comp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _MapLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: palette.surfaceColor.withOpacity(.92), borderRadius: BorderRadius.circular(7), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: Text(text, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: palette.text)),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final scale = 1 + _c.value * 1.6;
        final opacity = (.45 * (1 - _c.value)).clamp(0.0, .45);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(scale: scale, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: kLocationBlue.withOpacity(opacity), shape: BoxShape.circle))),
            Container(width: 14, height: 14, decoration: BoxDecoration(color: kLocationBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)])),
          ],
        );
      },
    );
  }
}

class _LivePulse extends StatefulWidget {
  final Color color;

  const _LivePulse({required this.color});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .4, end: 1.0).animate(_c),
      child: Container(width: 9, height: 9, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _MapSheet extends StatelessWidget {
  final AppPalette palette;
  final AppState state;
  final SeatComputation comp;

  const _MapSheet({required this.palette, required this.state, required this.comp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        border: Border(top: BorderSide(color: palette.line)),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Material(
                color: palette.subtle,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: state.resetToNow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('지금', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, fontWeight: FontWeight.w800, color: palette.text)),
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                  child: Slider(value: state.minutes.toDouble(), min: 300, max: 1200, activeColor: palette.primary, inactiveColor: palette.subtle, onChanged: (v) => state.setMinutes(v.round())),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('탑승 시각', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10, fontWeight: FontWeight.w700, color: palette.textMuted)),
                  Text(SunCalc.timeLabel(state.minutes), style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < comp.segments.length; i++)
                Expanded(
                  // 실제 구간 거리에 비례 (10m 단위, 최소 1)
                  flex: i < comp.segmentMeters.length ? math.max(1, (comp.segmentMeters[i] / 10).round()) : 1,
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: i < comp.segments.length - 1 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: comp.segments[i] == SegKind.shade
                          ? palette.primary
                          : (comp.segments[i] == SegKind.sun ? palette.sunDiscColor : palette.surface.grey),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlineButton(text: '결과 카드', onTap: () => state.goto(AppScreen.result), palette: palette, height: 52)),
              const SizedBox(width: 8),
              Expanded(child: SolidButton(text: '안내 시작', onTap: state.startGuide, palette: palette, height: 52)),
            ],
          ),
        ],
      ),
    );
  }
}
