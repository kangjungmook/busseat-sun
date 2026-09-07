import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class StopPickerScreen extends StatelessWidget {
  final AppPalette palette;

  const StopPickerScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    final dir = state.currentDir;
    if (route == null || dir == null) return const SizedBox.shrink();

    final stops = dir.stops;
    final last = stops.length - 1;
    final bIdx = state.boardIndex.clamp(0, last - 1 < 0 ? 0 : last - 1);
    final aIdx = state.alightIndex ?? last;
    final near = state.nearestStop; // 실제 GPS·정류소 좌표 기반 (없으면 fallback)
    final nearIdx = near?.index ?? (last > 0 ? 1 : 0);
    final nearM = near?.meters.round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: () => state.goto(AppScreen.result)),
                  const SizedBox(width: 6),
                  Text('구간 지정', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.6, color: palette.text)),
                  const Spacer(),
                  Text('${route.no} · ${dir.name}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
                ],
              ),
            ),
            SegmentedPill(
              labels: ['탑승 · ${stops[bIdx]}', '하차 · ${stops[aIdx]}'],
              selected: state.pickMode == 'board' ? 0 : 1,
              onSelect: (i) => i == 0 ? state.pickBoardTab() : state.pickAlightTab(),
              palette: palette,
            ),
            const SizedBox(height: 8),
            Text(
              state.pickMode == 'board' ? '탈 정류장을 고르면 그늘 계산이 그 구간만으로 다시 됩니다.' : '내릴 정류장을 고르세요. 탑승 이후 정류장만 선택돼요.',
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted, letterSpacing: -.1),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(width: 20, height: 20, decoration: const BoxDecoration(color: kLocationBlue, shape: BoxShape.circle), child: const Icon(Icons.location_on, color: Colors.white, size: 12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('현재 위치', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
                        Text(
                          state.location == null ? '아직 위치를 확인하지 않았어요' : 'GPS ${state.location!.accuracyLabel} 오차로 확인됨',
                          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: state.useNearestStop,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('가까운 정류장으로', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.onPrimary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: stops.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (context, i) {
                  final isB = i == bIdx, isA = i == aIdx;
                  final dim = state.pickMode != 'board' && i <= bIdx;
                  final active = state.pickMode == 'board' ? isB : isA;
                  final meta = i == nearIdx
                      ? (nearM != null ? '현재 위치에서 ${nearM}m · 도보 약 ${(nearM / 67).ceil().clamp(1, 99)}분' : '가장 가까울 것으로 추정')
                      : (i == 0 ? '기점' : (i == last ? '종점' : '경유 정류장'));
                  final tagText = isB ? '탑승' : (isA ? '하차' : '');
                  return Opacity(
                    opacity: dim ? .42 : 1,
                    child: Material(
                      color: active ? (palette.isDark ? Colors.white.withOpacity(.06) : palette.surfaceColor) : palette.subtle,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: dim ? null : () => state.tapStop(i, last),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 62),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? palette.primary : Colors.transparent, width: 2)),
                          child: Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: isB ? palette.primary : (isA ? kLocationBlue : (palette.isDark ? const Color(0xFF3F3B39) : const Color(0xFFDDDAD5))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(stops[i], style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15.5, fontWeight: FontWeight.w700, color: palette.text)),
                                    Text(meta, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted)),
                                  ],
                                ),
                              ),
                              if (tagText.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(color: isB ? palette.primary : kLocationBlue, borderRadius: BorderRadius.circular(8)),
                                  child: Text(tagText, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w800, color: isB ? palette.onPrimary : Colors.white)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SolidButton(text: '이 구간으로 계산 · ${stops[bIdx]} → ${stops[aIdx]}', onTap: state.applyStops, palette: palette, height: 52),
            const SizedBox(height: 4),
            GhostButton(text: '방면 전체(기점 → 종점)로 두기', onTap: state.wholeLine, palette: palette),
          ],
        ),
      ),
    );
  }
}
