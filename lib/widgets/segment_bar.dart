import 'package:flutter/material.dart';

import '../logic/seat_advice.dart';
import '../theme/tokens.dart';

const List<int> kSegWeightsUi = [14, 22, 9, 26, 11, 18];

/// 구간별 일사 6분할 막대 — 300ms 좌→우 채움 애니메이션.
class SegmentBar extends StatefulWidget {
  final List<SegKind> segments;
  final AppPalette palette;
  final double height;

  const SegmentBar({super.key, required this.segments, required this.palette, this.height = 36});

  @override
  State<SegmentBar> createState() => _SegmentBarState();
}

class _SegmentBarState extends State<SegmentBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant SegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color _colorFor(SegKind k) {
    final p = widget.palette;
    switch (k) {
      case SegKind.shade:
        return p.primary;
      case SegKind.sun:
        return p.sunDiscColor;
      case SegKind.under:
        return p.surface.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: widget.height,
        color: p.subtle,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: Curves.easeOut.transform(_c.value),
                child: child,
              ),
            );
          },
          child: Row(
            children: List.generate(widget.segments.length, (i) {
              final k = widget.segments[i];
              return Expanded(
                flex: kSegWeightsUi[i],
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: _colorFor(k),
                    border: i < widget.segments.length - 1 ? Border(right: BorderSide(color: p.surfaceColor, width: 2)) : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class SegmentLegend extends StatelessWidget {
  final AppPalette palette;

  const SegmentLegend({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    TextStyle style() => TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, color: palette.textMuted);
    return Row(
      children: [
        dot(palette.primary),
        const SizedBox(width: 5),
        Text('그늘', style: style()),
        const SizedBox(width: 13),
        dot(palette.sunDiscColor),
        const SizedBox(width: 5),
        Text('햇빛', style: style()),
        const SizedBox(width: 13),
        dot(palette.surface.grey),
        const SizedBox(width: 5),
        Text('지하·터널', style: style()),
      ],
    );
  }
}
