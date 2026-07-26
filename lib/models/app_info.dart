/// App branding fetched from the (public, no-auth) `/wali/app-info`
/// endpoint - lets the mobile app mirror whatever an admin sets on the web
/// side's Pengaturan Aplikasi page (name, pondok name, logo).
class AppInfo {
  final String namaAplikasi;
  final String namaPondok;
  final String? logoUrl;

  AppInfo({required this.namaAplikasi, required this.namaPondok, this.logoUrl});

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      namaAplikasi: json['nama_aplikasi'] as String,
      namaPondok: json['nama_pondok'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}
