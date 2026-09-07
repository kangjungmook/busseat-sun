import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/sun_calc.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class NightScreen extends StatelessWidget {
  final AppPalette palette;

  const NightScreen({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timeLabel = SunCalc.timeLabel(state.minutes);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 44, child: IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: state.goHome)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(24)),
                    child: Icon(Icons.nightlight_round, size: 38, color: palette.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text('지금은 계산할 수 없어요', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 29, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -1.1, color: palette.text)),
                  const SizedBox(height: 16),
                  Text(
                    '선택한 시각($timeLabel)은 일출 전이거나 일몰 후예요. 햇빛 방향이 없으니 좌석 추천도 의미가 없어요.',
                    style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, color: palette.textMuted, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: palette.text,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: state.useDaytime,
                        child: Center(
                          child: Text('주간(16:12) 기준으로 보기', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 16.5, fontWeight: FontWeight.w800, color: palette.background)),
                        ),
                      ),
                    ),
                  ),
                  GhostButton(text: '다시 검색', onTap: state.goHome, palette: palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
