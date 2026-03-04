import 'package:flutter/material.dart';

/// Habit Vector brand logo rendered as a CustomPainter.
/// Depicts an upward vector arrow with accent dots, inside a subtle circle.
class HabitVectorLogo extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final bool showBackground;

  const HabitVectorLogo({
    super.key,
    this.size = 120,
    this.primaryColor,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _HabitVectorLogoPainter(
        primaryColor: color,
        showBackground: showBackground,
      ),
    );
  }
}

class _HabitVectorLogoPainter extends CustomPainter {
  final Color primaryColor;
  final bool showBackground;

  _HabitVectorLogoPainter({
    required this.primaryColor,
    required this.showBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    // Background circle
    if (showBackground) {
      final bgPaint = Paint()
        ..color = primaryColor.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), s * 0.47, bgPaint);
    }

    // Arrow shaft
    final shaftPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = s * 0.062
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shaftStart = Offset(cx, s * 0.78);
    final shaftEnd = Offset(cx, s * 0.23);
    canvas.drawLine(shaftStart, shaftEnd, shaftPaint);

    // Arrowhead
    final headPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = s * 0.062
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final headPath = Path()
      ..moveTo(s * 0.34, s * 0.39)
      ..lineTo(cx, s * 0.23)
      ..lineTo(s * 0.66, s * 0.39);
    canvas.drawPath(headPath, headPaint);

    // Accent dots (progress indicators)
    final greenDot = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.35, s * 0.66), s * 0.031, greenDot);

    final purpleDot = Paint()
      ..color = const Color(0xFF818CF8).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.65, s * 0.58), s * 0.023, purpleDot);

    final amberDot = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.35, s * 0.51), s * 0.019, amberDot);
  }

  @override
  bool shouldRepaint(covariant _HabitVectorLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.showBackground != showBackground;
  }
}
