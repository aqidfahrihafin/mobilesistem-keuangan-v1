import 'package:flutter/material.dart';

/// One consistent "no data yet" view for every list/section that can be
/// legitimately empty - previously each screen (Home, Tagihan, Laporan,
/// Transfer, ...) had its own icon/wording/layout for this, some without
/// even an icon. Deliberately mirrors `ErrorStateView`'s visual language
/// (same 64px circled icon, same type scale) so the two read as one family:
/// "nothing to show" and "couldn't load" should feel like siblings, not two
/// unrelated designs.
///
/// [compact] renders a smaller, title-less version for space-constrained
/// spots (e.g. a preview card on Home showing at most 3 items) rather than
/// a whole-page/whole-list state.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? title;
  final bool compact;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = compact ? 44.0 : 84.0;
    final iconSize = compact ? 20.0 : 38.0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: compact ? Colors.grey[100] : const Color(0xFFEAF5F3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: iconSize,
                color: compact ? Colors.grey[400] : const Color(0xFF0F766E),
              ),
            ),
            if (!compact) ...[
              const Positioned(
                top: 3,
                right: -5,
                child: _DecorativeDot(size: 14, color: Color(0xFFF4C95D)),
              ),
              const Positioned(
                bottom: 5,
                left: -8,
                child: _DecorativeDot(size: 10, color: Color(0xFF7DD3C7)),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 10 : 18),
        if (!compact) ...[
          Text(
            title ?? 'Belum ada data',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 7),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: compact ? 12 : 13.5,
            height: 1.5,
          ),
        ),
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 8 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 360 : 310),
          child: content,
        ),
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
