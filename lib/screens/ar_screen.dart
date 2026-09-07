import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../logic/computation.dart';
import '../logic/seat_advice.dart';
import '../logic/sun_calc.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/city_silhouette_painter.dart';
import '../widgets/common.dart';

/// AR 태양 엿보기. 실제 나침반(flutter_compass) + 카메라 프리뷰(camera) 사용.
/// 센서/카메라를 쓸 수 없는 환경(시뮬레이터, 권한 거부)에서는 드래그로 방위를
/// 시뮬레이션하는 프로토타입 방식으로 자동 대체된다.
class ArScreen extends StatefulWidget {
  final AppPalette palette;

  const ArScreen({super.key, required this.palette});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  CameraController? _camera;
  StreamSubscription<CompassEvent>? _compassSub;
  double? _sensorHeading;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initCompass();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() => _camera = controller);
    } catch (_) {
      // 카메라를 쓸 수 없으면 하늘/건물 실루엣 배경으로 대체한다.
    }
  }

  void _initCompass() {
    if (FlutterCompass.events == null) return;
    _compassSub = FlutterCompass.events!.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _sensorHeading = event.heading);
      }
    });
  }

  double? get _heading {
    final state = context.read<AppState>();
    if (state.arHeadingOverride != null) return state.arHeadingOverride;
    if (_sensorHeading != null) return _sensorHeading! + _dragOffset;
    return null;
  }

  @override
  void dispose() {
    _camera?.dispose();
    _compassSub?.cancel();
    super.dispose();
  }

  double _normalize(double d) {
    var x = ((d % 360) + 360) % 360;
    if (x > 180) x -= 360;
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    final dir = state.currentDir;
    if (route == null || dir == null) return const SizedBox.shrink();

    final comp = SeatComputation.build(route: route, dirIndex: state.dirIndex, minutes: state.minutes, mode: state.effectiveMode, board: state.boardIndex, alight: state.alightIndex);
    final adv = comp.advice;
    final az = comp.azimuth;
    final alt = comp.altitude;

    // heading: 실제 센서 없으면 태양 기준 -22°에서 시작하는 시뮬레이션 값.
    final heading = _heading ?? (az - 22 + _dragOffset);
    final rel = _normalize(az - heading);
    const ppdFraction = 5.6 / 390;
    final sunRight = adv.sunOnRight;
    final incAngle = (math.sin(rel * math.pi / 180)).abs() * 78 + 6;
    final depth = 20 + (1 - alt) * 95;

    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() => _dragOffset -= d.delta.dx * 0.34);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_camera != null && _camera!.value.isInitialized) CameraPreview(_camera!) else CustomPaint(painter: CitySilhouettePainter()),
                  LayoutBuilder(builder: (context, constraints) {
                    final w = constraints.maxWidth, h = constraints.maxHeight;
                    final sunXFrac = 0.5 + rel * ppdFraction;
                    final sunYFrac = 0.6 - alt * 0.3436;
                    final sunX = sunXFrac * w, sunY = sunYFrac * h;
                    final paneCxFrac = sunRight ? 290 / 390 : 100 / 390;

                    return Stack(
                      children: [
                        // 태양 광선 (창 쪽으로)
                        if (alt > 0.02 && rel.abs() < 90)
                          CustomPaint(
                            size: Size(w, h),
                            painter: _RayPainter(sun: Offset(sunX, sunY), target: Offset(paneCxFrac * w, h * 0.86), fade: rel.abs() > 30),
                          ),
                        // 태양
                        if (alt > 0.02)
                          Positioned(
                            left: sunX - 32,
                            top: sunY - 32,
                            child: IgnorePointer(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFDE68A),
                                  boxShadow: [BoxShadow(color: const Color(0xFFFDE68A).withOpacity(.55), blurRadius: 90, spreadRadius: 20)],
                                ),
                              ),
                            ),
                          ),
                        // 버스 창 프레임
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: h * 0.10,
                          child: Row(
                            children: [
                              Expanded(child: _WindowPane(label: '좌측 창', lit: !sunRight && alt > 0.02, palette: palette)),
                              const SizedBox(width: 10),
                              Expanded(child: _WindowPane(label: '우측 창', lit: sunRight && alt > 0.02, palette: palette)),
                            ],
                          ),
                        ),
                        // 나침반 스트립
                        Positioned(top: 2, left: 0, right: 0, child: _CompassStrip(heading: heading, width: w)),
                        // 상단 칩
                        Positioned(
                          left: 14,
                          right: 14,
                          top: 56,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(.6), borderRadius: BorderRadius.circular(999)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                                    const SizedBox(width: 7),
                                    Text(
                                      _camera != null ? '카메라로 하늘 보기' : '카메라로 하늘 보기 · 예시 프리뷰',
                                      style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(.6), borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  '단말 방위 ${((heading % 360) + 360) % 360 ~/ 1}°',
                                  style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (rel.abs() > 34)
                          Positioned(
                            left: rel < 0 ? 14 : null,
                            right: rel < 0 ? null : 14,
                            top: h / 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(.72), borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.flip(
                                    flipX: rel >= 0,
                                    child: const Icon(Icons.arrow_back, size: 17, color: Color(0xFFFDE68A)),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '태양은 ${rel < 0 ? '왼쪽' : '오른쪽'} ${rel.abs().round()}° · 계속 돌려보세요',
                                    style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFDE68A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 8,
                          child: Text(
                            _sensorHeading == null && state.arHeadingOverride == null ? '화면을 좌우로 드래그하면 휴대폰을 돌리는 것과 같아요' : '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        _ArSheet(palette: palette, state: state, comp: comp, adv: adv, sunRight: sunRight, incAngle: incAngle, depth: depth),
      ],
    );
  }
}

class _WindowPane extends StatelessWidget {
  final String label;
  final bool lit;
  final AppPalette palette;

  const _WindowPane({required this.label, required this.lit, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: lit ? const Color(0xFFFBBF24).withOpacity(.26) : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lit ? const Color(0xFFFBBF24) : Colors.white24, width: lit ? 2 : 1),
      ),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 8),
      child: Text(label, style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
    );
  }
}

class _RayPainter extends CustomPainter {
  final Offset sun;
  final Offset target;
  final bool fade;

  _RayPainter({required this.sun, required this.target, required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDE68A).withOpacity(fade ? .25 : .85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    _dashedLine(canvas, sun, target, paint);
    final patch = Paint()..color = const Color(0xFFFBBF24).withOpacity(.30);
    canvas.drawCircle(target, 26, patch);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 9.0, gapLen = 8.0;
    final total = (b - a).distance;
    var covered = 0.0;
    final dir = (b - a) / total;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * math.min(covered + dashLen, total);
      canvas.drawLine(start, end, paint);
      covered += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) => oldDelegate.sun != sun || oldDelegate.target != target || oldDelegate.fade != fade;
}

class _CompassStrip extends StatelessWidget {
  final double heading;
  final double width;

  const _CompassStrip({required this.heading, required this.width});

  double _normalize(double d) {
    var x = ((d % 360) + 360) % 360;
    if (x > 180) x -= 360;
    return x;
  }

  @override
  Widget build(BuildContext context) {
    const cardinal = {0: '북', 45: '북동', 90: '동', 135: '남동', 180: '남', 225: '남서', 270: '서', 315: '북서'};
    final ppdFraction = 5.6 / 390;
    final children = <Widget>[];
    for (var d = 0; d < 360; d += 15) {
      final off = _normalize(d - heading);
      if (off.abs() > 40) continue;
      final name = cardinal[d];
      final x = width * (0.5 + off * ppdFraction);
      children.add(Positioned(
        left: x - 20,
        top: 2,
        width: 40,
        child: Text(
          name ?? '·',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: name != null ? 12 : 10,
            fontWeight: FontWeight.w800,
            color: name != null ? Colors.white : Colors.white54,
          ),
        ),
      ));
    }
    return SizedBox(height: 20, child: Stack(children: children));
  }
}

class _ArSheet extends StatelessWidget {
  final AppPalette palette;
  final AppState state;
  final SeatComputation comp;
  final SeatAdvice adv;
  final bool sunRight;
  final double incAngle;
  final double depth;

  const _ArSheet({required this.palette, required this.state, required this.comp, required this.adv, required this.sunRight, required this.incAngle, required this.depth});

  @override
  Widget build(BuildContext context) {
    final belowHorizon = comp.altitude < 0.02;
    final verdict = belowHorizon ? '해가 지평선 아래예요' : '${adv.sideLabel} 창가에 앉으세요';
    final incNote = belowHorizon ? '직사광이 없어 좌석 차이가 거의 없어요' : '${sunRight ? '우측' : '좌측'} 창으로 입사각 ${incAngle.round()}° · 좌석 ${depth.round()}cm까지 들어옴';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [palette.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: palette.primary.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                child: DirectionArrow(pointLeft: adv.leftSeat, color: palette.primaryText, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(verdict, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.4, color: palette.text)),
                    Text(incNote, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.primaryText)),
                  ],
                ),
              ),
              IconCircleButton(icon: const Icon(Icons.close, size: 15), color: palette.textMuted, onTap: () => state.goto(AppScreen.result)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatBox(number: comp.azimuthShort, caption: '태양 방위', palette: palette)),
              const SizedBox(width: 7),
              Expanded(child: _StatBox(number: '${(comp.altitude * 62).round()}°', caption: '태양 고도', palette: palette)),
              const SizedBox(width: 7),
              Expanded(child: _StatBox(number: '${incAngle.round()}°', caption: '창 입사각', palette: palette)),
            ],
          ),
          const SizedBox(height: 12),
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
                  child: Slider(
                    value: state.minutes.toDouble(),
                    min: 300,
                    max: 1200,
                    activeColor: palette.primary,
                    inactiveColor: palette.subtle,
                    onChanged: (v) => state.setMinutes(v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(SunCalc.timeLabel(state.minutes), textAlign: TextAlign.right, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String number;
  final String caption;
  final AppPalette palette;

  const _StatBox({required this.number, required this.caption, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(number, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, color: palette.text)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, color: palette.textMuted)),
        ],
      ),
    );
  }
}
