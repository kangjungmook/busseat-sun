import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/computation.dart';
import '../models/route.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  final AppPalette palette;

  const TodayScreen({super.key, required this.palette});

  SeatComputation _computeFor(Favorite f, AppState state) {
    final route = findRoute(f.routeNo);
    return SeatComputation.build(
      route: route,
      dirIndex: f.dirIndex,
      minutes: state.minutes,
      mode: state.effectiveMode,
      board: f.boardIndex,
      alight: f.alightIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favs = state.favorites;
    final f1 = favs.isNotEmpty ? favs[0] : null;
    final f2 = favs.length > 1 ? favs[1] : null;

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
                  Text(
                    _dateLabel(),
                    style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, fontWeight: FontWeight.w700, color: palette.textMuted),
                  ),
                  const Spacer(),
                  IconCircleButton(
                    icon: const Icon(Icons.settings_outlined),
                    color: palette.text,
                    onTap: () => state.goto(AppScreen.settings),
                  ),
                ],
              ),
            ),
            Text(
              state.todayGreeting,
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.3, color: palette.text),
            ),
            const SizedBox(height: 14),
            if (f1 != null) _TodayCard(fav: f1, comp: _computeFor(f1, state), palette: palette, onTap: () => state.openFavoriteResult(f1)),
            if (f2 != null) ...[
              const SizedBox(height: 8),
              _FavRow(fav: f2, comp: _computeFor(f2, state), palette: palette, onTap: () => state.openFavoriteResult(f2)),
            ],
            const Spacer(),
            OutlineButton(text: '다른 노선 찾기', onTap: state.goHome, palette: palette),
          ],
        ),
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final w = weekdays[now.weekday - 1];
    return '${now.month}월 ${now.day}일 $w · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _TodayCard extends StatelessWidget {
  final Favorite fav;
  final SeatComputation comp;
  final AppPalette palette;
  final VoidCallback onTap;

  const _TodayCard({required this.fav, required this.comp, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final adv = comp.advice;
    final modeWord = comp.mode == SunMode.shade ? '그늘' : '볕';
    return Material(
      color: palette.primary,
      borderRadius: BorderRadius.circular(AppRadius.cardLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Tag(text: fav.label, palette: palette),
                  const SizedBox(width: 9),
                  Text(fav.routeNo, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, color: palette.onPrimary)),
                  const Spacer(),
                  Text(
                    '${fav.from} → ${fav.to}',
                    style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.onPrimary.withOpacity(.85)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  DirectionArrow(pointLeft: adv.leftSeat, color: palette.onPrimary, size: 46),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${adv.sideLabel} 창가에\n앉으세요',
                          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.2, color: palette.onPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '이동 중 ${adv.pct}% $modeWord 좋음 · ${comp.durationMin}분',
                          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.onPrimary.withOpacity(.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavRow extends StatelessWidget {
  final Favorite fav;
  final SeatComputation comp;
  final AppPalette palette;
  final VoidCallback onTap;

  const _FavRow({required this.fav, required this.comp, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final adv = comp.advice;
    return Material(
      color: palette.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _Tag(text: fav.label, palette: palette),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${fav.routeNo} · ${adv.sideLabel} 창가', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, color: palette.text)),
                    Text('${fav.from} → ${fav.to}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)),
                  ],
                ),
              ),
              Text('${adv.pct}%', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, fontWeight: FontWeight.w800, color: palette.primaryText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _Tag({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w800, color: palette.text)),
    );
  }
}
