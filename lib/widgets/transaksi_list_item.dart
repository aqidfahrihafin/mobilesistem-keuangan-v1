import 'package:flutter/material.dart';

import '../models/transaksi.dart';
import '../utils/formatters.dart';
import '../utils/metode_topup.dart';

const _hijau = Color(0xFF15803D);
const _merah = Color(0xFFB91C1C);
const _kuning = Color(0xFFB45309);
const _teal = Color(0xFF0F766E);

(IconData, Color) _iconFor(Transaksi tx) => switch (tx.jenis) {
  'topup_tunai' || 'topup_transfer_wali' => (Icons.arrow_downward_rounded, _hijau),
  'pembayaran_kantin' => (Icons.storefront_rounded, _kuning),
  'pembayaran_tagihan' => (Icons.receipt_long_rounded, _merah),
  'penarikan_tunai' => (Icons.arrow_upward_rounded, _merah),
  'transfer_antar_santri' => (Icons.swap_horiz_rounded, _teal),
  _ => (tx.isKredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, Colors.grey),
};

String _subtitleFor(Transaksi tx) {
  switch (tx.jenis) {
    case 'pembayaran_kantin':
      return tx.referensi?.nama ?? 'Kantin';
    case 'transfer_antar_santri':
      final lawan = tx.referensi?.nama;
      if (lawan == null) return 'Transfer antar santri';
      return tx.isKredit ? 'Dari $lawan' : 'Ke $lawan';
    case 'pembayaran_tagihan':
      return tx.tagihan != null
          ? '${tx.tagihan!.jenisTagihanNama} • ${tx.tagihan!.periodeLabel}'
          : 'Pembayaran tagihan';
    case 'topup_tunai':
      return 'Setor tunai';
    case 'topup_transfer_wali':
      return metodeTopupByKode(tx.metodeDetail)?.label ?? 'Transfer wali';
    case 'penarikan_tunai':
      return 'Tunai';
    default:
      return jenisTransaksiLabel[tx.jenis] ?? tx.jenis;
  }
}

String _jam(DateTime dt) {
  final d = dt.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// One transaction row for the flat, borderless, date-grouped list style
/// (Laporan's Transaksi/Pengeluaran sub-tabs, Home's Aktivitas Terbaru) -
/// shared so both stay in sync instead of drifting the way the old
/// _TransaksiCard/_AktivitasPreviewRow pair had started to. Deliberately
/// has no card chrome of its own (no border/background/radius) - callers
/// separate rows with a plain Divider and provide their own section
/// headers, matching the reference design's flat list look.
class TransaksiListItem extends StatelessWidget {
  final Transaksi tx;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Defaults to full 16px horizontal inset for callers rendering this
  /// edge-to-edge (Laporan's own full-width list). A caller that already
  /// sits inside its own horizontally-padded container (Home's Aktivitas
  /// Terbaru, inside the page's 20px padding) should pass horizontal: 0
  /// here instead of double-padding.
  final EdgeInsetsGeometry padding;

  const TransaksiListItem({
    super.key,
    required this.tx,
    this.onTap,
    this.showChevron = true,
    this.padding = const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _iconFor(tx);
    final amountColor = tx.isKredit ? _hijau : _merah;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jenisTransaksiLabel[tx.jenis] ?? tx.jenis,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleFor(tx),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.isKredit ? '+' : '-'}${formatRupiah(tx.nominal)}',
                  style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _jam(tx.createdAt),
                  style: TextStyle(color: Colors.grey[400], fontSize: 10.5),
                ),
              ],
            ),
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }
}
