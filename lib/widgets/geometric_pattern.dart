import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A faint tiled 8-point star lattice - the pesantren's own visual
/// character on brand-colored surfaces (splash, login hero) instead of a
/// plain flat gradient. Deliberately subtle (low opacity, thin strokes) so
/// it reads as texture, not decoration competing with the logo/text on top.
class GeometricPatternBackground extends StatelessWidget {
  final Color color;
  final double opacity;
  final double tileSize;

  const GeometricPatternBackground({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.08,
    this.tileSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GeometricPatternPainter(
          color: color.withValues(alpha: opacity),
          tileSize: tileSize,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GeometricPatternPainter extends CustomPainter {
  final Color color;
  final double tileSize;

  _GeometricPatternPainter({required this.color, required this.tileSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final center = Offset(col * tileSize, row * tileSize);
        _drawStar(canvas, paint, center, tileSize * 0.42);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double radius) {
    const points = 8;
    final path = Path();

    for (var i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? radius : radius * 0.55;
      final angle = (math.pi / points) * i - math.pi / 2;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GeometricPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tileSize != tileSize;
}
