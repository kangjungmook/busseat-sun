import 'package:flutter/material.dart';

import '../logic/seat_advice.dart';
import '../theme/tokens.dart';

/// 경로 지도 배경 — 도로 그리드 + 건물 블록 + 6구간 경로. 로컬 좌표계 390×790.
class RouteMapPainter extends CustomPainter {
  final AppPalette palette;
  final List<SegKind> segments;

  RouteMapPainter({required this.palette, required this.segments});

  static const double vbW = 390, vbH = 790;

  static const List<List<double>> _blockRows = [
    [46, 52],
    [122, 52],
    [202, 54],
    [282, 54],
    [360, 52],
    [440, 52],
    [516, 52],
    [596, 52],
    [670, 52],
  ];
  static const List<List<double>> _blockCols = [
    [78, 40],
    [146, 38],
    [212, 32],
    [272, 30],
  ];

  static Path _segmentPath(int i) {
    final p = Path();
    switch (i) {
      case 0:
        p.moveTo(104, 452);
        p.lineTo(104, 392);
        p.quadraticBezierTo(104, 380, 120, 376);
        p.lineTo(170, 366);
        break;
      case 1:
        p.moveTo(170, 366);
        p.lineTo(198, 360);
        break;
      case 2:
        p.moveTo(198, 360);
        p.lineTo(198, 268);
        break;
      case 3:
        p.moveTo(198, 268);
        p.lineTo(198, 196);
        break;
      case 4:
        p.moveTo(198, 196);
        p.lineTo(198, 150);
        p.quadraticBezierTo(198, 138, 214, 134);
        p.lineTo(244, 128);
        break;
      case 5:
        p.moveTo(244, 128);
        p.lineTo(252, 126);
        break;
    }
    return p;
  }

  Color _segColor(SegKind k) {
    switch (k) {
      case SegKind.shade:
        return palette.primary;
      case SegKind.sun:
        return palette.sunDiscColor;
      case SegKind.weak:
        return palette.surface.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / vbW, sy = size.height / vbH;
    canvas.save();
    canvas.scale(sx, sy);

    canvas.drawRect(const Rect.fromLTWH(-40, -10, 470, 820), Paint()..color = palette.surface.mapBase);

    final roadMajor = Paint()
      ..color = palette.surface.mapRoad
      ..strokeWidth = 16;
    for (final y in [110.0, 268.0, 424.0, 580.0, 730.0]) {
      canvas.drawLine(Offset(-40, y), Offset(430, y), roadMajor);
    }
    for (final x in [64.0, 198.0, 312.0]) {
      canvas.drawLine(Offset(x, -10), Offset(x, 800), roadMajor);
    }
    final roadMinor = Paint()
      ..color = palette.surface.mapRoad.withOpacity(.85)
      ..strokeWidth = 6;
    for (final y in [32.0, 188.0, 348.0, 502.0, 656.0]) {
      canvas.drawLine(Offset(-40, y), Offset(430, y), roadMinor);
    }
    for (final x in [132.0, 256.0]) {
      canvas.drawLine(Offset(x, -10), Offset(x, 800), roadMinor);
    }

    final blockPaint = Paint()..color = palette.surface.mapBlock;
    for (final row in _blockRows) {
      final y = row[0], h = row[1];
      for (final col in _blockCols) {
        final x = col[0], w = col[1];
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)), blockPaint);
      }
    }

    for (var i = 0; i < segments.length && i < 6; i++) {
      final paint = Paint()
        ..color = _segColor(segments[i])
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = _segmentPath(i);
      // 좌우 차이가 거의 없는 구간은 점선으로 — 예전엔 '지하·터널'이었지만
      // 그건 우리가 가진 적 없는 데이터였다.
      if (segments[i] == SegKind.weak) {
        _drawDashedPath(canvas, path, paint, 2, 10);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashLen, double gapLen) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLen;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) => oldDelegate.segments != segments || oldDelegate.palette != palette;
}
