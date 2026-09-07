import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/sun_calc.dart';
import '../models/route.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// 방면 2개인 노선 선택 시 뜨는 바텀시트.
class DirPickerSheet extends StatelessWidget {
  final AppPalette palette;

  const DirPickerSheet({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = state.currentRoute;
    if (route == null) return const SizedBox.shrink();
    final az = SunCalc.azimuth(state.minutes);

    return Positioned.fill(
      child: GestureDetector(
        onTap: state.closeDirPicker,
        child: Container(
          color: Colors.black.withOpacity(.42),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Transform.translate(offset: Offset(0, t * 120), child: child),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('어느 방면인가요?', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.5, color: palette.text)),
                    const SizedBox(height: 4),
                    Text('방면에 따라 앉을 창가가 반대예요.', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13, color: palette.textMuted)),
                    const SizedBox(height: 16),
                    for (var i = 0; i < route.dirs.length; i++) ...[
                      if (i > 0) const SizedBox(height: 9),
                      _DirRow(route: route, index: i, az: az, palette: palette, state: state),
                    ],
                    GhostButton(text: '닫기', onTap: state.closeDirPicker, palette: palette),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirRow extends StatelessWidget {
  final BusRoute route;
  final int index;
  final double az;
  final AppPalette palette;
  final AppState state;

  const _DirRow({required this.route, required this.index, required this.az, required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    final d = route.dirs[index];
    final rel = ((az - d.bearing) % 360 + 360) % 360;
    final sunRight = rel < 180;
    final leftSeat = state.effectiveMode == SunMode.shade ? sunRight : !sunRight;
    return Material(
      color: palette.subtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => state.pickDir(route, index),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.line)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.name, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -.3, color: palette.text)),
                    const SizedBox(height: 3),
                    Text('${d.from} → ${d.to} · ${d.stopCount}개 정류장', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, color: palette.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: palette.surfaceColor, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: palette.line)),
                child: Text(leftSeat ? '왼쪽 창가' : '오른쪽 창가', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, color: palette.primaryText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
