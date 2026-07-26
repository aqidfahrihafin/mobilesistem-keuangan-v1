import 'package:flutter/material.dart';

const _teal = Color(0xFF0F766E);

/// The scanner "target box" overlay drawn over the camera preview - 4
/// L-shaped corner brackets (instead of a plain bordered square) plus a
/// slow teal scan-line sweep. Corners stay white for contrast against
/// whatever the camera happens to be pointed at (a colored bracket would
/// wash out against a busy background); the scan-line carries the one
/// branded teal accent.
class QrScannerFrame extends StatefulWidget {
  final double size;

  const QrScannerFrame({super.key, this.size = 240});

  @override
  State<QrScannerFrame> createState() => _QrScannerFrameState();
}

class _QrScannerFrameState extends State<QrScannerFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CornerBracketPainter(),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: 14 + (widget.size - 28) * _controller.value,
                left: 14,
                right: 14,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        _teal.withValues(alpha: 0),
                        _teal.withValues(alpha: 0.9),
                        _teal.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: _teal.withValues(alpha: 0.7), blurRadius: 6),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    const radius = 18.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(arm, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - arm, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, arm),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - arm)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(arm, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - arm, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
        ..lineTo(size.width, size.height - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
