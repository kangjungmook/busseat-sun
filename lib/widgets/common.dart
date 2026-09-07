import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 44 높이의 원형 아이콘 버튼 — 뒤로가기/설정 등.
class IconCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final Color? color;

  const IconCircleButton({super.key, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: IconTheme(
            data: IconThemeData(color: color, size: 20),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// 그늘/햇살 · 시스템/라이트/다크 같은 2~3단 pill 토글.
class SegmentedPill extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final AppPalette palette;
  final double height;

  const SegmentedPill({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.palette,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.ease,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: on ? palette.surfaceColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: palette.isDark ? Colors.black.withOpacity(.55) : Colors.black.withOpacity(.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: AppTextStyles.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: on ? palette.text : palette.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SolidButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final AppPalette palette;
  final double height;
  final Widget? icon;

  const SolidButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.palette,
    this.height = kCtaHeight,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: enabled ? palette.primary : palette.subtle,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: AppTextStyles.family,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: enabled ? palette.onPrimary : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final AppPalette palette;
  final double height;
  final Widget? icon;

  const OutlineButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.palette,
    this.height = kCtaHeight,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color: palette.isDark ? Colors.white.withOpacity(.22) : Colors.black.withOpacity(.18),
                width: 2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 7)],
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final AppPalette palette;

  const GhostButton({super.key, required this.text, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: palette.textMuted),
        child: Text(
          text,
          style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 15, fontWeight: FontWeight.w700, color: palette.textMuted),
        ),
      ),
    );
  }
}

/// apRise — opacity 0→1, translateY 16→0.
class RiseIn extends StatelessWidget {
  final Widget child;
  final bool play;
  final Duration duration;

  const RiseIn({super.key, required this.child, required this.play, this.duration = const Duration(milliseconds: 240)});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: play ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: play ? Offset.zero : const Offset(0, 0.03),
        duration: duration,
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

/// 좌/우를 색만으로 표현하지 않도록 항상 함께 쓰는 방향 화살표.
class DirectionArrow extends StatelessWidget {
  final bool pointLeft;
  final Color color;
  final double size;

  const DirectionArrow({super.key, required this.pointLeft, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
      transform: Matrix4.identity()..scale(pointLeft ? -1.0 : 1.0, 1.0),
      transformAlignment: Alignment.center,
      child: Icon(Icons.arrow_back, color: color, size: size),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const SectionLabel(this.text, {super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
          color: palette.textMuted,
        ),
      ),
    );
  }
}
