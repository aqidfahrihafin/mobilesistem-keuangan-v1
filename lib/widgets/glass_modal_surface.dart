import 'dart:ui';

import 'package:flutter/material.dart';

/// Permukaan kaca untuk dialog dan bottom sheet.
///
/// Opasitasnya cukup tinggi untuk menjaga keterbacaan, sementara blur,
/// border, dan shadow memberi pemisahan yang tegas dari halaman di belakang.
class GlassModalSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const GlassModalSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(26)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6F1F8F6),
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x240F3D3A),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
