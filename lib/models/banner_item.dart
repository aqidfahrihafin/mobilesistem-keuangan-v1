/// A single Home tab promo/announcement banner, fetched from the (public,
/// no-auth) `/wali/banners` endpoint - admin-managed under Banner Beranda.
class BannerItem {
  final int id;
  final String judul;
  final String gambarUrl;
  final String? linkUrl;

  BannerItem({
    required this.id,
    required this.judul,
    required this.gambarUrl,
    this.linkUrl,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'] as int,
      judul: json['judul'] as String,
      gambarUrl: json['gambar_url'] as String,
      linkUrl: json['link_url'] as String?,
    );
  }
}
