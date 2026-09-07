import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/computation.dart';
import '../logic/seat_advice.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class SeatMapScreen extends StatelessWidget {
  final AppPalette palette;

  const SeatMapScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    final dir = state.currentDir;
    if (route == null || dir == null) return const SizedBox.shrink();

    final comp = SeatComputation.build(
      route: route,
      dirIndex: state.dirIndex,
      minutes: state.minutes,
      mode: state.effectiveMode,
      board: state.boardIndex,
      alight: state.alightIndex,
    );
    final adv = comp.advice;
    final goodColor = palette.primary;
    final badColor = palette.badColor;
    final badFg = palette.badForeground;

    final best = SeatCalc.bestSeat(adv);
    final (leftAvg, rightAvg) = SeatCalc.sideAverages(adv);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: () => state.goto(AppScreen.result)),
                  const SizedBox(width: 6),
                  Text('좌석별 그늘 지도', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.6, color: palette.text)),
                  const Spacer(),
                  Text(comp.spanLabel, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
                ],
              ),
            ),
            Row(
              children: [
                Text('왼쪽 $leftAvg%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.text)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(999)),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        Expanded(flex: leftAvg, child: Container(color: leftAvg >= rightAvg ? goodColor : badColor.withOpacity(.75))),
                        Expanded(flex: rightAvg, child: Container(color: rightAvg > leftAvg ? goodColor : badColor.withOpacity(.75))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('오른쪽 $rightAvg%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.text)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(26), border: Border.all(color: palette.line, width: 2)),
                child: Column(
                  children: [
                    Container(
                      height: 26,
                      decoration: BoxDecoration(color: kLocationBlue.withOpacity(palette.isDark ? .22 : .10), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text('앞유리 · 진행 방향 ↑', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w800, color: palette.textMuted)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: palette.surfaceColor, shape: BoxShape.circle, border: Border.all(color: palette.line)),
                            child: Icon(Icons.trip_origin, size: 15, color: palette.textMuted),
                          ),
                          Text('운전석', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10, fontWeight: FontWeight.w700, color: palette.textMuted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: palette.line)),
                            child: Text('앞문', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 9.5, fontWeight: FontWeight.w800, color: palette.textMuted)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          for (var row = 0; row < SeatCalc.rowCount; row++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SeatRow(
                                  row: row,
                                  adv: adv,
                                  best: best,
                                  palette: palette,
                                  goodColor: goodColor,
                                  badColor: badColor,
                                  badFg: badFg,
                                ),
                              ),
                            ),
                          _RearRow(leftAvg: leftAvg, rightAvg: rightAvg, palette: palette, goodColor: goodColor, badColor: badColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: goodColor, label: '그늘 강', palette: palette),
                const SizedBox(width: 11),
                _Legend(color: goodColor.withOpacity(.42), label: '보통', palette: palette),
                const SizedBox(width: 11),
                _Legend(color: badColor.withOpacity(.38), label: '약한 직사광', palette: palette),
                const SizedBox(width: 11),
                _Legend(color: badColor, label: '강한 직사광', palette: palette),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.primary, width: 2)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text('추천', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w800, color: palette.onPrimary)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${best.row + 1}열 ${best.col < 2 ? '왼쪽' : '오른쪽'}${best.col == 0 || best.col == 3 ? ' 창가' : ' 통로'} · ${best.row * 4 + best.col + 1}번',
                          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text),
                        ),
                        Text(
                          '${state.effectiveMode == SunMode.shade ? '이 구간 중 그늘' : '이 구간 중 볕'} ${(best.score * 0.42).round()}분 · 반대쪽보다 ${(leftAvg - rightAvg).abs().clamp(4, 100)}%p 유리',
                          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text('${best.score}%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 19, fontWeight: FontWeight.w800, color: palette.primaryText)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '지하·터널 구간은 계산에서 제외했어요 · 좌석 배치는 ${route.no}번 표준 차량 기준',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final int row;
  final SeatAdvice adv;
  final ({int row, int col, int score}) best;
  final AppPalette palette;
  final Color goodColor;
  final Color badColor;
  final Color badFg;

  const _SeatRow({required this.row, required this.adv, required this.best, required this.palette, required this.goodColor, required this.badColor, required this.badFg});

  Color _bg(int score) {
    final level = shadeLevelOf(score);
    switch (level) {
      case ShadeLevel.strong:
        return goodColor;
      case ShadeLevel.mid:
        return goodColor.withOpacity(.42);
      case ShadeLevel.weak:
        return badColor.withOpacity(.38);
      case ShadeLevel.direct:
        return badColor;
    }
  }

  Color _fg(int score) {
    final level = shadeLevelOf(score);
    if (level == ShadeLevel.strong) return palette.onPrimary;
    if (level == ShadeLevel.direct) return badFg;
    return palette.text;
  }

  Widget _winStrip(int score) {
    final level = score >= 70 ? goodColor.withOpacity(.75) : (score >= 45 ? badColor.withOpacity(.5) : badColor);
    return Container(width: 8, decoration: BoxDecoration(color: level, borderRadius: BorderRadius.circular(3)));
  }

  Widget _seat(int col) {
    final score = SeatCalc.seatScore(row, col, adv);
    final isBest = best.row == row && best.col == col;
    final label = (isBest ? '★' : '') + '${row * 4 + col + 1}';
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: _bg(score),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isBest ? palette.text : Colors.transparent, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: _fg(score))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreA = SeatCalc.seatScore(row, 0, adv);
    final scoreD = SeatCalc.seatScore(row, 3, adv);
    return Row(
      children: [
        _winStrip(scoreA),
        const SizedBox(width: 4),
        _seat(0),
        _seat(1),
        SizedBox(
          width: 26,
          child: Text('${row + 1}열', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 9.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
        ),
        _seat(2),
        _seat(3),
        const SizedBox(width: 4),
        _winStrip(scoreD),
      ],
    );
  }
}

class _RearRow extends StatelessWidget {
  final int leftAvg;
  final int rightAvg;
  final AppPalette palette;
  final Color goodColor;
  final Color badColor;

  const _RearRow({required this.leftAvg, required this.rightAvg, required this.palette, required this.goodColor, required this.badColor});

  @override
  Widget build(BuildContext context) {
    Widget winStrip(int score) {
      final c = score >= 70 ? goodColor.withOpacity(.75) : (score >= 45 ? badColor.withOpacity(.5) : badColor);
      return Container(width: 8, height: 42, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          winStrip(leftAvg),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(color: goodColor.withOpacity(.28), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('맨 뒷줄 5석 · 평균 ${((leftAvg + rightAvg) / 2).round()}%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10, fontWeight: FontWeight.w800, color: palette.text)),
            ),
          ),
          const SizedBox(width: 6),
          winStrip(rightAvg),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final AppPalette palette;

  const _Legend({required this.color, required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, color: palette.textMuted)),
      ],
    );
  }
}
