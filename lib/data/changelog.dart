class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}

/// Newest first. Append a new entry here with each release so "Versi
/// Aplikasi" in Profil always reflects what actually shipped - there's no
/// backend changelog endpoint, this list is the source of truth.
const changelog = <ChangelogEntry>[
  ChangelogEntry(
    version: '1.1.13',
    date: 'Agustus 2026',
    changes: [
      'Login sidik jari kini terbuka otomatis pada halaman PIN saat fitur biometrik aktif.',
      'Tampilan nominal Top Up, Setor Tabungan, dan Transfer Saldo dibuat lebih terstruktur.',
      'Pusat notifikasi tetap menampilkan isi pesan ketika data asal sudah tidak tersedia.',
      'Tampilan data kosong, Semua Layanan, Tentang Aplikasi, Versi, dan Pusat Bantuan diperbarui.',
    ],
  ),
  ChangelogEntry(
    version: '1.1.1',
    date: 'Juli 2026',
    changes: [
      'Detail tagihan lunas kini menampilkan informasi pembayaran yang lebih lengkap.',
      'Unduhan QRIS kini berisi QR, nominal, status, masa berlaku, dan ID pembayaran.',
    ],
  ),
  ChangelogEntry(
    version: '1.1.0',
    date: 'Juli 2026',
    changes: [
      'Halaman detail dan alur pembayaran tagihan kini tersedia dalam satu proses terpusat.',
      'QRIS pembayaran Top Up dan tagihan kini dapat disimpan langsung ke galeri.',
      'Login atau unlock dengan sidik jari selalu kembali ke halaman Beranda.',
      'Optimasi render modal, gambar jaringan, polling, dan dependency agar aplikasi lebih ringan.',
    ],
  ),
  ChangelogEntry(
    version: '1.0.0',
    date: 'Juli 2026',
    changes: [
      'Pantau saldo santri secara real-time, lengkap dengan info batas minimum saldo.',
      'Bayar tagihan dari saldo atau langsung via transfer bank (VA) dan QRIS.',
      'Dukungan cicilan untuk jenis tagihan yang mengizinkan pembayaran bertahap.',
      'Top up saldo santri kapan saja lewat VA atau QRIS.',
      'Kwitansi pembayaran resmi bernomor, siap diunduh sebagai PDF.',
      'Login dengan sidik jari dan sesi terkunci otomatis saat tidak aktif.',
      'Menu Laporan: rincian Transaksi, Pengeluaran, dan ringkasan yang bisa diunduh sebagai evaluasi.',
      'Filter periode dan jenis transaksi di halaman Tagihan dan Laporan.',
      'Pengingat visual untuk tagihan yang mendekati atau sudah lewat jatuh tempo.',
    ],
  ),
];
