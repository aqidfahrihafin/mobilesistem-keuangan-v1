import 'package:flutter/material.dart';

/// Permukaan kaca untuk dialog dan bottom sheet.
///
/// Uses an opaque surface instead of a live backdrop blur. This keeps modal
/// scrolling smooth on lower-end devices while preserving visual separation.
class GlassModalSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const GlassModalSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F7),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
