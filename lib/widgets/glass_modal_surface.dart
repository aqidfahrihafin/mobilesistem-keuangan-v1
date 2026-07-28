import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared solid surface for dialogs and bottom sheets.
class GlassModalSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const GlassModalSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: AppRadius.radius),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
