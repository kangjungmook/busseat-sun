import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 결과 화면 히어로의 좌석 단면 픽토그램 — 진행 방향, 창-좌석-좌석-통로-좌석-좌석-창.
class SeatPictogram extends StatelessWidget {
  final bool leftSeat;
  final AppPalette palette;
  final VoidCallback? onTap;

  const SeatPictogram({super.key, required this.leftSeat, required this.palette, this.onTap});

  Widget _cell(bool on, {bool isWindow = false}) {
    final color = on ? palette.primary : (palette.isDark ? const Color(0xFF3F3B39) : const Color(0xFFDDDAD5));
    return Container(
      width: isWindow ? 8 : 16,
      height: 12,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(isWindow ? 3 : 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('진행 방향 ↑', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cell(leftSeat, isWindow: true),
              const SizedBox(width: 4),
              Column(children: [_cell(leftSeat), const SizedBox(height: 6), _cell(leftSeat)]),
              const SizedBox(width: 10),
              Column(children: [_cell(!leftSeat), const SizedBox(height: 6), _cell(!leftSeat)]),
              const SizedBox(width: 4),
              _cell(!leftSeat, isWindow: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                child: Text('왼쪽', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w800, color: leftSeat ? palette.primaryText : palette.textMuted)),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text('오른쪽', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w800, color: !leftSeat ? palette.primaryText : palette.textMuted)),
              ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Text('좌석 지도 자세히 ›', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.text, decoration: TextDecoration.underline)),
          ],
        ],
      ),
    );
  }
}
