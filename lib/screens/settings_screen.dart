import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  final AppPalette palette;

  const SettingsScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: state.goHome),
                  const SizedBox(width: 6),
                  Text('설정', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.8, color: palette.text)),
                ],
              ),
            ),
            SectionLabel('계정', palette: palette),
            Container(
              decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      children: [
                        Container(width: 26, height: 26, decoration: const BoxDecoration(color: kKakaoYellow, shape: BoxShape.circle), child: const Icon(Icons.chat_bubble, color: kKakaoInk, size: 14)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.user != null ? '카카오 계정으로 로그인' : '로그인하지 않음', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text)),
                              Text(
                                state.user != null ? '즐겨찾기 ${state.favorites.length}개 동기화 중' : '즐겨찾기가 이 기기에만 저장돼요',
                                style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: palette.line),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (state.user != null) {
                          await state.logout();
                        } else {
                          final err = await state.loginWithKakao();
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Expanded(child: Text(state.user != null ? '로그아웃' : '카카오로 로그인', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textMuted))),
                            Icon(Icons.chevron_right, size: 15, color: palette.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SectionLabel('기본 모드', palette: palette),
            SegmentedPill(
              labels: const ['계절 자동', '그늘', '햇살'],
              selected: state.seasonAuto ? 0 : (state.modeOverride == SunMode.shade ? 1 : 2),
              onSelect: (i) {
                if (i == 0) {
                  state.setSeasonAuto();
                } else {
                  state.setMode(i == 1 ? SunMode.shade : SunMode.sun);
                }
              },
              palette: palette,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                state.seasonAuto ? '4~10월은 그늘 모드, 11~3월은 햇살 모드로 자동 전환돼요.' : '선택한 모드로 항상 시작해요.',
                style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted),
              ),
            ),
            SectionLabel('화면 테마', palette: palette),
            SegmentedPill(
              labels: const ['시스템', '라이트', '다크'],
              selected: state.themePref.index,
              onSelect: (i) => state.setThemePref(AppThemePref.values[i]),
              palette: palette,
            ),
            SectionLabel('동작', palette: palette),
            Container(
              decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  _SwitchRow(title: '정류장 도착 알림', subtitle: '탑승 3분 전에 좌석 안내를 다시 띄워요', value: state.switches[0], onTap: () => state.toggleSwitch(0), palette: palette),
                  Container(height: 1, color: palette.line),
                  _SwitchRow(title: '앱 켤 때 번호판 자동 열기', subtitle: '실행 즉시 숫자 키패드에 포커스', value: state.switches[1], onTap: () => state.toggleSwitch(1), palette: palette),
                  Container(height: 1, color: palette.line),
                  _SwitchRow(title: '계산 근거 자세히 보기', subtitle: '태양 고도·건물 높이 값을 함께 표시', value: state.switches[2], onTap: () => state.toggleSwitch(2), palette: palette),
                ],
              ),
            ),
            SectionLabel('위젯', palette: palette),
            Material(
              color: palette.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => state.goto(AppScreen.widget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Expanded(child: Text('위젯 미리보기', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text))),
                      Icon(Icons.chevron_right, size: 15, color: palette.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            SectionLabel('데이터 출처', palette: palette),
            Container(
              decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  // 실제로 쓰는 것만 적는다. 예전에는 기상청 단기예보,
                  // 서울 TOPIS, 국토지리정보원 수치표고가 적혀 있었는데
                  // 셋 다 부르지 않는다 (TOPIS는 서울 지원 때 붙일 예정).
                  _SourceRow(k: '노선·정류장', v: '국토교통부 TAGO', palette: palette),
                  Container(height: 1, color: palette.line),
                  _SourceRow(k: '위치·지명', v: '카카오 로컬', palette: palette),
                  Container(height: 1, color: palette.line),
                  _SourceRow(k: '태양 위치', v: 'NOAA 계산식 (앱 내 계산)', palette: palette),
                ],
              ),
            ),
            SectionLabel('개발자용', palette: palette),
            Material(
              color: palette.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => state.goto(AppScreen.tagoDebug),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Expanded(child: Text('TAGO API 테스트', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text))),
                      Icon(Icons.chevron_right, size: 15, color: palette.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('햇살좌석 v1.2.0 · 좌석 데이터 09-07', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, color: palette.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;
  final AppPalette palette;

  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text)),
                    Text(subtitle, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: (_) => onTap(), activeColor: palette.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String k;
  final String v;
  final AppPalette palette;

  const _SourceRow({required this.k, required this.v, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(k, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text)),
                Text(v, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11.5, color: palette.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 15, color: palette.textMuted),
        ],
      ),
    );
  }
}
