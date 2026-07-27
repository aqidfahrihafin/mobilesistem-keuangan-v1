import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banner_item.dart';
import '../providers/banner_provider.dart';

const _teal = Color(0xFF0F766E);
const _bannerHeight = 100.0;

/// Home tab promo/announcement carousel, admin-managed via "Banner Beranda"
/// on the web side (pengumuman, ajakan donasi/hibah wali, dll). Deliberately
/// renders nothing when there are no active banners, so Home's layout is
/// unaffected either way - no reserved empty space waiting for content that
/// may never come.
///
/// Exactly one active banner shows full-width; two or more show a "peeking"
/// carousel (the next card partially visible at the right edge) with dot
/// indicators below, matching a typical bank-app promo strip rather than a
/// full-bleed single slide once there's more than one to cycle through.
class BannerCarousel extends StatelessWidget {
  const BannerCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = context.watch<BannerProvider>().banners;

    // No active banner - collapses to nothing (not even reserved spacing),
    // so Home's layout is pixel-identical to before this feature existed.
    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: banners.length == 1
          ? _BannerCard(banner: banners.first)
          : _BannerPeekCarousel(banners: banners),
    );
  }
}

class _BannerPeekCarousel extends StatefulWidget {
  final List<BannerItem> banners;

  const _BannerPeekCarousel({required this.banners});

  @override
  State<_BannerPeekCarousel> createState() => _BannerPeekCarouselState();
}

class _BannerPeekCarouselState extends State<_BannerPeekCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.page?.round() ?? 0;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: _bannerHeight,
          child: PageView.builder(
            controller: _controller,
            // false - keeps the first card flush against the row's left
            // edge (matching every other section on Home) instead of
            // PageView's default of centering each page, which would add a
            // leading gap before the very first banner too.
            padEnds: false,
            itemCount: widget.banners.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == widget.banners.length - 1 ? 0 : 10,
              ),
              child: _BannerCard(banner: widget.banners[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? _teal : const Color(0xFFD8DBE2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F2F4),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: banner.linkUrl == null ? null : () => _openLink(banner.linkUrl!),
        child: SizedBox(
          height: _bannerHeight,
          width: double.infinity,
          child: Image.network(
            banner.gambarUrl,
            fit: BoxFit.cover,
            cacheHeight: 300,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort - a broken/malformed admin-entered link shouldn't crash
      // the tap, just silently does nothing.
    }
  }
}
