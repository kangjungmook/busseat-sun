import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class LoadingScreen extends StatefulWidget {
  final AppPalette palette;

  const LoadingScreen({super.key, required this.palette});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = widget.palette;
    final route = state.currentRoute;
    final dir = state.currentDir;
    final title = route == null || dir == null ? '' : '${route.no} · ${dir.name}';

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
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: state.goHome),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.text)),
                ],
              ),
            ),
            _Skeleton(height: 300, radius: 26, palette: palette, animation: _pulse, delay: 0),
            const SizedBox(height: 12),
            _Skeleton(height: 120, radius: 22, palette: palette, animation: _pulse, delay: .15),
            const SizedBox(height: 26),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary),
                  ),
                  const SizedBox(width: 9),
                  Text('태양 고도 · 건물 그림자 계산 중', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  final double radius;
  final AppPalette palette;
  final Animation<double> animation;
  final double delay;

  const _Skeleton({required this.height, required this.radius, required this.palette, required this.animation, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = (animation.value + delay) % 1.0;
        final opacity = 0.5 - (0.28 * (1 - (t - 0.5).abs() * 2)).clamp(0.0, 0.28);
        return Container(
          height: height,
          decoration: BoxDecoration(color: palette.subtle.withOpacity(opacity.clamp(0.22, 0.5)), borderRadius: BorderRadius.circular(radius)),
        );
      },
    );
  }
}
