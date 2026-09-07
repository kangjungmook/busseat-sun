import 'package:flutter/material.dart';

/// 햇살좌석 앱 아이콘 (앰버 배경 + 흰 태양 + 인디고 좌석 실루엣). 앱 아이콘.dc.html B안.
class AppIconMark extends StatelessWidget {
  final double size;

  const AppIconMark({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppIconPainter()),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    void scaleCanvas(void Function() draw) {
      canvas.save();
      canvas.scale(s);
      draw();
      canvas.restore();
    }

    scaleCanvas(() {
      final bg = Paint()..color = const Color(0xFFF59E0B);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 512, 512), const Radius.circular(118)),
        bg,
      );

      final sun = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(368, 146), 52, sun);

      final ray = Paint()
        ..color = Colors.white
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;
      const rays = [
        [Offset(368, 44), Offset(368, 66)],
        [Offset(368, 226), Offset(368, 248)],
        [Offset(266, 146), Offset(288, 146)],
        [Offset(448, 146), Offset(470, 146)],
        [Offset(296, 74), Offset(312, 90)],
        [Offset(424, 202), Offset(440, 218)],
        [Offset(440, 74), Offset(424, 90)],
        [Offset(312, 202), Offset(296, 218)],
      ];
      for (final r in rays) {
        canvas.drawLine(r[0], r[1], ray);
      }

      final seat = Paint()..color = const Color(0xFF312E81);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(132, 160, 80, 204), const Radius.circular(38)),
        seat,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(132, 306, 230, 62), const Radius.circular(30)),
        seat,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(150, 362, 36, 76), const Radius.circular(18)),
        seat,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(308, 362, 36, 76), const Radius.circular(18)),
        seat,
      );
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
