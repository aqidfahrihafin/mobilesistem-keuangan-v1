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
    final iconBoxSize = compact ? 44.0 : 64.0;
    final iconSize = compact ? 20.0 : 30.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: compact ? 8 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: iconSize, color: Colors.grey[400]),
            ),
            SizedBox(height: compact ? 10 : 16),
            if (!compact && title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: compact ? 12 : (title != null ? 12.5 : 13),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
