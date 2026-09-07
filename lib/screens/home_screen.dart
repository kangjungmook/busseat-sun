import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/sun_calc.dart';
import '../models/route.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/common.dart';
import '../widgets/sun_arc_painter.dart';

class HomeScreen extends StatelessWidget {
  final AppPalette palette;

  const HomeScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasQuery = state.query.isNotEmpty;
    final matches = state.matches;
    final showFavs = !hasQuery && state.favorites.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const AppIconMark(size: 26),
                  const SizedBox(width: 8),
                  Text('햇살좌석', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -.4, color: palette.text)),
                  const Spacer(),
                  IconCircleButton(icon: const Icon(Icons.settings_outlined), color: palette.text, onTap: () => state.goto(AppScreen.settings)),
                ],
              ),
            ),
            _LocationBar(palette: palette, state: state),
            const SizedBox(height: 6),
            _SunPanel(palette: palette, state: state),
            const SizedBox(height: 12),
            SegmentedPill(
              labels: const ['그늘', '햇살'],
              selected: state.effectiveMode == SunMode.shade ? 0 : 1,
              onSelect: (i) => state.setMode(i == 0 ? SunMode.shade : SunMode.sun),
              palette: palette,
              height: 46,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                state.seasonAuto ? '${DateTime.now().month}월 · 계절 기본값은 ${state.seasonalDefault == SunMode.shade ? '그늘' : '햇살'} 모드' : '선택한 모드로 계속 보고 있어요',
                style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            _QueryField(palette: palette, state: state),
            if (showFavs) ...[
              const SizedBox(height: 14),
              _FavoritesSection(palette: palette, state: state),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: hasQuery ? _CandidatesList(palette: palette, state: state, matches: matches) : _RecentsRow(palette: palette, state: state),
            ),
            const SizedBox(height: 10),
            _Keypad(palette: palette, state: state),
            const SizedBox(height: 9),
            SolidButton(text: state.ctaText, onTap: matches.isNotEmpty ? state.submitSearch : null, palette: palette),
          ],
        ),
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _LocationBar({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final loc = state.location;
    final label = loc == null ? '강남역 11번 출구 근처' : '현재 위치 (${loc.lat.toStringAsFixed(4)}, ${loc.lon.toStringAsFixed(4)})';
    final acc = loc == null ? '±8m' : loc.accuracyLabel;
    return GestureDetector(
      onTap: state.refreshLocation,
      child: Container(
        height: 34,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: kLocationBlue, shape: BoxShape.circle),
              child: const Icon(Icons.location_on, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.text)),
            ),
            Text('GPS $acc', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SunPanel extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _SunPanel({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final day = SunCalc.dayProgress(state.minutes);
    final alt = SunCalc.altitude(state.minutes);
    final fillColor = alt > 0.02 ? palette.sunDiscColor : palette.surface.grey;
    return Container(
      height: 92,
      decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(20), boxShadow: [palette.cardShadow]),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SunArcPainter(
                dayProgress: day,
                trackColor: palette.isDark ? Colors.white.withOpacity(.16) : Colors.black.withOpacity(.13),
                fillColor: fillColor,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 12,
            child: Text(
              '${SunCalc.timeLabel(state.minutes)} · 고도 ${(alt * 62).round()}° · ${SunCalc.azimuthName(state.minutes)}',
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.text),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Text('일출 05:58', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Text('일몰 19:04', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _QueryField extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _QueryField({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final hasQuery = state.query.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasQuery ? palette.primary : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasQuery ? state.query : '번호 입력',
              style: TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: hasQuery ? palette.text : palette.textMuted,
              ),
            ),
          ),
          if (hasQuery) IconCircleButton(icon: const Icon(Icons.close, size: 16), color: palette.textMuted, onTap: state.clearQuery),
        ],
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _FavoritesSection({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('즐겨찾는 노선', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3, color: palette.textMuted)),
            Text('탭하면 바로 결과', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.primaryText)),
          ],
        ),
        const SizedBox(height: 8),
        for (final f in state.favorites.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FavoriteRow(fav: f, palette: palette, state: state),
          ),
      ],
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final Favorite fav;
  final AppPalette palette;
  final AppState state;

  const _FavoriteRow({required this.fav, required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => state.openFavoriteResult(fav),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(8)),
                child: Text(fav.label, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w800, color: palette.text)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${fav.routeNo} · ${fav.from} → ${fav.to}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w800, color: palette.text)),
                    Text(fav.to, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentsRow extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _RecentsRow({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final recents = [kSeedRoutes[0], kSeedRoutes[2], kSeedRoutes[4]];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('가까운 정류장', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3, color: palette.textMuted)),
            const SizedBox(width: 6),
            Text('강남역.중앙차로 · 120m', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: palette.primaryText)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final r = recents[i];
              return Material(
                color: palette.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => state.chooseRoute(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.no, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.4, color: palette.text)),
                        Text(r.dirs.first.name, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CandidatesList extends StatelessWidget {
  final AppPalette palette;
  final AppState state;
  final List<BusRoute> matches;

  const _CandidatesList({required this.palette, required this.state, required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
        child: Text('일치하는 노선이 없어요. 번호를 확인해 주세요.', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, color: palette.textMuted)),
      );
    }
    final top = matches.take(3).toList();
    return ListView.separated(
      itemCount: top.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, i) {
        final r = top[i];
        return Material(
          color: palette.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => state.chooseRoute(r),
            child: Container(
              constraints: const BoxConstraints(minHeight: 66),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.line)),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 56),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: r.badgeColor, borderRadius: BorderRadius.circular(9)),
                    child: Text(r.no, style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.dirs.map((d) => d.name).join(' / '), style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w700, color: palette.text)),
                        Text('${r.kind} · ${r.dirs.first.from} ↔ ${r.dirs.first.to}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 15, color: palette.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Keypad extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _Keypad({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final keys = state.keypadKeys;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 7, crossAxisSpacing: 7, mainAxisExtent: 50),
      itemBuilder: (context, i) {
        final k = keys[i];
        final blank = k.isEmpty;
        final isSwitch = k == 'ABC' || k == '123';
        final isBack = k == '⌫';
        return Material(
          color: blank ? Colors.transparent : (isSwitch ? palette.subtle : palette.surfaceColor),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: blank ? null : () => state.tapKey(k),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: blank ? Colors.transparent : palette.line)),
              alignment: Alignment.center,
              child: Text(
                k,
                style: TextStyle(
                  fontFamily: AppTextStyles.family,
                  fontSize: isSwitch ? 14 : (isBack ? 17 : 22),
                  fontWeight: isSwitch ? FontWeight.w800 : FontWeight.w700,
                  color: (isBack || isSwitch) ? palette.textMuted : palette.text,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
