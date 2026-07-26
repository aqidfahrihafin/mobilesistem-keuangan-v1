import 'package:flutter/material.dart';

/// Static metadata for each Core API top up method this app supports -
/// drives both the payment-method picker and the step-by-step "Cara Bayar"
/// tutorial shown once a top up has been created. Kept in one place so the
/// picker list and the tutorial can never drift out of sync with each other.
class MetodeTopup {
  final String kode;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> langkahPembayaran;

  const MetodeTopup({
    required this.kode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.langkahPembayaran,
  });
}

const List<MetodeTopup> daftarMetodeTopup = [
  MetodeTopup(
    kode: 'bni_va',
    label: 'Virtual Account BNI',
    subtitle: 'Transfer via ATM, m-Banking, atau internet banking BNI',
    icon: Icons.account_balance_outlined,
    langkahPembayaran: [
      'Buka aplikasi BNI Mobile Banking, atau kunjungi ATM BNI terdekat.',
      'Pilih menu Transfer, lalu pilih Virtual Account Billing.',
      'Masukkan nomor Virtual Account di atas.',
      'Periksa detail pembayaran yang muncul, lalu konfirmasi.',
      'Simpan bukti transfer sebagai referensi.',
    ],
  ),
  MetodeTopup(
    kode: 'bca_va',
    label: 'Virtual Account BCA',
    subtitle: 'Transfer via ATM, m-BCA, atau KlikBCA',
    icon: Icons.account_balance_outlined,
    langkahPembayaran: [
      'Buka aplikasi BCA mobile (m-BCA), atau kunjungi ATM BCA terdekat.',
      'Pilih menu m-Transfer, lalu pilih BCA Virtual Account.',
      'Masukkan nomor Virtual Account di atas.',
      'Periksa detail pembayaran yang muncul, lalu konfirmasi dengan PIN.',
      'Simpan bukti transfer sebagai referensi.',
    ],
  ),
  MetodeTopup(
    kode: 'bri_va',
    label: 'Virtual Account BRI',
    subtitle: 'Transfer via ATM, BRImo, atau internet banking BRI',
    icon: Icons.account_balance_outlined,
    langkahPembayaran: [
      'Buka aplikasi BRImo, atau kunjungi ATM BRI terdekat.',
      'Pilih menu Pembayaran, lalu pilih BRIVA.',
      'Masukkan nomor Virtual Account di atas.',
      'Periksa detail pembayaran yang muncul, lalu konfirmasi dengan PIN.',
      'Simpan bukti transfer sebagai referensi.',
    ],
  ),
  MetodeTopup(
    kode: 'qris',
    label: 'QRIS',
    subtitle: 'Scan pakai e-wallet atau m-banking apapun',
    icon: Icons.qr_code_rounded,
    langkahPembayaran: [
      'Buka aplikasi m-Banking atau e-wallet yang mendukung QRIS (GoPay, OVO, DANA, ShopeePay, dan lainnya).',
      'Pilih menu Scan QR atau Bayar.',
      'Arahkan kamera ke kode QR di atas.',
      'Periksa nominal yang muncul, lalu konfirmasi pembayaran.',
    ],
  ),
];

MetodeTopup? metodeTopupByKode(String? kode) {
  for (final metode in daftarMetodeTopup) {
    if (metode.kode == kode) return metode;
  }
  return null;
}
