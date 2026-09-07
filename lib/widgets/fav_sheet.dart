import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// "3초 등록" — 결과 화면에서 즐겨찾기 저장.
class FavSheet extends StatelessWidget {
  final AppPalette palette;

  const FavSheet({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    final dir = state.currentDir;
    if (route == null || dir == null) return const SizedBox.shrink();
    final last = dir.stops.length - 1;
    final bIdx = state.boardIndex.clamp(0, last - 1 < 0 ? 0 : last - 1);
    final aIdx = state.alightIndex ?? last;
    final from = dir.stops[bIdx];
    final to = dir.stops[aIdx];

    return Positioned.fill(
      child: GestureDetector(
        onTap: state.closeFavSheet,
        child: Container(
          color: Colors.black.withOpacity(.42),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: palette.line, borderRadius: BorderRadius.circular(999))),
                  ),
                  Text('3초 등록', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.6, color: palette.text)),
                  const SizedBox(height: 4),
                  Text('이 구간을 저장하면 앱을 켜는 즉시 결과가 떠요.', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, color: palette.textMuted)),
                  const SizedBox(height: 18),
                  Text('언제 타는 노선인가요?', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3, color: palette.textMuted)),
                  const SizedBox(height: 8),
                  SegmentedPill(
                    labels: const ['출근', '퇴근', '기타'],
                    selected: const ['출근', '퇴근', '기타'].indexOf(state.favLabel).clamp(0, 2),
                    onSelect: (i) => state.setFavLabel(['출근', '퇴근', '기타'][i]),
                    palette: palette,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _EditRow(
                            dotColor: palette.primary,
                            label: '탑승',
                            value: from,
                            trailing: route.no,
                            palette: palette,
                            onTap: () {
                              state.closeFavSheet();
                              state.goto(AppScreen.stopPicker);
                            }),
                        Container(height: 1, color: palette.line),
                        _EditRow(
                            dotColor: kLocationBlue,
                            label: '하차',
                            value: to,
                            trailing: '변경',
                            palette: palette,
                            onTap: () {
                              state.closeFavSheet();
                              state.goto(AppScreen.stopPicker);
                            }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SolidButton(text: '저장하고 실행 화면 보기', onTap: state.saveFavorite, palette: palette, height: 52),
                  GhostButton(text: '취소', onTap: state.closeFavSheet, palette: palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final String trailing;
  final AppPalette palette;
  final VoidCallback onTap;

  const _EditRow({required this.dotColor, required this.label, required this.value, required this.trailing, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(width: 11, height: 11, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
                    Text(value, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15.5, fontWeight: FontWeight.w700, color: palette.text)),
                  ],
                ),
              ),
              Text(trailing, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
