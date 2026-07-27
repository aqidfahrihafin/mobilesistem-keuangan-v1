import 'package:flutter/material.dart';

/// Thin border instead of a drop shadow - the "flat" look used throughout
/// this app (PayPal-style) instead of Material's default elevated Card.
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
    final radius = BorderRadius.circular(10);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (listItem ? Colors.white : const Color(0xEAF1F8F6)),
        borderRadius: listItem ? BorderRadius.zero : radius,
        border: listItem
            ? null
            : Border.all(color: const Color(0xE6FFFFFF), width: 1.1),
        boxShadow: listItem
            ? null
            : const [
                BoxShadow(
                  color: Color(0x180F3D3A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
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
