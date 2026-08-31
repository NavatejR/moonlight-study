import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// A steamed-coffee-logo placeholder shown until the AI is wired.
class CoffeeMugIcon extends StatelessWidget {
  const CoffeeMugIcon({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? CoffeeColors.caramel;
    return CustomPaint(
      size: Size.square(size),
      painter: _MugPainter(c),
    );
  }
}

class _MugPainter extends CustomPainter {
  _MugPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..color = color;

    final body = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.45,
      size.height * 0.4,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(6)), stroke);

    // Handle
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.6,
        size.height * 0.38,
        size.width * 0.25,
        size.height * 0.22,
      ),
      0,
      3.14159,
      false,
      stroke,
    );

    // Steam
    final steam = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final dx in [0.3, 0.5]) {
      canvas.drawLine(
        Offset(size.width * dx, size.height * 0.24),
        Offset(size.width * dx, size.height * 0.16),
        steam,
      );
    }
  }

  @override
  bool shouldRepaint(_MugPainter oldDelegate) => oldDelegate.color != color;
}