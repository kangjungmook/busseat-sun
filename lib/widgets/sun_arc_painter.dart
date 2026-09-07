import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 홈 화면의 태양 궤적 패널. viewBox 0 0 320 92 좌표계를 컨테이너 크기에 맞게
/// 비균등 스케일(preserveAspectRatio="none")로 그린다.
class SunArcPainter extends CustomPainter {
  final double dayProgress; // 0(일출)~1(일몰)
  final Color trackColor;
  final Color fillColor;

  SunArcPainter({required this.dayProgress, required this.trackColor, required this.fillColor});

  static const double _vbW = 320, _vbH = 92;

  static Offset domePoint(double d) {
    final x = 10 + d * 300;
    final y = 84 - math.sin(math.pi * d) * 66;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    canvas.save();
    canvas.scale(sx, sy);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 점선 돔 트랙 (전체)
    const dash = 2.0, gap = 7.0;
    double dist = 0;
    Offset? prev;
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final d = i / steps;
      final p = domePoint(d);
      if (prev != null) {
        final segLen = (p - prev).distance;
        var travelled = 0.0;
        while (travelled < segLen) {
          final onDash = (dist % (dash + gap)) < dash;
          final segStart = prev + (p - prev) * (travelled / segLen);
          final next = math.min(travelled + 0.6, segLen);
          final segEnd = prev + (p - prev) * (next / segLen);
          if (onDash) canvas.drawLine(segStart, segEnd, trackPaint);
          dist += 0.6;
          travelled = next;
        }
      }
      prev = p;
    }

    // 기준선
    canvas.drawLine(const Offset(6, 84), const Offset(314, 84), trackPaint..strokeWidth = 2);

    // 진행분 (실선, 현재 위치까지)
    final fillPaint = Paint()
      ..color = fillColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPath = Path();
    const fillSteps = 80;
    for (var i = 0; i <= fillSteps; i++) {
      final d = (i / fillSteps) * dayProgress;
      final p = domePoint(d);
      if (i == 0) {
        fillPath.moveTo(p.dx, p.dy);
      } else {
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(fillPath, fillPaint);

    final sunPos = domePoint(dayProgress);
    canvas.drawCircle(sunPos, 15, Paint()..color = fillColor.withOpacity(.2));
    canvas.drawCircle(sunPos, 9, Paint()..color = fillColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SunArcPainter oldDelegate) => oldDelegate.dayProgress != dayProgress || oldDelegate.trackColor != trackColor || oldDelegate.fillColor != fillColor;
}
