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
