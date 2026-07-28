import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One quiet canvas for every route. Decorative gradients belong to branded
/// hero sections, not the whole application background.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}
