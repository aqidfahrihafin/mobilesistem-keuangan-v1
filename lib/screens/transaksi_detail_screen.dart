import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/anak.dart';
import '../models/transaksi.dart';
import '../providers/anak_provider.dart';
import '../providers/app_info_provider.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import 'kwitansi_preview_screen.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

const Map<String, String> _metodeLabel = {
  'tunai': 'Tunai',
  'transfer_bank': 'Transfer Bank',
  'midtrans': 'Midtrans',
  'sistem': 'Sistem',
};

/// Short, receipt-friendly labels for the specific Midtrans channel
/// (Transaksi.metodeDetail) - deliberately more compact than
/// MetodeTopup.label ("Virtual Account BRI...", meant for the method
/// picker), matching how a real bank/e-wallet receipt names the channel.
const Map<String, String> _metodeDetailLabel = {
  'bni_va': 'BNI VA',
  'bca_va': 'BCA VA',
  'bri_va': 'BRIVA',
  'qris': 'QRIS',
};

/// The label actually shown on the Metode row - the specific channel when
/// known (e.g. "BRIVA", "QRIS"), falling back to the coarse metode label
/// (e.g. "Midtrans") only when metodeDetail isn't available.
String _metodeDisplay(Transaksi tx) {
  final detail = tx.metodeDetail;
  if (detail != null && _metodeDetailLabel.containsKey(detail)) {
    return _metodeDetailLabel[detail]!;
  }
  return _metodeLabel[tx.metode] ?? tx.metode;
}

/// The "aksi" word driving the hero title ("{aksi} {status}", e.g. "Transfer
/// Berhasil", "Top Up Diproses") - deliberately not just "Transaksi" for
/// every jenis, since a receipt reads more naturally when it names the
/// specific action that happened.
const Map<String, String> _aksiLabel = {
  'transfer_antar_santri': 'Transfer',
  'pembayaran_kantin': 'Pembayaran',
  'pembayaran_tagihan': 'Pembayaran',
  'topup_tunai': 'Top Up',
  'topup_transfer_wali': 'Top Up',
  'penarikan_tunai': 'Penarikan',
  'penyesuaian': 'Penyesuaian',
};

String _statusSuffix(String status) => switch (status) {
  'berhasil' => 'Berhasil',
  'pending' || 'menunggu_verifikasi' => 'Diproses',
  'ditolak' => 'Ditolak',
  'dibatalkan' => 'Dibatalkan',
  _ => status,
};

(IconData, Color, Color) _statusVisual(String status) => switch (status) {
  'berhasil' => (
    Icons.check_rounded,
    const Color(0xFFDCFCE7),
    const Color(0xFF15803D),
  ),
  'pending' || 'menunggu_verifikasi' => (
    Icons.schedule_rounded,
    const Color(0xFFFEF6E7),
    const Color(0xFFB45309),
  ),
  'dibatalkan' => (
    Icons.block_rounded,
    const Color(0xFFF1F2F4),
    const Color(0xFF52525B),
  ),
  _ => (Icons.close_rounded, const Color(0xFFFDECEC), const Color(0xFFB91C1C)),
};

/// The natural-language summary under the hero title - "Dana Masuk/Keluar
/// Rp X ..." naming the counterparty or purpose, so the receipt reads like
/// a real e-wallet/bank confirmation rather than a raw field dump. Only
/// used for a settled (berhasil) transaksi; pending/ditolak/dibatalkan get
/// a status-first sentence instead since "diterima dari" wouldn't be true
/// yet (or ever, if rejected).
String _deskripsi(Transaksi tx) {
  final nominal = formatRupiah(tx.nominal);

  if (tx.status == 'ditolak') {
    return 'Transaksi sebesar $nominal ditolak.';
  }
  if (tx.status == 'dibatalkan') {
    return 'Transaksi sebesar $nominal dibatalkan.';
  }
  if (tx.status == 'pending' || tx.status == 'menunggu_verifikasi') {
    return 'Transaksi sebesar $nominal sedang diproses.';
  }

  final referensi = tx.referensi;

  switch (tx.jenis) {
    case 'transfer_antar_santri':
      if (referensi == null) break;
      return tx.isKredit
          ? 'Dana Masuk $nominal telah diterima dari ${referensi.nama}.'
          : 'Dana Keluar $nominal telah dikirim ke ${referensi.nama}.';
    case 'pembayaran_kantin':
      if (referensi == null) break;
      return 'Dana Keluar $nominal telah dibayarkan ke ${referensi.nama}.';
    case 'pembayaran_tagihan':
      final tagihan = tx.tagihan;
      return tagihan != null
          ? 'Dana Keluar $nominal telah dibayarkan untuk ${tagihan.jenisTagihanNama} - ${tagihan.periodeLabel}.'
          : 'Dana Keluar $nominal telah dibayarkan untuk tagihan.';
    case 'topup_tunai':
    case 'topup_transfer_wali':
      return 'Dana Masuk $nominal telah ditambahkan ke saldo melalui Top Up.';
    case 'penarikan_tunai':
      return 'Dana Keluar $nominal telah ditarik tunai.';
    case 'penyesuaian':
      return tx.isKredit
          ? 'Saldo bertambah $nominal melalui penyesuaian sistem.'
          : 'Saldo berkurang $nominal melalui penyesuaian sistem.';
  }

  return tx.isKredit
      ? 'Dana Masuk $nominal diterima.'
      : 'Dana Keluar $nominal dikirim.';
}

/// Full detail for a single transaksi, styled as a proper bukti transaksi
/// (transaction receipt) - a status-aware hero (icon/title/description all
/// change together for berhasil/pending/ditolak/dibatalkan) plus a rincian
/// card carrying a reference number, matching what a real e-wallet/bank
/// confirmation shows. Read-only (no payment actions here); entered by
/// tapping a row in Home's "Aktivitas Terbaru" or the Transaksi list in
/// Laporan. The AppBar's share icon rasterizes the receipt content (not the
/// AppBar itself) to a PNG and hands it to the OS share sheet - same idea
/// as the web admin's "download QR as image" feature, just via Flutter's
/// own RepaintBoundary instead of a JS DOM-to-canvas library.
class TransaksiDetailScreen extends StatefulWidget {
  final Transaksi transaksi;

  const TransaksiDetailScreen({super.key, required this.transaksi});

  @override
  State<TransaksiDetailScreen> createState() => _TransaksiDetailScreenState();
}

class _TransaksiDetailScreenState extends State<TransaksiDetailScreen> {
  final _shareKey = GlobalKey();
  bool _sharing = false;
  bool _unduhingKwitansi = false;

  Future<void> _unduhKwitansi(int kwitansiId) async {
    if (_unduhingKwitansi) return;
    setState(() => _unduhingKwitansi = true);

    try {
      final api = context.read<WaliApi>();
      final pdf = await api.getKwitansiPdf(kwitansiId);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              KwitansiPreviewScreen(nomor: pdf.nomor, bytes: pdf.bytes),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka kwitansi. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _unduhingKwitansi = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // pixelRatio 3.0 - a crisp, share-worthy resolution regardless of the
      // device's own screen density (matching typical "save as image" output).
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tx = widget.transaksi;
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'transaksi-${tx.id}.png',
            ),
          ],
          text:
              '${jenisTransaksiLabel[tx.jenis] ?? tx.jenis} - ${formatRupiah(tx.nominal)}',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat gambar untuk dibagikan.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaksi;
    final (icon, iconBg, iconFg) = _statusVisual(tx.status);
    // The uuid column (not the auto-increment id) - unguessable, so a
    // reference number shown on a receipt that gets shared externally
    // can't be used to enumerate/probe other transaksi by incrementing it.
    final noReferensi = 'TRX-${tx.uuid}';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _sharing ? null : _share,
            tooltip: 'Bagikan sebagai gambar',
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              RepaintBoundary(
                key: _shareKey,
                // Only the official proof content belongs in the shared
                // image. Page controls such as the PDF download button stay
                // outside this capture boundary.
                child: Container(
                  width: double.infinity,
                  color: _bg,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Small celebratory sparkles around the badge -
                                  // only for a settled (berhasil) transaksi, since
                                  // a "confetti" flourish doesn't fit a pending or
                                  // rejected receipt.
                                  if (tx.status == 'berhasil') ...[
                                    Positioned(
                                      top: 10,
                                      left: 18,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 13,
                                        color: iconFg.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Positioned(
                                      top: 22,
                                      right: 12,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18,
                                        color: iconFg.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 14,
                                      left: 8,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 10,
                                        color: iconFg.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 20,
                                      right: 22,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 9,
                                        color: iconFg.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ],
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(icon, color: iconFg, size: 38),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${_aksiLabel[tx.jenis] ?? 'Transaksi'} ',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _statusSuffix(tx.status),
                                    style: TextStyle(color: iconFg),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                _deskripsi(tx),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9EBEF)),
                        ),
                        child: Column(
                          children: [
                            _row(
                              'Jenis',
                              jenisTransaksiLabel[tx.jenis] ?? tx.jenis,
                              icon: Icons.receipt_long_rounded,
                              iconBg: iconBg,
                              iconFg: iconFg,
                            ),
                            _divider(),
                            // topup_transfer_wali gets a Nominal Transfer/Biaya
                            // Admin/Total Transfer breakdown instead of a single
                            // Nominal row, whenever a fee was actually recorded
                            // for it (see TopupWaliService::settle()) - every
                            // other jenis keeps the plain single-row display.
                            if (tx.jenis == 'topup_transfer_wali' &&
                                tx.biayaMidtrans != null) ...[
                              _row(
                                'Nominal Transfer',
                                formatRupiah(tx.nominal),
                                icon: Icons.account_balance_wallet_rounded,
                                iconBg: iconBg,
                                iconFg: iconFg,
                              ),
                              _divider(),
                              _row(
                                'Biaya Admin',
                                // biayaDitanggungWali == true berarti biayanya
                                // DIBEBANKAN ke wali (wali yang bayar lebih) -
                                // hanya kasus ini yang menampilkan nominalnya.
                                // false/null berarti pesantren yang menanggung,
                                // jadi selalu "Gratis" tanpa embel-embel angka,
                                // konsisten berapa pun biaya_midtrans yang
                                // sebenarnya tercatat di baliknya.
                                (tx.biayaDitanggungWali == true &&
                                        tx.biayaMidtrans! > 0)
                                    ? formatRupiah(tx.biayaMidtrans!)
                                    : 'Gratis',
                                icon: Icons.receipt_rounded,
                                iconBg: iconBg,
                                iconFg: iconFg,
                                valueColor:
                                    (tx.biayaDitanggungWali == true &&
                                        tx.biayaMidtrans! > 0)
                                    ? null
                                    : const Color(0xFF15803D),
                              ),
                              _divider(),
                              _row(
                                'Total Transfer',
                                formatRupiah(
                                  tx.nominal +
                                      ((tx.biayaDitanggungWali == true)
                                          ? tx.biayaMidtrans!
                                          : 0),
                                ),
                                icon: Icons.payments_rounded,
                                iconBg: iconBg,
                                iconFg: iconFg,
                                bold: true,
                                valueColor: iconFg,
                              ),
                            ] else
                              _row(
                                'Nominal',
                                formatRupiah(tx.nominal),
                                icon: Icons.account_balance_wallet_rounded,
                                iconBg: iconBg,
                                iconFg: iconFg,
                                bold: true,
                                valueColor: iconFg,
                              ),
                            _divider(),
                            // Both sides of a transfer antar santri, right in
                            // this card - the reference/kantin single-party
                            // layout below (_ReferensiCard) doesn't fit here
                            // since a transfer genuinely has two santri, not one
                            // counterparty against an implicit "you".
                            if (tx.jenis == 'transfer_antar_santri' &&
                                tx.referensi != null) ...[
                              _DariKeTimeline(
                                self: context.watch<AnakProvider>().selected,
                                other: tx.referensi!,
                                selfIsPengirim: !tx.isKredit,
                                iconBg: iconBg,
                                iconFg: iconFg,
                              ),
                              _divider(),
                            ],
                            _row(
                              'Tanggal & Waktu',
                              formatTanggalWaktu(tx.createdAt),
                              icon: Icons.calendar_today_rounded,
                              iconBg: iconBg,
                              iconFg: iconFg,
                            ),
                            _divider(),
                            _row(
                              'Metode',
                              _metodeDisplay(tx),
                              icon: Icons.credit_card_rounded,
                              iconBg: iconBg,
                              iconFg: iconFg,
                            ),
                            _divider(),
                            _row(
                              'No. Referensi',
                              noReferensi,
                              icon: Icons.tag_rounded,
                              iconBg: iconBg,
                              iconFg: iconFg,
                            ),
                            if (tx.catatan != null &&
                                tx.catatan!.isNotEmpty) ...[
                              _divider(),
                              _row(
                                'Catatan',
                                tx.catatan!,
                                icon: Icons.notes_rounded,
                                iconBg: iconBg,
                                iconFg: iconFg,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Only for kantin (single counterparty) - a transfer's two
                      // parties are already shown inline above via _DariKeTimeline.
                      if (tx.referensi != null &&
                          tx.jenis != 'transfer_antar_santri') ...[
                        const SizedBox(height: 16),
                        _ReferensiCard(tx: tx),
                      ],
                      if (tx.tagihan != null) ...[
                        const SizedBox(height: 16),
                        _TagihanRingkasCard(tagihan: tx.tagihan!),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9EBEF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: _teal,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bukti Transaksi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Dibuat otomatis oleh sistem '
                                    '${context.watch<AppInfoProvider>().namaAplikasi ?? 'E-Mall Annuqayah'}.',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.workspace_premium_outlined,
                              size: 30,
                              color: _teal.withValues(alpha: 0.25),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tx.kwitansiId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _unduhingKwitansi
                          ? null
                          : () => _unduhKwitansi(tx.kwitansiId!),
                      icon: _unduhingKwitansi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Unduh Kwitansi Resmi (PDF)'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Both sides of a transfer antar santri - "self" (the santri whose ledger
/// this Transaksi belongs to, from AnakProvider - not carried on the
/// Transaksi payload itself since the API already scopes the list to one
/// santri) and "other" (Transaksi.referensi, the sibling on the other end).
/// [selfIsPengirim] follows Transaksi.arah: a debit means money left self
/// for other (self = Dari, other = Ke); a kredit means the reverse.
class _DariKeTimeline extends StatelessWidget {
  final Anak? self;
  final TransaksiReferensi other;
  final bool selfIsPengirim;
  final Color iconBg;
  final Color iconFg;

  const _DariKeTimeline({
    required this.self,
    required this.other,
    required this.selfIsPengirim,
    required this.iconBg,
    required this.iconFg,
  });

  @override
  Widget build(BuildContext context) {
    final selfNama = self?.nama ?? 'Anda';
    final selfNis = self?.nis;
    final selfLembaga = self?.lembaga;

    return Column(
      children: [
        _party(
          label: 'Dari (Pengirim)',
          nama: selfIsPengirim ? selfNama : other.nama,
          nis: selfIsPengirim ? selfNis : other.nis,
          lembaga: selfIsPengirim ? selfLembaga : null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              SizedBox(
                width: 2,
                height: 22,
                child: DecoratedBox(decoration: BoxDecoration(color: iconBg)),
              ),
              const SizedBox(width: 13),
              Icon(Icons.arrow_downward_rounded, size: 16, color: iconFg),
            ],
          ),
        ),
        _party(
          label: 'Ke (Penerima)',
          nama: selfIsPengirim ? other.nama : selfNama,
          nis: selfIsPengirim ? other.nis : selfNis,
          lembaga: selfIsPengirim ? null : selfLembaga,
        ),
      ],
    );
  }

  Widget _party({
    required String label,
    required String nama,
    String? nis,
    String? lembaga,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: 14, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                nama,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              if (nis != null) ...[
                const SizedBox(height: 2),
                Text(
                  nis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
              // "Santri" is the only role a transfer counterparty can have
              // in this app (see TransferController) - the lembaga (if
              // known - only for self, TransaksiReferensi doesn't carry
              // one) is the useful part to show, not a role label that
              // never actually varies.
              if (lembaga != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Santri • $lembaga',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Widget _divider() => const Divider(height: 20, color: Color(0xFFE9EBEF));

Widget _row(
  String label,
  String value, {
  IconData? icon,
  Color? iconBg,
  Color? iconFg,
  bool bold = false,
  Color? valueColor,
}) {
  return Row(
    children: [
      if (icon != null) ...[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: iconFg),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ),
      const SizedBox(width: 12),
      // Expanded (not Flexible/loose) - a loose-fit box shrink-wraps to the
      // value text's own width, which leaves textAlign.right nothing to
      // align *within* (the box IS the text), so short values like "Rp
      // 5.000" ended up sitting immediately after the label instead of
      // flush against the row's right edge. Expanded forces the box to
      // actually fill its share of the row, so the text has room to align
      // right inside it.
      Expanded(
        flex: 2,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 13.5,
            color: valueColor,
          ),
        ),
      ),
    ],
  );
}

/// The counterparty box - who a kantin payment went to, or which santri a
/// transfer moved money to/from. "Ke"/"Dari" is picked by [Transaksi.arah]:
/// debit means the money left this santri *for* the other party, kredit
/// means it arrived *from* them.
class _ReferensiCard extends StatelessWidget {
  final Transaksi tx;

  const _ReferensiCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final referensi = tx.referensi!;
    final isUnitUsaha = referensi.isUnitUsaha;
    final label = isUnitUsaha ? 'Kantin' : (tx.isKredit ? 'Dari' : 'Ke');

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Stack(
        children: [
          // A quiet decorative watermark, not a real illustration asset -
          // just enough visual weight on this card to stop it reading as a
          // plain data row, matching the "counterparty" cards on real
          // e-wallet receipts without pulling in an image dependency.
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(
              isUnitUsaha
                  ? Icons.storefront_rounded
                  : Icons.diversity_3_rounded,
              size: 92,
              color: _teal.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isUnitUsaha
                        ? Icons.storefront_rounded
                        : Icons.person_rounded,
                    color: _teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        referensi.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (referensi.nis != null || referensi.kode != null)
                        Text(
                          referensi.nis ?? referensi.kode!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The linked tagihan's own breakdown - shown for pembayaran_tagihan rows
/// so a wali can see what bill this payment settled without leaving the
/// screen, same info TagihanTab's card already surfaces.
class _TagihanRingkasCard extends StatelessWidget {
  final TagihanRingkas tagihan;

  const _TagihanRingkasCard({required this.tagihan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                'Tagihan Terkait',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${tagihan.jenisTagihanNama} • ${tagihan.periodeLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (tagihan.sedangDicicil) ...[
            const SizedBox(height: 10),
            _row('Terbayar', formatRupiah(tagihan.nominalTerbayar)),
            const SizedBox(height: 6),
            _row('Sisa', formatRupiah(tagihan.sisa), bold: true),
          ],
        ],
      ),
    );
  }
}
