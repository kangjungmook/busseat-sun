import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/computation.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/common.dart';

class WidgetScreen extends StatelessWidget {
  final AppPalette palette;

  const WidgetScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fav = state.favorites.isNotEmpty ? state.favorites.first : null;
    final route = fav != null ? state.currentRoute : null;

    SeatComputation? comp;
    if (fav != null && route != null) {
      comp = SeatComputation.build(route: route, dirIndex: fav.dirIndex, minutes: state.minutes, mode: state.effectiveMode, board: fav.boardIndex, alight: fav.alightIndex);
    }
    final adv = comp?.advice;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: () => state.goto(AppScreen.settings)),
                  const SizedBox(width: 6),
                  Text('위젯 미리보기', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.4, color: palette.text)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.subtle, palette.background]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateLabel(), style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
                  Text(state.clockLabel, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 62, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -2.6, color: palette.text)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: palette.surfaceColor.withOpacity(.9), borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        if (adv != null) DirectionArrow(pointLeft: adv.leftSeat, color: palette.primaryText, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fav == null ? '즐겨찾기를 등록하면 표시돼요' : '${fav.routeNo} · ${adv!.sideLabel} 창가',
                            style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text),
                          ),
                        ),
                        if (adv != null) Text('${adv.pct}%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.primaryText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(22), boxShadow: [palette.cardShadow]),
                  child: fav == null
                      ? Center(child: Text('위젯', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fav.routeNo, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.textMuted)),
                                const AppIconMark(size: 20),
                              ],
                            ),
                            const Spacer(),
                            DirectionArrow(pointLeft: adv!.leftSeat, color: palette.primaryText, size: 30),
                            const SizedBox(height: 4),
                            Text('${adv.sideLabel}\n창가', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 17, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -.5, color: palette.text)),
                            Text('${adv.pct}${state.effectiveMode == SunMode.shade ? '% 그늘' : '% 볕'} · 3분 후', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.primaryText)),
                          ],
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      Row(children: List.generate(3, (_) => _AppIconPlaceholder(palette: palette))),
                      const SizedBox(height: 11),
                      Row(children: List.generate(3, (_) => _AppIconPlaceholder(palette: palette))),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text('위젯을 탭하면 계산된 결과가 바로 열려요', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}';
  }
}

class _AppIconPlaceholder extends StatelessWidget {
  final AppPalette palette;

  const _AppIconPlaceholder({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.5),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(16))),
        ),
      ),
    );
  }
}
