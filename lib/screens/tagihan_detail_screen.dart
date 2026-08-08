import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/jatuh_tempo.dart';
import '../widgets/status_badge.dart';
import '../widgets/tagihan_bayar_flow.dart';
import 'kwitansi_preview_screen.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Full detail for a single tagihan, on its own page - same rincian
/// content _TagihanCard already shows inline (expanded), plus the real
/// Bayar/Cetak actions via the shared [bayarTagihanFlow]/[cetakTagihanFlow]
/// (also used by TagihanTab, so both entry points share one payment path).
/// Entered by tapping a tagihan preview on Home.
class TagihanDetailScreen extends StatefulWidget {
  final Anak anak;
  final Tagihan tagihan;

  const TagihanDetailScreen({
    super.key,
    required this.anak,
    required this.tagihan,
  });

  @override
  State<TagihanDetailScreen> createState() => _TagihanDetailScreenState();
}

class _TagihanDetailScreenState extends State<TagihanDetailScreen> {
  late Tagihan _tagihan = widget.tagihan;
  bool _berubah = false;
  bool _membukaPembayaran = false;
  int? _kwitansiLoadingId;

  Future<void> _muatUlang() async {
    final fresh = await context.read<WaliApi>().getTagihanDetail(
      widget.anak.id,
      _tagihan.id,
    );
    if (mounted) setState(() => _tagihan = fresh);
  }

  Future<void> _unduhKwitansi(TagihanPembayaran pembayaran) async {
    final id = pembayaran.kwitansiId;
    if (id == null || _kwitansiLoadingId != null) return;
    setState(() => _kwitansiLoadingId = id);
    try {
      final pdf = await context.read<WaliApi>().getKwitansiPdf(id);
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
      if (mounted) setState(() => _kwitansiLoadingId = null);
    }
  }

  Future<void> _bayar() async {
    if (_membukaPembayaran) return;
    setState(() => _membukaPembayaran = true);

    try {
      final berhasil = await bayarTagihanFlow(context, widget.anak, _tagihan);
      // The flow already refreshes AnakProvider's saldo; the tagihan's own
      // fresh state (nominal_terbayar/sisa/status) isn't returned from it
      // though, so this screen falls back to just reflecting "sudah lunas"
      // for a full payment and leaving the rest to whoever refreshes the
      // list behind it (see PopScope below, which reports back via `true`).
      if (berhasil && mounted) {
        _berubah = true;
        await _muatUlang();
      }
    } finally {
      if (mounted) setState(() => _membukaPembayaran = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagihan = _tagihan;
    final (badgeBg, badgeFg) = StatusBadge.colorsFor(tagihan.status);
    final progress = tagihan.nominal > 0
        ? (tagihan.nominalTerbayar / tagihan.nominal).clamp(0.0, 1.0)
        : 0.0;
    final jatuhTempoInfo = hitungJatuhTempo(tagihan);
    final showActions = !tagihan.selesai || tagihan.nominalTerbayar > 0;

    return PopScope(
      // Intercepts every pop path (AppBar back arrow, system back gesture,
      // not just an explicit button) so the caller (Home) always learns
      // whether a payment went through here and can refresh its own
      // tagihan/aktivitas lists - same "pop(true) on success" contract
      // TagihanTopupScreen already uses elsewhere.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_berubah);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Detail Tagihan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: badgeFg,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tagihan.jenisTagihanNama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tagihan.periodeLabel,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: tagihan.status),
                        ],
                      ),
                      if (jatuhTempoInfo != null ||
                          (tagihan.bisaDicicil && !tagihan.selesai)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (jatuhTempoInfo != null)
                              _Chip(
                                icon: jatuhTempoInfo.icon,
                                label: jatuhTempoInfo.label,
                                color: jatuhTempoInfo.color,
                                background: jatuhTempoInfo.background,
                              ),
                            if (tagihan.bisaDicicil && !tagihan.selesai)
                              const _Chip(
                                icon: Icons.payments_outlined,
                                label: 'Bisa Dicicil',
                                color: _teal,
                                background: Color(0x1A0F766E),
                              ),
                          ],
                        ),
                      ],
                      if (tagihan.status == 'sebagian') ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFEFF1F4),
                            valueColor: const AlwaysStoppedAnimation(_teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).round()}% terbayar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Color(0xFFE9EBEF)),
                      const SizedBox(height: 16),
                      Text(
                        tagihan.lunas ? 'Total Tagihan' : 'Sisa Tagihan',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatRupiah(
                          tagihan.lunas ? tagihan.nominal : tagihan.sisa,
                        ),
                        style: TextStyle(
                          color: tagihan.lunas
                              ? const Color(0xFF15803D)
                              : const Color(0xFF0F172A),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      _row('No. Tagihan', '#${tagihan.id}'),
                      _divider(),
                      _row('Nama Santri', widget.anak.nama),
                      _divider(),
                      _row('NIS', widget.anak.nis),
                      _divider(),
                      _row('Periode', tagihan.periodeLabel),
                      _divider(),
                      if (tagihan.adaDiskon) ...[
                        _row(
                          'Sebelum Diskon',
                          formatRupiah(tagihan.nominalSebelumDiskon!),
                        ),
                        _divider(),
                        _row('Diskon', '${tagihan.diskonPersen}%'),
                        _divider(),
                      ],
                      _row('Nominal', formatRupiah(tagihan.nominal)),
                      _divider(),
                      _row('Terbayar', formatRupiah(tagihan.nominalTerbayar)),
                      _divider(),
                      _row(
                        'Sisa',
                        formatRupiah(tagihan.sisa),
                        bold: !tagihan.lunas,
                      ),
                      _divider(),
                      _row(
                        'Status',
                        statusTagihanLabel[tagihan.status] ?? tagihan.status,
                        bold: tagihan.lunas,
                      ),
                      if (tagihan.jatuhTempo != null) ...[
                        _divider(),
                        _row('Jatuh Tempo', formatTanggal(tagihan.jatuhTempo!)),
                      ],
                    ],
                  ),
                ),
                if (tagihan.pembayaran.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE9EBEF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riwayat Pembayaran dan Kwitansi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Setiap cicilan memiliki kwitansi resmi tersendiri.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...tagihan.pembayaran.map(
                          (pembayaran) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAF9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8E4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatRupiah(pembayaran.nominal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          pembayaran.sumberLabel,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        if (pembayaran.dibayarAt != null)
                                          Text(
                                            formatTanggalWaktu(
                                              pembayaran.dibayarAt!,
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (pembayaran.kwitansiId != null)
                                    TextButton.icon(
                                      onPressed: _kwitansiLoadingId == null
                                          ? () => _unduhKwitansi(pembayaran)
                                          : null,
                                      icon:
                                          _kwitansiLoadingId ==
                                              pembayaran.kwitansiId
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.picture_as_pdf_outlined,
                                              size: 17,
                                            ),
                                      label: Text(
                                        pembayaran.nomorKwitansi ?? 'Kwitansi',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showActions) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (tagihan.nominalTerbayar > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () => cetakTagihanFlow(
                                context,
                                widget.anak,
                                tagihan,
                              ),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: Text(
                                tagihan.lunas
                                    ? 'Unduh Ringkasan'
                                    : 'Ringkasan Tagihan',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _teal,
                                side: const BorderSide(
                                  color: Color(0xFFD8DBE2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!tagihan.selesai) const SizedBox(width: 10),
                      ],
                      if (!tagihan.selesai)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _membukaPembayaran ? null : _bayar,
                              icon: _membukaPembayaran
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.wallet_outlined, size: 18),
                              label: Text(
                                _membukaPembayaran ? 'Membuka...' : 'Bayar',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _divider() =>
      const Divider(height: 20, color: Color(0xFFE9EBEF));

  static Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 13.5,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
