import 'package:flutter/material.dart';

/// A rounded box with a sweeping shimmer highlight - the "modern" loading
/// placeholder used in place of a bare spinner wherever a screen is waiting
/// on a list/card shaped response, so the layout that's about to appear is
/// hinted at instead of just a centered circle. Falls back to a flat
/// (non-animated) box when the platform/user has reduced motion on.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = const Color(0xFFE9EBEF);

    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: widget.borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            height: widget.height,
            color: base,
            child: FractionallySizedBox(
              widthFactor: 2.4,
              alignment: Alignment(_controller.value * 4 - 2, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      base,
                      const Color(0xFFF6F7F9),
                      base,
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for a full-width card-shaped list row (Tagihan/Transaksi/
/// Laporan lists all share roughly this shape: an icon circle, two lines
/// of text, and a trailing value).
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Row(
        children: [
          const ShimmerBox(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 90, height: 11),
              ],
            ),
          ),
          const ShimmerBox(width: 64, height: 13),
        ],
      ),
    );
  }
}

/// A short vertical stack of [SkeletonListRow]s - drop-in replacement for a
/// centered spinner while a list-shaped request is in flight.
class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: List.generate(count, (_) => const SkeletonListRow()),
    );
  }
}

/// Compact rows matching Home's "Tagihan Terbaru"/"Aktivitas Terbaru"
/// preview cards - same FlatCard chrome (white, rounded, bordered) so the
/// skeleton doesn't visually pop when the real data swaps in.
class SkeletonPreviewCard extends StatelessWidget {
  final int rows;

  const SkeletonPreviewCard({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Column(
        children: List.generate(rows, (index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: index == rows - 1
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xFFE9EBEF))),
            ),
            child: Row(
              children: [
                const ShimmerBox(
                  width: 32,
                  height: 32,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 120, height: 12),
                      SizedBox(height: 7),
                      ShimmerBox(width: 70, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 56, height: 12),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Full-page placeholder for Home's initial anak-load - mirrors the hero
/// header + balance card + stat-tile row shape instead of one centered
/// spinner, so the eventual layout doesn't "pop in" from nothing.
class SkeletonHomePage extends StatelessWidget {
  const SkeletonHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
          child: Container(
            height: 210,
            color: const Color(0xFFE9EBEF),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EBEF)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 110, height: 12),
                SizedBox(height: 14),
                ShimmerBox(width: 160, height: 26),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
                  child: const ShimmerBox(height: 76),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
