import 'dart:math';
import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final bool isComplete;
  final bool isPaused;
  final double size;
  final Widget child;

  const CountdownRing({
    super.key,
    required this.progress,
    required this.isComplete,
    required this.isPaused,
    required this.size,
    required this.child,
  });

  Color get _ringColor {
    if (isComplete) return const Color(0xFF00E676);
    if (isPaused) return const Color(0xFF5A6478);
    return const Color(0xFFFFB800);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          ringColor: _ringColor,
          showGlow: !isPaused,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool showGlow;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.showGlow,
  });

  static const _strokeWidth = 16.0;
  static const _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = const Color(0xFF162035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    if (progress <= 0) return;

    final sweep = 2 * pi * progress;

    // Outer glow
    if (showGlow) {
      canvas.drawArc(
        rect,
        _startAngle,
        sweep,
        false,
        Paint()
          ..color = ringColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth + 18
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Main arc
    canvas.drawArc(
      rect,
      _startAngle,
      sweep,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Leading-edge dot for polish (skip at 100%)
    if (progress < 0.995) {
      final endAngle = _startAngle + sweep;
      final dotCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );
      // Glow halo around dot
      canvas.drawCircle(
        dotCenter,
        _strokeWidth / 2 + 4,
        Paint()
          ..color = ringColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Solid dot
      canvas.drawCircle(
        dotCenter,
        _strokeWidth / 2,
        Paint()..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.showGlow != showGlow;
}
