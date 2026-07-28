import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Canonical application surface: solid, bordered, and shadow-free.
class FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool listItem;

  const FlatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.listItem = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = AppRadius.borderRadius;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: listItem ? BorderRadius.zero : radius,
        border: listItem ? null : Border.all(color: AppColors.border),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: listItem ? BorderRadius.zero : radius,
      child: InkWell(
        borderRadius: listItem ? BorderRadius.zero : radius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
