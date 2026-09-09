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
            if (state.apiKeysMissing) ...[
              _PreviewNotice(palette: palette, text: state.apiKeysMissingNotice),
              const SizedBox(height: 8),
            ],
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
              child: hasQuery ? _SearchHint(palette: palette, state: state) : _RecentsRow(palette: palette, state: state),
            ),
            const SizedBox(height: 10),
            _Keypad(palette: palette, state: state),
            const SizedBox(height: 9),
            SolidButton(
              text: state.ctaText,
              onTap: state.canSubmitSearch ? state.submitSearch : null,
              palette: palette,
            ),
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
    // 위치를 못 받았으면 그렇다고 말한다. 예전엔 '강남역 11번 출구 근처'와
    // 'GPS ±8m'를 그냥 박아뒀는데, 위치를 켠 적도 없는 사용자에게 정확한 위치를
    // 잡은 것처럼 보였다.
    //
    // 반대로 좌표를 그대로 띄우는 것도(`36.4981, 127.3228`) 정직하긴 해도
    // 읽는 사람에겐 아무 의미가 없다. 카카오 로컬로 받은 지명을 먼저 쓰고,
    // 그게 없으면 가까운 정류장 이름, 그것도 없으면 담백한 문구로 내려간다.
    final label = loc == null
        ? (state.locationLoading ? '위치를 확인하는 중…' : '위치를 확인하려면 탭하세요')
        : state.locationRegionLabel ??
            (state.nearbyStationLabel != null
                ? '${state.nearbyStationLabel!.name} 근처'
                : '현재 위치를 확인했어요');
    final acc = loc == null ? '꺼짐' : loc.accuracyLabel;
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
    final day = state.sun.dayProgress(state.minutes);
    final alt = state.sun.altitudeDeg(state.minutes);
    final fillColor = alt > 0 ? palette.sunDiscColor : palette.surface.grey;  // 고도(도)
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
              '${SunCalc.timeLabel(state.minutes)} · 고도 ${alt.round()}° · ${state.sun.azimuthName(state.minutes)}',
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.text),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Text('일출 ${SunCalc.timeLabel(state.sun.sunriseMin)}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Text('일몰 ${SunCalc.timeLabel(state.sun.sunsetMin)}', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w700, color: palette.textMuted)),
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

/// "가까운 정류장" 캡션. 값은 [AppState.nearbyStationLabel]이 채운다
/// (TAGO 좌표기반 조회 → 실패 시 캐시된 노선 정류장 순).
/// 위치를 아직 안 받았거나 후보가 없으면 조용히 안내 문구로 대체한다.
String _nearbyStationCaption(AppState state) {
  if (state.apiKeysMissing) return '미리보기에서는 조회할 수 없어요';
  if (state.nearbyStationLoading) return '가까운 정류장 찾는 중…';
  if (state.location == null) return '위치 아이콘을 눌러 확인';
  final near = state.nearbyStationLabel;
  if (near == null) return '주변 정류장 정보 없음';
  return '${near.name} · ${near.meters.round()}m';
}

class _RecentsRow extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _RecentsRow({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    // **조회에 성공해서 캐시된 실제 노선만** 보여준다.
    //
    // 예전에는 시드 상수(9401·3401·140)를 띄웠는데 두 가지가 문제였다:
    // TAGO가 서울을 담당하지 않아 검색으로는 절대 나올 수 없는 번호들이었고,
    // 누르면 손으로 적어둔 방위·소요시간으로 계산된 좌석 추천이 실제 결과와
    // 똑같은 화면에 떴다. "3초 안에 알려준다"는 앱에서 그 3초가 지어낸 값이면
    // 사용자는 그걸 믿고 자리를 잡는다.
    final recents = state.routeCache.values.toList().reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('가까운 정류장', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3, color: palette.textMuted)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _nearbyStationCaption(state),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, color: palette.primaryText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('최근 검색한 노선', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3, color: palette.textMuted)),
        const SizedBox(height: 8),
        if (recents.isEmpty)
          Container(
            height: 62,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: Text(
              '번호를 검색하면 여기에 쌓여요',
              style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, color: palette.textMuted),
            ),
          )
        else
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

/// 타이핑 중엔 미리보기 후보를 보여주지 않는다 — 노선번호를 실시간으로
/// 미리 훑으려면 전국 도시를 다 조회해야 해서(TagoBusService.findRouteNationwide)
/// 키 입력마다 부르기엔 너무 무겁다. 대신 검색 버튼을 눌러야 실제로 찾는다.
class _SearchHint extends StatelessWidget {
  final AppPalette palette;
  final AppState state;

  const _SearchHint({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.searching) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary)),
            const SizedBox(width: 9),
            Text('전국에서 ${state.query}번 찾는 중…', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
          ],
        ),
      );
    }
    if (state.searchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
        child: Text(state.searchError!, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, color: palette.textMuted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
      child: Text(
        // 키가 없으면 버튼이 비활성이라, "눌러서 찾아요"는 거짓말이 된다.
        state.apiKeysMissing
            ? '실제 검색은 앱을 설치해야 동작해요.'
            : '아래 검색 버튼을 눌러 전국에서 ${state.query}번을 찾아요.',
        style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, color: palette.textMuted),
      ),
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


/// API 키 없이 돌 때 홈 맨 위에 뜨는 안내 띠.
///
/// 카드를 하나 더 쌓지 않고 위치 바와 같은 결(둥근 subtle 배경)로 맞춘다.
/// 경고색을 쓰지 않는 이유: 사용자가 뭘 잘못한 게 아니라 이 빌드의 성질이라
/// 겁줄 일이 아니다. 대신 본문 색을 써서 읽히게는 한다.
class _PreviewNotice extends StatelessWidget {
  final AppPalette palette;
  final String text;

  const _PreviewNotice({required this.palette, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: palette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
