import 'package:flutter/material.dart';

/// AR 화면의 하늘/건물 배경 (카메라 프리뷰가 없을 때 대체 배경으로도 쓴다).
class CitySilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.6;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), Paint()..color = const Color(0xFF8FA0B2));
    canvas.drawRect(Rect.fromLTWH(0, horizon, size.width, size.height - horizon), Paint()..color = const Color(0xFF3A3633));

    final buildingPaint = Paint()..color = const Color(0xFF2B2724).withOpacity(.92);
    final w = size.width;
    final buildings = [
      Rect.fromLTWH(-w * 0.02, horizon - 146, w * 0.22, 146),
      Rect.fromLTWH(w * 0.22, horizon - 114, w * 0.16, 114),
      Rect.fromLTWH(w * 0.40, horizon - 172, w * 0.19, 172),
      Rect.fromLTWH(w * 0.61, horizon - 96, w * 0.15, 96),
      Rect.fromLTWH(w * 0.78, horizon - 138, w * 0.23, 138),
    ];
    for (final b in buildings) {
      canvas.drawRect(b, buildingPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF6E6B66)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, horizon), Offset(w, horizon), linePaint);

    final roadPaint = Paint()
      ..color = const Color(0xFF575149)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.71), Offset(w, size.height * 0.71), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.80), Offset(w, size.height * 0.80), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
