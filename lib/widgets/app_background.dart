import 'package:flutter/material.dart';

/// Latar visual tunggal untuk seluruh aplikasi.
///
/// Scaffold dibuat transparan sehingga setiap halaman mendapatkan kedalaman
/// dari semburat warna ini tanpa perlu menduplikasi dekorasi.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F8F8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FBFC),
                  Color(0xFFF1F8F7),
                  Color(0xFFF7F7FC),
                ],
              ),
            ),
          ),
          const Positioned(
            top: -150,
            right: -110,
            child: _Glow(size: 330, color: Color(0x3372D9CF)),
          ),
          const Positioned(
            top: 260,
            left: -170,
            child: _Glow(size: 360, color: Color(0x247CB7FF)),
          ),
          const Positioned(
            bottom: -170,
            right: -130,
            child: _Glow(size: 380, color: Color(0x21A78BFA)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
