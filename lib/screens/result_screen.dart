import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/computation.dart';
import '../logic/seat_advice.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/seat_pictogram.dart';
import '../widgets/segment_bar.dart';

class ResultScreen extends StatelessWidget {
  final AppPalette palette;

  const ResultScreen({super.key, required this.palette});

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
      sun: state.sun,
      board: state.boardIndex,
      alight: state.alightIndex,
    );
    final adv = comp.advice;
    final modeWord = state.effectiveMode == SunMode.shade ? '그늘' : '햇살';

    return SafeArea(
      child: RiseIn(
        play: state.resultEntered,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: state.goHome),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Text('${route.no} · ${dir.name}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, fontWeight: FontWeight.w700, color: palette.text)),
                        ),
                      ),
                    ),
                    IconCircleButton(icon: const Icon(Icons.brightness_6_outlined), color: palette.text, onTap: state.toggleMode),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _ConclusionCard(state: state, comp: comp, palette: palette, modeWord: modeWord, adv: adv),
                    const SizedBox(height: 12),
                    _DetailCard(comp: comp, palette: palette),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: Material(
                      color: palette.text,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        onTap: () => state.goto(AppScreen.ar),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 19, color: palette.background),
                              const SizedBox(width: 8),
                              Text('카메라로 지금 햇빛 각도 보기', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15.5, fontWeight: FontWeight.w800, color: palette.background)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: OutlineButton(text: '지도로 보기', onTap: () => state.goto(AppScreen.map), palette: palette, height: 56, icon: Icon(Icons.map_outlined, size: 16, color: palette.text))),
                      const SizedBox(width: 9),
                      Expanded(
                        child: SolidButton(
                          text: state.isCurrentFavorite ? '즐겨찾기 수정' : '+ 3초 등록',
                          onTap: state.openFavSheet,
                          palette: palette,
                          height: 56,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // 예전 문구는 '기상청 일사 … 기준 · 건물 그림자 반영'이었다.
                    // 둘 다 사실이 아니다 — 기상청 API를 부르지 않고, 건물 높이
                    // 데이터도 없다. 앱의 결론이 나오는 화면에서 근거를 지어내면
                    // 사용자가 이 답을 실제보다 더 믿게 된다.
                    '태양 위치 ${comp.timeLabel} 기준 · 직사광 기준(건물 그림자 미반영) · ${comp.spanLabel} 구간',
                    style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, color: palette.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConclusionCard extends StatelessWidget {
  final AppState state;
  final SeatComputation comp;
  final AppPalette palette;
  final String modeWord;
  final SeatAdvice adv;

  const _ConclusionCard({required this.state, required this.comp, required this.palette, required this.modeWord, required this.adv});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(26), boxShadow: [palette.cardShadow]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(8)),
                child: Text(modeWord, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: palette.text)),
              ),
              GestureDetector(
                onTap: () => state.goto(AppScreen.stopPicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.line)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(comp.spanLabel, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.text)),
                      const SizedBox(width: 6),
                      Text('변경', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted, decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.2, color: palette.text),
              children: [
                TextSpan(text: '${adv.sideLabel} 창가', style: TextStyle(color: palette.primaryText)),
                const TextSpan(text: '에 앉으세요'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: palette.line),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SeatPictogram(leftSeat: adv.leftSeat, palette: palette, onTap: () => state.goto(AppScreen.seatMap)),
              const SizedBox(width: 18),
              Container(width: 1, height: 64, color: palette.line),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${adv.pct}%', style: AppTextStyles.bigPercent(palette.text)),
                    const SizedBox(height: 2),
                    Text(state.effectiveMode == SunMode.shade ? '이동 중 그늘 유지' : '이동 중 볕 좋음', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.isDark ? Colors.black.withOpacity(.28) : Colors.black.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: palette.primary, width: 3)),
            ),
            child: Text(
              '태양이 진행 방향 ${adv.sunOnRight ? '오른쪽' : '왼쪽'}(${comp.azimuthLong})에 있어요.',
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final SeatComputation comp;
  final AppPalette palette;

  const _DetailCard({required this.comp, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('구간별 일사', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.text)),
              Text(comp.timeLabel, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in comp.sampledStopLabels) Text(s, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, color: palette.textMuted)),
            ],
          ),
          const SizedBox(height: 5),
          // 정류장 좌표가 없는 노선은 구간 분포를 계산할 수 없다 — 가짜 막대를
          // 그리느니 그렇다고 말한다.
          if (comp.hasSegmentData) ...[
            SegmentBar(segments: comp.segments, meters: comp.segmentMeters, palette: palette),
            const SizedBox(height: 10),
            SegmentLegend(palette: palette),
          ] else
            Container(
              height: 36,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(11)),
              child: Text(
                '이 노선은 정류장 좌표가 없어 구간별로 나눌 수 없어요',
                style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatBox(number: '${comp.stopCount}', caption: '정류장', palette: palette)),
              const SizedBox(width: 7),
              Expanded(child: _StatBox(number: '${comp.durationMin}분', caption: '예상 소요', palette: palette)),
              const SizedBox(width: 7),
              Expanded(child: _StatBox(number: comp.azimuthShort, caption: '태양 방위', palette: palette)),
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
